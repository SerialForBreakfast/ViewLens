import Foundation
#if canImport(NativeUIAuditKitModels)
import NativeUIAuditKitModels
#endif

public enum ModelLocatorError: Error, LocalizedError, Sendable {
    case notFound(searchedPaths: [String])
    case invalidModel(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let searchedPaths):
            return "CoreML model not found. Searched paths:\n" + searchedPaths.map { "  - \($0)" }.joined(separator: "\n")
        case .invalidModel(let path, let reason):
            return "Invalid CoreML model at '\(path)': \(reason)"
        }
    }
}

public struct ModelLocator: Sendable {
    public static let defaultModelName = "best.mlpackage"
    public static let maxExpectedSizeMB: Double = 25.0

    /// Attempts to resolve the CoreML model URL based on standard resolution priority.
    public static func resolve(customPath: String? = nil) -> Result<URL, ModelLocatorError> {
        var searchedPaths: [String] = []

        // 1. Explicit argument
        if let customPath = customPath, !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            searchedPaths.append(expanded)
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return validate(url: url)
            }
        }

        // 2. Bundled SPM Model from NativeUIAuditKitModels (Zero-config out of the box)
        #if canImport(NativeUIAuditKitModels)
        let spmURL = NativeUIModelAsset.defaultModelURL
        searchedPaths.append(spmURL.path)
        if FileManager.default.fileExists(atPath: spmURL.path) {
            return validate(url: spmURL)
        }
        #endif

        // 2. VIEWLENS_MODEL_PATH environment variable
        if let envPath = ProcessInfo.processInfo.environment["VIEWLENS_MODEL_PATH"], !envPath.isEmpty {
            let expanded = (envPath as NSString).expandingTildeInPath
            searchedPaths.append(expanded)
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return validate(url: url)
            }
        }

        // 3. NATIVEUI_MODEL_PATH environment variable
        if let envPath = ProcessInfo.processInfo.environment["NATIVEUI_MODEL_PATH"], !envPath.isEmpty {
            let expanded = (envPath as NSString).expandingTildeInPath
            searchedPaths.append(expanded)
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return validate(url: url)
            }
        }

        // 4. Relative paths from current working directory
        let relativeCandidates = [
            "models/\(defaultModelName)",
            "weights/\(defaultModelName)",
            "../NativeUIAuditKit/models/\(defaultModelName)",
            "../NativeUIAuditKit/yolo_runs/yolo11n_e100/weights/\(defaultModelName)",
            "../NativeUITrainer/yolo_runs/yolo11n_e100/weights/\(defaultModelName)"
        ]

        let currentDirectory = FileManager.default.currentDirectoryPath
        for candidate in relativeCandidates {
            let fullPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(candidate).path
            let normalized = (fullPath as NSString).standardizingPath
            searchedPaths.append(normalized)
            if FileManager.default.fileExists(atPath: normalized) {
                return validate(url: URL(fileURLWithPath: normalized))
            }
        }

        // 5. User Application Support Directory
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let userModelPath = appSupport.appendingPathComponent("ViewLens/models/\(defaultModelName)").path
            searchedPaths.append(userModelPath)
            if FileManager.default.fileExists(atPath: userModelPath) {
                return validate(url: URL(fileURLWithPath: userModelPath))
            }
        }

        // 6. Bundle resources (if running inside macOS App)
        if let bundleURL = Bundle.main.url(forResource: "best", withExtension: "mlpackage") ??
                           Bundle.main.url(forResource: "best", withExtension: "mlmodelc") {
            searchedPaths.append(bundleURL.path)
            return validate(url: bundleURL)
        }

        return .failure(.notFound(searchedPaths: searchedPaths))
    }

    /// Validates that the resolved model URL is accessible and non-empty.
    public static func validate(url: URL) -> Result<URL, ModelLocatorError> {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return .failure(.invalidModel(path: url.path, reason: "File or directory does not exist"))
        }

        do {
            let size = try calculateSize(at: url)
            let sizeMB = Double(size) / (1024.0 * 1024.0)
            if sizeMB == 0 {
                return .failure(.invalidModel(path: url.path, reason: "Model file is empty (0 MB)"))
            }
            return .success(url)
        } catch {
            return .failure(.invalidModel(path: url.path, reason: "Could not read size: \(error.localizedDescription)"))
        }
    }

    /// Computes the total byte size of a file or .mlpackage package directory.
    public static func calculateSize(at url: URL) throws -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        }

        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [])
        var totalSize: Int64 = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }

        return totalSize
    }
}
