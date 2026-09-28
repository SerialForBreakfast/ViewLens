import Testing
import Foundation
@testable import ViewLensKit

@Suite("ModelLocator Resolution Tests")
struct ModelLocatorTests {
    @Test("Calculates size of directory or file")
    func testCalculateSize() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleFile = tempDir.appendingPathComponent("sample.bin")
        let data = Data(repeating: 0x42, count: 1024 * 100) // 100 KB
        try data.write(to: sampleFile)

        let size = try ModelLocator.calculateSize(at: tempDir)
        #expect(size >= 102400)
    }

    @Test("Validates non-existent path returns failure")
    func testNonExistentModel() {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_model_\(UUID().uuidString).mlpackage")
        let result = ModelLocator.validate(url: nonExistentURL)
        switch result {
        case .success:
            Issue.record("Expected validation failure for non-existent path")
        case .failure:
            break
        }
    }

    @Test("Resolves bundled tvOS model from NativeUIAuditKitModels")
    func testResolveTVOSModel() {
        let result = ModelLocator.resolveTVOS()
        switch result {
        case .success(let url):
            #expect(url.lastPathComponent.contains("tvOS") || url.lastPathComponent.contains("mlmodelc"))
        case .failure(let error):
            Issue.record("Expected bundled tvOS model resolution to succeed, failed with: \(error)")
        }
    }
}
