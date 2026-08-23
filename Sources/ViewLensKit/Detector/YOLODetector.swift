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

#if canImport(NativeUIAuditKit)
import NativeUIAuditKit
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
    ) async throws -> [DetectedElement] {
        #if canImport(NativeUIAuditKit)
        let config = NativeUIDetectionConfiguration(
            minimumConfidence: Double(minConfidence),
            includesTextRecognition: false
        )
        let request = NativeUIDetectionRequest(configuration: config)
        let observations = try await request.perform(on: image)
        let imgW = Double(image.width)
        let imgH = Double(image.height)

        return observations.map { obs in
            let px = obs.boundingBoxPixels
            let normX = imgW > 0 ? px.x / imgW : 0
            let normY = imgH > 0 ? px.y / imgH : 0
            let normW = imgW > 0 ? px.width / imgW : 0
            let normH = imgH > 0 ? px.height / imgH : 0
            return DetectedElement(
                type: obs.elementType.rawValue,
                confidence: Float(obs.confidence),
                boundingBox: BoundingBox(x: normX, y: normY, width: normW, height: normH)
            )
        }
        #else
        let (pixelBuffer, scale, padX, padY) = try preprocess(image: image)
        let rawElements = try runInference(pixelBuffer: pixelBuffer, originalWidth: Double(image.width), originalHeight: Double(image.height), scale: scale, padX: padX, padY: padY, minConfidence: minConfidence)
        return NonMaximumSuppression.suppress(elements: rawElements, iouThreshold: iouThreshold)
        #endif
    }

    /// Performs batch inference across multiple CGImages using the pre-loaded MLModel instance.
    public func detectBatch(
        images: [CGImage],
        minConfidence: Float = 0.10,
        iouThreshold: Double = 0.30
    ) async throws -> [[DetectedElement]] {
        var batchResults: [[DetectedElement]] = []
        batchResults.reserveCapacity(images.count)

        for image in images {
            let elements = try await detect(image: image, minConfidence: minConfidence, iouThreshold: iouThreshold)
            batchResults.append(elements)
        }

        return batchResults
    }

    // MARK: - Fallback Preprocessing & Letterboxing
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
            throw YOLODetectorError.imageProcessingFailed("Failed to create CVPixelBuffer (status: \(status))")
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw YOLODetectorError.imageProcessingFailed("Failed to lock pixel buffer base address")
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: baseAddress,
                width: inputWidth,
                height: inputHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            throw YOLODetectorError.imageProcessingFailed("Failed to create CGContext for letterboxing")
        }

        // Fill with YOLO letterbox standard gray (114/255)
        context.setFillColor(CGColor(srgbRed: 114.0/255.0, green: 114.0/255.0, blue: 114.0/255.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: inputWidth, height: inputHeight))

        // Draw centered and scaled
        let drawRect = CGRect(x: padX, y: padY, width: newW, height: newH)
        context.draw(image, in: drawRect)

        return (pixelBuffer, scale, padX, padY)
    }

    private func runInference(
        pixelBuffer: CVPixelBuffer,
        originalWidth: Double,
        originalHeight: Double,
        scale: Double,
        padX: Double,
        padY: Double,
        minConfidence: Float
    ) throws -> [DetectedElement] {
        let inputFeatureName: String
        if let firstInput = model.modelDescription.inputDescriptionsByName.keys.first {
            inputFeatureName = firstInput
        } else {
            inputFeatureName = "image"
        }

        let featureProvider: MLFeatureProvider
        do {
            let featureValue = MLFeatureValue(pixelBuffer: pixelBuffer)
            featureProvider = try MLDictionaryFeatureProvider(dictionary: [inputFeatureName: featureValue])
        } catch {
            throw YOLODetectorError.imageProcessingFailed("Failed to create MLFeatureProvider: \(error.localizedDescription)")
        }

        let prediction: MLFeatureProvider
        do {
            prediction = try model.prediction(from: featureProvider)
        } catch {
            throw YOLODetectorError.modelLoadFailed("Prediction failed: \(error.localizedDescription)")
        }

        guard let outputFeatureName = model.modelDescription.outputDescriptionsByName.keys.first,
              let outputValue = prediction.featureValue(for: outputFeatureName),
              let multiArray = outputValue.multiArrayValue else {
            throw YOLODetectorError.outputParsingFailed("Failed to extract output MLMultiArray from model prediction")
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

            let origCx = (cx - padX) / scale
            let origCy = (cy - padY) / scale
            let origW = w / scale
            let origH = h / scale

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
