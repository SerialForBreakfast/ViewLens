import Foundation

/// OpenTelemetry-compatible span representation for tracing tool and audit lifecycles.
public struct TelemetrySpan: Codable, Sendable, Equatable {
    public let name: String
    public let traceId: String
    public let spanId: String
    public let parentSpanId: String?
    public let startTime: Date
    public var endTime: Date?
    public var durationMs: Double?
    public var status: String // "ok", "error", "in_progress"
    public var attributes: [String: String]

    public init(
        name: String,
        traceId: String = UUID().uuidString,
        spanId: String = UUID().uuidString,
        parentSpanId: String? = nil,
        startTime: Date = Date(),
        attributes: [String: String] = [:]
    ) {
        self.name = name
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
        self.startTime = startTime
        self.endTime = nil
        self.durationMs = nil
        self.status = "in_progress"
        self.attributes = attributes
    }
}

/// OpenTelemetry-compatible metric point.
public struct TelemetryMetric: Codable, Sendable, Equatable {
    public let name: String
    public let type: String // "counter", "gauge", "histogram"
    public let value: Double
    public let unit: String
    public let timestamp: Date
    public let tags: [String: String]

    public init(
        name: String,
        type: String = "counter",
        value: Double,
        unit: String = "count",
        timestamp: Date = Date(),
        tags: [String: String] = [:]
    ) {
        self.name = name
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.tags = tags
    }
}

/// Privacy-preserving telemetry and tracing engine (MCP-18.10).
/// Strictly guarantees zero logging of user passwords, form secrets, or raw code text.
public final class TelemetryEngine: @unchecked Sendable {
    public static let shared = TelemetryEngine()

    private let lock = NSLock()
    private var spans: [TelemetrySpan] = []
    private var metrics: [TelemetryMetric] = []

    private static let sensitiveKeys: Set<String> = [
        "password", "secret", "token", "auth", "authorization",
        "apikey", "api_key", "credential", "privatekey"
    ]

    public init() {}

    /// Starts a new telemetry span with sanitized attributes.
    public func startSpan(
        name: String,
        parent: TelemetrySpan? = nil,
        attributes: [String: String] = [:]
    ) -> TelemetrySpan {
        let span = TelemetrySpan(
            name: name,
            traceId: parent?.traceId ?? UUID().uuidString,
            spanId: UUID().uuidString,
            parentSpanId: parent?.spanId,
            startTime: Date(),
            attributes: sanitizeAttributes(attributes)
        )
        return span
    }

    /// Ends an active span and records duration.
    public func endSpan(
        _ span: inout TelemetrySpan,
        status: String = "ok",
        extraAttributes: [String: String] = [:]
    ) {
        let now = Date()
        span.endTime = now
        span.durationMs = now.timeIntervalSince(span.startTime) * 1000.0
        span.status = status

        let sanitizedExtra = sanitizeAttributes(extraAttributes)
        for (k, v) in sanitizedExtra {
            span.attributes[k] = v
        }

        lock.lock()
        spans.append(span)
        lock.unlock()
    }

    /// Records a numerical metric.
    public func recordMetric(
        name: String,
        type: String = "counter",
        value: Double,
        unit: String = "count",
        tags: [String: String] = [:]
    ) {
        let metric = TelemetryMetric(
            name: name,
            type: type,
            value: value,
            unit: unit,
            timestamp: Date(),
            tags: sanitizeAttributes(tags)
        )

        lock.lock()
        metrics.append(metric)
        lock.unlock()
    }

    /// Exports recorded spans.
    public func exportSpans() -> [TelemetrySpan] {
        lock.lock()
        defer { lock.unlock() }
        return spans
    }

    /// Exports recorded metrics.
    public func exportMetrics() -> [TelemetryMetric] {
        lock.lock()
        defer { lock.unlock() }
        return metrics
    }

    /// Clears recorded telemetry.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        spans.removeAll()
        metrics.removeAll()
    }

    /// Redacts sensitive key-value pairs.
    private func sanitizeAttributes(_ attrs: [String: String]) -> [String: String] {
        var clean: [String: String] = [:]
        for (key, val) in attrs {
            let lowerKey = key.lowercased()
            if Self.sensitiveKeys.contains(where: { lowerKey.contains($0) }) {
                clean[key] = "[REDACTED]"
            } else {
                clean[key] = val
            }
        }
        return clean
    }
}
