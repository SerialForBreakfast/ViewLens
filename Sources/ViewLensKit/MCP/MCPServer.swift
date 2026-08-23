import Foundation
import CoreGraphics
import ImageIO

/// Pure Swift Model Context Protocol (MCP) Server operating over standard input/output (stdio).
public final class MCPServer: Sendable {
    public init() {}

    /// Starts the blocking stdio JSON-RPC request loop.
    public func start() async {
        let inputHandle = FileHandle.standardInput

        while true {
            guard let lineData = readLineData(from: inputHandle) else {
                break // EOF on stdin (parent agent closed connection)
            }

            guard !lineData.isEmpty else { continue }

            do {
                let request = try JSONDecoder().decode(JSONRPCRequest.self, from: lineData)
                let responseData = await handleRequest(request)
                if let responseData = responseData {
                    FileHandle.standardOutput.write(responseData)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                }
            } catch {
                let errResponse = JSONRPCResponse<String>(
                    id: nil,
                    error: JSONRPCError(code: -32700, message: "Parse error: \(error.localizedDescription)")
                )
                if let data = try? JSONEncoder().encode(errResponse) {
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                }
            }
        }
    }

    private func readLineData(from handle: FileHandle) -> Data? {
        var buffer = Data()
        while true {
            let chunk = handle.readData(ofLength: 1)
            guard !chunk.isEmpty else {
                return buffer.isEmpty ? nil : buffer
            }
            if chunk[0] == UInt8(ascii: "\n") {
                return buffer
            }
            buffer.append(chunk)
        }
    }

    private func handleRequest(_ request: JSONRPCRequest) async -> Data? {
        switch request.method {
        case "initialize":
            let result = MCPInitializeResult()
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "notifications/initialized":
            // Notifications do not receive a response
            return nil

        case "ping":
            let response = JSONRPCResponse(id: request.id, result: [String: String]())
            return try? JSONEncoder().encode(response)

        case "tools/list":
            let tools = defineTools()
            let response = JSONRPCResponse(id: request.id, result: MCPToolsListResult(tools: tools))
            return try? JSONEncoder().encode(response)

        case "tools/call":
            return await handleToolCall(request)

        default:
            let response = JSONRPCResponse<String>(
                id: request.id,
                error: JSONRPCError(code: -32601, message: "Method not found: \(request.method)")
            )
            return try? JSONEncoder().encode(response)
        }
    }

    private func defineTools() -> [MCPTool] {
        let doctorSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "model_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to override default CoreML model discovery.")
                ])
            ])
        ])

        let screenshotSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "image_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the screenshot image file (PNG/JPEG) to audit.")
                ]),
                "min_confidence": .object([
                    "type": .string("number"),
                    "description": .string("Minimum detection confidence threshold (default 0.10).")
                ]),
                "scale": .object([
                    "type": .string("number"),
                    "description": .string("Display scale override (@2x = 2.0, @3x = 3.0). Auto-inferred if omitted.")
                ]),
                "overlay_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to write an annotated PNG image with color-coded bounding boxes.")
                ]),
                "model_path": .object([
                    "type": .string("string"),
                    "description": .string("Optional path to override default CoreML model.")
                ])
            ]),
            "required": .array([.string("image_path")])
        ])

        let viewSchema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "template": .object([
                    "type": .string("string"),
                    "description": .string("Name of the registered SwiftUI/UIKit template.")
                ]),
                "devices": .object([
                    "type": .string("array"),
                    "description": .string("List of device profiles (e.g. ['iPhoneSE', 'iPhone16Pro']).")
                ]),
                "dynamic_type_sizes": .object([
                    "type": .string("array"),
                    "description": .string("List of Dynamic Type sizes (e.g. ['large', 'accessibility3']).")
                ]),
                "color_schemes": .object([
                    "type": .string("array"),
                    "description": .string("List of color schemes ('light', 'dark').")
                ])
            ]),
            "required": .array([.string("template")])
        ])

        return [
            MCPTool(
                name: "viewlens_doctor",
                description: "Reports environment readiness: verifies CoreML model path, file size, and performs cold-load latency check. Call this first. See .agents/skills/viewlens/SKILL.md.",
                inputSchema: doctorSchema
            ),
            MCPTool(
                name: "viewlens_audit_screenshot",
                description: "Audits a screenshot image using YOLO11n CoreML vision detection and HIG rules. Returns structured JSON coordinates [x, y, w, h] in normalized top-left space and classified layout issues.",
                inputSchema: screenshotSchema
            ),
            MCPTool(
                name: "viewlens_audit_view",
                description: "Renders and audits a registered SwiftUI/UIKit view template across a matrix of device profiles and accessibility traits (Milestone 2).",
                inputSchema: viewSchema
            )
        ]
    }

    private func handleToolCall(_ request: JSONRPCRequest) async -> Data? {
        guard let paramsObj = request.params?.objectValue,
              let toolName = paramsObj["name"]?.stringValue else {
            let response = JSONRPCResponse<String>(
                id: request.id,
                error: JSONRPCError(code: -32602, message: "Invalid params for tools/call")
            )
            return try? JSONEncoder().encode(response)
        }

        let arguments = paramsObj["arguments"]?.objectValue ?? [:]

        switch toolName {
        case "viewlens_doctor":
            let modelPath = arguments["model_path"]?.stringValue
            let report = runDoctor(customPath: modelPath)
            let jsonText = JSONFormatter.encode(report)
            let result = MCPToolCallResult(text: jsonText, isError: report.status != "ready")
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_audit_screenshot":
            guard let imagePath = arguments["image_path"]?.stringValue else {
                let result = MCPToolCallResult(text: JSONFormatter.errorJSON(message: "Missing required 'image_path' parameter"), isError: true)
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            let minConfidence = Float(arguments["min_confidence"]?.doubleValue ?? 0.10)
            let scale = arguments["scale"]?.doubleValue
            let overlayPath = arguments["overlay_path"]?.stringValue
            let modelPath = arguments["model_path"]?.stringValue

            let auditResult = await runAuditScreenshot(
                imagePath: imagePath,
                minConfidence: minConfidence,
                scale: scale,
                overlayPath: overlayPath,
                modelPath: modelPath
            )

            let result = MCPToolCallResult(text: auditResult.jsonText, isError: !auditResult.success)
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        case "viewlens_audit_view":
            guard let templateName = arguments["template"]?.stringValue else {
                let result = MCPToolCallResult(text: JSONFormatter.errorJSON(message: "Missing required 'template' parameter"), isError: true)
                let response = JSONRPCResponse(id: request.id, result: result)
                return try? JSONEncoder().encode(response)
            }

            let devicesArray: [String]
            if case .array(let arr) = arguments["devices"] {
                devicesArray = arr.compactMap { $0.stringValue }
            } else {
                devicesArray = ["iPhoneSE", "iPhone16Pro"]
            }

            let dtArray: [String]
            if case .array(let arr) = arguments["dynamic_type_sizes"] {
                dtArray = arr.compactMap { $0.stringValue }
            } else {
                dtArray = ["large", "accessibility3"]
            }

            let schemeArray: [String]
            if case .array(let arr) = arguments["color_schemes"] {
                schemeArray = arr.compactMap { $0.stringValue }
            } else {
                schemeArray = ["light", "dark"]
            }

            let auditResult = await runAuditView(
                templateName: templateName,
                deviceNames: devicesArray,
                dtSizes: dtArray,
                schemes: schemeArray
            )

            let result = MCPToolCallResult(text: auditResult.jsonText, isError: !auditResult.passed)
            let response = JSONRPCResponse(id: request.id, result: result)
            return try? JSONEncoder().encode(response)

        default:
            let response = JSONRPCResponse<String>(
                id: request.id,
                error: JSONRPCError(code: -32601, message: "Unknown tool: \(toolName)")
            )
            return try? JSONEncoder().encode(response)
        }
    }

    private func runDoctor(customPath: String?) -> DoctorReport {
        var checks: [DiagnosticCheck] = []
        var allPassed = true

        let modelResult = ModelLocator.resolve(customPath: customPath)
        let resolvedURL: URL?

        switch modelResult {
        case .success(let url):
            resolvedURL = url
            checks.append(DiagnosticCheck(name: "model_found", status: "confirmed", detail: url.path))
        case .failure(let error):
            resolvedURL = nil
            allPassed = false
            checks.append(DiagnosticCheck(name: "model_found", status: "failed", detail: error.localizedDescription))
        }

        if let url = resolvedURL {
            do {
                let sizeBytes = try ModelLocator.calculateSize(at: url)
                let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
                let formattedMB = String(format: "%.1fMB", sizeMB)

                if sizeMB <= ModelLocator.maxExpectedSizeMB && sizeMB > 0.1 {
                    checks.append(DiagnosticCheck(name: "model_size", status: "confirmed", detail: "\(formattedMB) (< \(Int(ModelLocator.maxExpectedSizeMB))MB)"))
                } else {
                    allPassed = false
                    checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: "\(formattedMB) exceeds expectation"))
                }
            } catch {
                allPassed = false
                checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_size", status: "skipped", detail: "Model not found"))
        }

        if let url = resolvedURL {
            let start = DispatchTime.now()
            do {
                _ = try YOLODetector(modelURL: url)
                let end = DispatchTime.now()
                let elapsedSeconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
                checks.append(DiagnosticCheck(name: "model_loads", status: "confirmed", detail: String(format: "Cold load: %.2fs", elapsedSeconds)))
            } catch {
                allPassed = false
                checks.append(DiagnosticCheck(name: "model_loads", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_loads", status: "skipped", detail: "Model not found"))
        }

        let overallStatus = allPassed ? "ready" : "not_ready"
        let nextCommand = allPassed ? "viewlens scan <image-path>" : "export VIEWLENS_MODEL_PATH=/path/to/best.mlpackage"

        return DoctorReport(status: overallStatus, checks: checks, recommendedNextCommand: nextCommand)
    }

    private func runAuditScreenshot(
        imagePath: String,
        minConfidence: Float,
        scale: Double?,
        overlayPath: String?,
        modelPath: String?
    ) async -> (jsonText: String, success: Bool) {
        let expanded = (imagePath as NSString).expandingTildeInPath
        let imageURL = URL(fileURLWithPath: expanded)

        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return (JSONFormatter.errorJSON(message: "Cannot load image at '\(imagePath)'"), false)
        }

        let modelURL: URL
        switch ModelLocator.resolve(customPath: modelPath) {
        case .success(let url):
            modelURL = url
        case .failure(let error):
            return (JSONFormatter.errorJSON(message: error.localizedDescription, nextCommand: "viewlens doctor"), false)
        }

        let detector: YOLODetector
        do {
            detector = try YOLODetector(modelURL: modelURL)
        } catch {
            return (JSONFormatter.errorJSON(message: "Failed to initialize detector: \(error.localizedDescription)"), false)
        }

        let imgWidth = Double(cgImage.width)
        let imgHeight = Double(cgImage.height)
        let imgSize = CGSize(width: imgWidth, height: imgHeight)
        let resolvedScale = scale ?? IssueClassifier.inferDisplayScale(imageWidth: imgWidth)

        let detectedElements: [DetectedElement]
        do {
            detectedElements = try await detector.detect(image: cgImage, minConfidence: minConfidence)
        } catch {
            return (JSONFormatter.errorJSON(message: "Inference failed: \(error.localizedDescription)"), false)
        }

        let issues = IssueClassifier.classify(elements: detectedElements, imageSize: imgSize, scale: resolvedScale)
        let report = AuditReport(
            sourceMode: .screenshot,
            image: imagePath,
            dimensions: AuditDimensions(width: imgWidth, height: imgHeight, scale: resolvedScale),
            elements: detectedElements,
            issues: issues
        )

        if let overlayPath = overlayPath {
            if let annotated = OverlayRenderer.render(image: cgImage, elements: detectedElements, issues: issues) {
                let outURL = URL(fileURLWithPath: (overlayPath as NSString).expandingTildeInPath)
                try? OverlayRenderer.write(image: annotated, to: outURL)
            }
        }

        return (JSONFormatter.encode(report), report.passed)
    }

    private func runAuditView(
        templateName: String,
        deviceNames: [String],
        dtSizes: [String],
        schemes: [String]
    ) async -> (jsonText: String, passed: Bool) {
        var detector: YOLODetector? = nil
        if let modelURL = try? ModelLocator.resolve().get() {
            detector = try? YOLODetector(modelURL: modelURL)
        }

        do {
            let matrixReport = try await MatrixRenderer.auditNamedTemplate(
                templateName: templateName,
                deviceNames: deviceNames,
                dtSizes: dtSizes,
                schemes: schemes,
                detector: detector
            )
            return (JSONFormatter.encode(matrixReport), matrixReport.passed)
        } catch {
            let available = await MainActor.run {
                TemplateRegistry.shared.availableTemplates.joined(separator: ", ")
            }
            return (JSONFormatter.errorJSON(
                message: error.localizedDescription,
                detail: "Available templates: \(available)",
                nextCommand: "viewlens render --list-templates"
            ), false)
        }
    }
}
