import Testing
import Foundation
@testable import ViewLensKit

@Suite("ViewLens Configuration Tests")
struct ConfigTests {
    @Test("Loads default configuration with pre-commit, pre-push, and pull-request gates")
    func testDefaultConfig() {
        let config = ViewLensConfig()
        #expect(config.version == 1)
        #expect(config.gates["pre-commit"] != nil)
        #expect(config.gates["pre-push"] != nil)
        #expect(config.gates["pull-request"] != nil)

        let preCommit = config.gates["pre-commit"]!
        #expect(preCommit.failOn == .error)
        #expect(preCommit.devices.contains("iPhoneSE"))
        #expect(preCommit.devices.contains("iPhone16Pro"))
    }

    @Test("Encodes and decodes JSON configuration")
    func testConfigSerialization() throws {
        var config = ViewLensConfig()
        config.gates["custom-gate"] = GateConfig(
            failOn: .warning,
            purposes: [.touchTargets, .clipping],
            devices: ["iPadPro11"],
            dynamicTypeSizes: ["large"],
            colorSchemes: ["light"],
            strict: true
        )

        let json = config.toJSONString()
        guard let data = json.data(using: .utf8) else {
            Issue.record("Failed to convert JSON string to data")
            return
        }

        let decoded = try JSONDecoder().decode(ViewLensConfig.self, from: data)
        #expect(decoded.gates["custom-gate"]?.failOn == .warning)
        #expect(decoded.gates["custom-gate"]?.devices == ["iPadPro11"])
        #expect(decoded.gates["custom-gate"]?.strict == true)
    }
}
