import Foundation
import CoreML
import CoreGraphics
import ImageIO
import Accelerate

public enum YOLODetectorError: Error, LocalizedError, Sendable {
    case modelCompilationFailed(String)
    case modelLoadFailed(String)
    case imageProcessingFailed(String)
    case outputParsingFailed(String)
    case unsupportedModelOutput(String)

    public var errorDescription: String? {
        switch self {
        case .modelCompilationFailed(let reason):
            return "Failed to compile CoreML model: \(reason)"
        case .modelLoadFailed(let reason):
            return "Failed to load CoreML model: \(reason)"
        case .imageProcessingFailed(let reason):
            return "Failed to preprocess image: \(reason)"
        case .outputParsingFailed(let reason):
            return "Failed to parse CoreML output MultiArray: \(reason)"
        case .unsupportedModelOutput(let reason):
            return "Unsupported model output tensor: \(reason)"
        }
    }
}

#if canImport(NativeUIAuditKitModels)
import NativeUIAuditKitModels
#endif

/// Actor managing YOLO11n CoreML inference on Apple Neural Engine and GPU.
public actor YOLODetector {
    private let model: MLModel
    public let classNames: [String]
    public let inputWidth: Int = 640
    public let inputHeight: Int = 640

    public static var defaultClassNames: [String] {
        #if canImport(NativeUIAuditKitModels)
        return NativeUIModelAsset.metadata.classLabels
        #else
        return [
            "navigationBar",
            "primaryButton",
            "tabBar",
            "textField",
            "toggle"
        ]
        #endif
    }

    /// Initializes a YOLODetector from a model URL (either .mlmodelc or .mlpackage).
    public init(
        modelURL: URL,
        classNames: [String] = defaultClassNames,
        configuration: MLModelConfiguration = MLModelConfiguration()
    ) throws {
        self.classNames = classNames

        let compiledURL: URL
        if modelURL.pathExtension == "mlpackage" || modelURL.pathExtension == "mlmodel" {
            do {
                compiledURL = try MLModel.compileModel(at: modelURL)
            } catch {
                throw YOLODetectorError.modelCompilationFailed(error.localizedDescription)
            }
        } else {
            compiledURL = modelURL
        }

        do {
            self.model = try MLModel(contentsOf: compiledURL, configuration: configuration)
        } catch {
            throw YOLODetectorError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Performs inference on a single CGImage.
    public func detect(
        image: CGImage,
        minConfidence: Float = 0.10,
        iouThreshold: Double = 0.30
    ) throws -> [DetectedElement] {
        let (pixelBuffer, scale, padX, padY) = try preprocess(image: image)
        let rawElements = try runInference(pixelBuffer: pixelBuffer, originalWidth: Double(image.width), originalHeight: Double(image.height), scale: scale, padX: padX, padY: padY, minConfidence: minConfidence)
        return NonMaximumSuppression.suppress(elements: rawElements, iouThreshold: iouThreshold)
    }

    /// Performs batch inference across multiple CGImages using the pre-loaded MLModel instance.
    public func detectBatch(
        images: [CGImage],
        minConfidence: Float = 0.10,
        iouThreshold: Double = 0.30
    ) throws -> [[DetectedElement]] {
        var batchResults: [[DetectedElement]] = []
        batchResults.reserveCapacity(images.count)

        for image in images {
            let elements = try detect(image: image, minConfidence: minConfidence, iouThreshold: iouThreshold)
            batchResults.append(elements)
        }

        return batchResults
    }

    // MARK: - Preprocessing & Letterboxing
    private func preprocess(image: CGImage) throws -> (pixelBuffer: CVPixelBuffer, scale: Double, padX: Double, padY: Double) {
        let origW = Double(image.width)
        let origH = Double(image.height)
        guard origW > 0, origH > 0 else {
            throw YOLODetectorError.imageProcessingFailed("Invalid image dimensions \(origW)x\(origH)")
        }

        let targetW = Double(inputWidth)
        let targetH = Double(inputHeight)
        let scale = min(targetW / origW, targetH / origH)

        let newW = origW * scale
        let newH = origH * scale
        let padX = (targetW - newW) / 2.0
        let padY = (targetH - newH) / 2.0

        var pixelBufferOut: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            inputWidth,
            inputHeight,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBufferOut
        )

        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            throw YOLODetectorError.imageProcessingFailed("CVPixelBufferCreate failed with code \(status)")
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: inputWidth,
            height: inputHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw YOLODetectorError.imageProcessingFailed("Failed to create CGContext for pixel buffer")
        }

        // Fill background with neutral gray padding (114/255)
        context.setFillColor(red: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: inputWidth, height: inputHeight))

        // Draw resized image centered within the 640x640 canvas
        let drawRect = CGRect(x: padX, y: padY, width: newW, height: newH)
        context.draw(image, in: drawRect)

        return (pixelBuffer, scale, padX, padY)
    }

    // MARK: - Inference & Output MultiArray Parsing
    private func runInference(
        pixelBuffer: CVPixelBuffer,
        originalWidth: Double,
        originalHeight: Double,
        scale: Double,
        padX: Double,
        padY: Double,
        minConfidence: Float
    ) throws -> [DetectedElement] {
        // Resolve input feature name
        let inputFeatureName = model.modelDescription.inputDescriptionsByName.keys.first ?? "image"
        let inputFeatureValue = MLFeatureValue(pixelBuffer: pixelBuffer)
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputFeatureName: inputFeatureValue])

        let prediction = try model.prediction(from: provider)
        guard let outputFeatureName = model.modelDescription.outputDescriptionsByName.keys.first,
              let outputValue = prediction.featureValue(for: outputFeatureName),
              let multiArray = outputValue.multiArrayValue else {
            throw YOLODetectorError.outputParsingFailed("Missing or invalid MLMultiArray in prediction output")
        }

        return try parseYOLOOutput(
            multiArray: multiArray,
            originalWidth: originalWidth,
            originalHeight: originalHeight,
            scale: scale,
            padX: padX,
            padY: padY,
            minConfidence: minConfidence
        )
    }

    private func parseYOLOOutput(
        multiArray: MLMultiArray,
        originalWidth: Double,
        originalHeight: Double,
        scale: Double,
        padX: Double,
        padY: Double,
        minConfidence: Float
    ) throws -> [DetectedElement] {
        // YOLO11 tensor format: [1, 4 + num_classes, num_proposals (e.g. 8400)]
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count >= 2 else {
            throw YOLODetectorError.unsupportedModelOutput("MultiArray shape \(shape) is unsupported")
        }

        let numChannels: Int
        let numProposals: Int

        if shape.count == 3 {
            numChannels = shape[1]
            numProposals = shape[2]
        } else {
            numChannels = shape[0]
            numProposals = shape[1]
        }

        let numClasses = numChannels - 4
        guard numClasses > 0 else {
            throw YOLODetectorError.unsupportedModelOutput("Invalid number of classes: \(numClasses)")
        }

        let strides = multiArray.strides.map { $0.intValue }
        let channelStride: Int
        let proposalStride: Int

        if shape.count == 3 {
            channelStride = strides[1]
            proposalStride = strides[2]
        } else {
            channelStride = strides[0]
            proposalStride = strides[1]
        }

        let ptr = UnsafeMutablePointer<Float>(OpaquePointer(multiArray.dataPointer))
        var detected: [DetectedElement] = []

        for p in 0..<numProposals {
            let offsetP = p * proposalStride

            // Find best class score for proposal p
            var bestScore: Float = 0.0
            var bestClassIdx: Int = 0

            for c in 0..<numClasses {
                let classOffset = (4 + c) * channelStride + offsetP
                let score = ptr[classOffset]
                if score > bestScore {
                    bestScore = score
                    bestClassIdx = c
                }
            }

            guard bestScore >= minConfidence else { continue }

            let cx = Double(ptr[0 * channelStride + offsetP])
            let cy = Double(ptr[1 * channelStride + offsetP])
            let w = Double(ptr[2 * channelStride + offsetP])
            let h = Double(ptr[3 * channelStride + offsetP])

            // Un-letterbox: map 640x640 letterbox coordinates back to original unpadded image
            let origCx = (cx - padX) / scale
            let origCy = (cy - padY) / scale
            let origW = w / scale
            let origH = h / scale

            // Normalize to [0.0, 1.0] relative to original image size
            let normCx = origCx / originalWidth
            let normCy = origCy / originalHeight
            let normW = origW / originalWidth
            let normH = origH / originalHeight

            let className = bestClassIdx < classNames.count ? classNames[bestClassIdx] : "class_\(bestClassIdx)"
            let box = BoundingBox(centerX: normCx, centerY: normCy, width: normW, height: normH)

            detected.append(DetectedElement(
                type: className,
                confidence: bestScore,
                boundingBox: box
            ))
        }

        return detected
    }
}
