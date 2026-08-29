import Foundation
import Testing
@testable import ViewLensKit

@Suite("Telemetry & Tracing Engine Tests (MCP-18.10)")
struct TelemetryEngineTests {
    @Test("Records spans, calculates duration, and automatically redacts sensitive keys")
    func spanRecordingAndRedaction() {
        let engine = TelemetryEngine()
        engine.clear()

        var span = engine.startSpan(
            name: "mcp.tool.viewlens_audit_view",
            attributes: [
                "template": "LoginForm",
                "authToken": "super-secret-password-123"
            ]
        )

        // Verify initial redaction
        #expect(span.attributes["template"] == "LoginForm")
        #expect(span.attributes["authToken"] == "[REDACTED]")

        engine.endSpan(
            &span,
            status: "ok",
            extraAttributes: ["api_key": "raw-key-456", "duration_custom": "fast"]
        )

        let recorded = engine.exportSpans()
        #expect(recorded.count == 1)
        #expect(recorded[0].name == "mcp.tool.viewlens_audit_view")
        #expect(recorded[0].status == "ok")
        #expect((recorded[0].durationMs ?? 0) >= 0)
        #expect(recorded[0].attributes["api_key"] == "[REDACTED]")
        #expect(recorded[0].attributes["duration_custom"] == "fast")
    }

    @Test("Records metrics and tags with privacy redaction")
    func metricRecording() {
        let engine = TelemetryEngine()
        engine.clear()

        engine.recordMetric(
            name: "mcp.tool_execution_time",
            type: "histogram",
            value: 42.5,
            unit: "ms",
            tags: ["tool": "viewlens_doctor", "password_input": "attempt"]
        )

        let recorded = engine.exportMetrics()
        #expect(recorded.count == 1)
        #expect(recorded[0].name == "mcp.tool_execution_time")
        #expect(recorded[0].value == 42.5)
        #expect(recorded[0].tags["tool"] == "viewlens_doctor")
        #expect(recorded[0].tags["password_input"] == "[REDACTED]")
    }
}
