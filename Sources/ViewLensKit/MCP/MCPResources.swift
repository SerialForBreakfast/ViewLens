import Foundation

public struct MCPResourceAnnotations: Codable, Sendable, Equatable {
    public let audience: [String]
    public let priority: Double
    public let lastModified: String?

    public init(
        audience: [String] = ["assistant"],
        priority: Double = 0.5,
        lastModified: String? = nil
    ) {
        self.audience = audience
        self.priority = min(max(priority, 0), 1)
        self.lastModified = lastModified
    }
}

public struct MCPResource: Codable, Sendable, Equatable {
    public let uri: String
    public let name: String
    public let title: String?
    public let description: String?
    public let mimeType: String?
    public let size: Int?
    public let annotations: MCPResourceAnnotations?

    public init(
        uri: String,
        name: String,
        title: String? = nil,
        description: String? = nil,
        mimeType: String? = nil,
        size: Int? = nil,
        annotations: MCPResourceAnnotations? = nil
    ) {
        self.uri = uri
        self.name = name
        self.title = title
        self.description = description
        self.mimeType = mimeType
        self.size = size
        self.annotations = annotations
    }
}

public struct MCPResourceTemplate: Codable, Sendable, Equatable {
    public let uriTemplate: String
    public let name: String
    public let title: String
    public let description: String
    public let mimeType: String
    public let annotations: MCPResourceAnnotations

    public init(
        uriTemplate: String,
        name: String,
        title: String,
        description: String,
        mimeType: String = "application/json",
        priority: Double = 0.5
    ) {
        self.uriTemplate = uriTemplate
        self.name = name
        self.title = title
        self.description = description
        self.mimeType = mimeType
        self.annotations = MCPResourceAnnotations(priority: priority)
    }
}

public struct MCPResourcesListResult: Encodable, Sendable {
    public let resultType: String?
    public let resources: [MCPResource]
    public let nextCursor: String?
    public let ttlMs: Int?
    public let cacheScope: String?
    public let metadata: MCPResultMetadata?

    enum CodingKeys: String, CodingKey {
        case resultType, resources, nextCursor, ttlMs, cacheScope
        case metadata = "_meta"
    }

    public init(resources: [MCPResource], nextCursor: String?, modern: Bool) {
        self.resultType = modern ? "complete" : nil
        self.resources = resources
        self.nextCursor = nextCursor
        self.ttlMs = modern ? 0 : nil
        self.cacheScope = modern ? "private" : nil
        self.metadata = modern ? MCPResultMetadata() : nil
    }
}

public struct MCPResourceTemplatesListResult: Encodable, Sendable {
    public let resultType: String?
    public let resourceTemplates: [MCPResourceTemplate]
    public let nextCursor: String?
    public let ttlMs: Int?
    public let cacheScope: String?
    public let metadata: MCPResultMetadata?

    enum CodingKeys: String, CodingKey {
        case resultType, resourceTemplates, nextCursor, ttlMs, cacheScope
        case metadata = "_meta"
    }

    public init(resourceTemplates: [MCPResourceTemplate], nextCursor: String?, modern: Bool) {
        self.resultType = modern ? "complete" : nil
        self.resourceTemplates = resourceTemplates
        self.nextCursor = nextCursor
        self.ttlMs = modern ? 3_600_000 : nil
        self.cacheScope = modern ? "public" : nil
        self.metadata = modern ? MCPResultMetadata() : nil
    }
}

public struct MCPResourceContent: Codable, Sendable, Equatable {
    public let uri: String
    public let mimeType: String
    public let text: String?
    public let blob: String?
    public let annotations: MCPResourceAnnotations?

    public init(
        uri: String,
        mimeType: String,
        text: String? = nil,
        blob: String? = nil,
        annotations: MCPResourceAnnotations? = nil
    ) {
        self.uri = uri
        self.mimeType = mimeType
        self.text = text
        self.blob = blob
        self.annotations = annotations
    }
}

public struct MCPResourceReadResult: Encodable, Sendable {
    public let resultType: String?
    public let contents: [MCPResourceContent]
    public let ttlMs: Int?
    public let cacheScope: String?
    public let metadata: MCPResultMetadata?

    enum CodingKeys: String, CodingKey {
        case resultType, contents, ttlMs, cacheScope
        case metadata = "_meta"
    }

    public init(contents: [MCPResourceContent], modern: Bool) {
        self.resultType = modern ? "complete" : nil
        self.contents = contents
        self.ttlMs = modern ? 60_000 : nil
        self.cacheScope = modern ? "private" : nil
        self.metadata = modern ? MCPResultMetadata() : nil
    }
}

actor MCPResourceStore {
    private struct ArtifactSnapshot: Sendable {
        let metadata: MCPEvidenceEnvelope.Artifact
        let data: Data?
    }

    private struct ReviewRecord: Sendable {
        let envelope: MCPEvidenceEnvelope
        let createdAt: Date
        let artifactSnapshots: [ArtifactSnapshot]
    }

    enum ReadError: Error, Sendable {
        case notFound
        case artifactUnavailable
        case artifactTooLarge
    }

    private let maximumReviews = 50
    private let maximumArtifactBytes = 10 * 1_024 * 1_024
    private var records: [String: ReviewRecord] = [:]

    func record(_ envelope: MCPEvidenceEnvelope) {
        let snapshots = envelope.artifacts.map { artifact -> ArtifactSnapshot in
            let url = URL(fileURLWithPath: artifact.path).standardizedFileURL
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? nil
            let data: Data?
            if FileManager.default.isReadableFile(atPath: url.path),
               let size, size <= maximumArtifactBytes {
                data = try? Data(contentsOf: url, options: [.mappedIfSafe])
            } else {
                data = nil
            }
            return ArtifactSnapshot(metadata: artifact, data: data)
        }
        records[envelope.reviewID] = ReviewRecord(
            envelope: envelope,
            createdAt: Date(),
            artifactSnapshots: snapshots
        )
        if records.count > maximumReviews,
           let oldest = records.min(by: { $0.value.createdAt < $1.value.createdAt })?.key {
            records.removeValue(forKey: oldest)
        }
    }

    func resources() -> [MCPResource] {
        let indexes = Self.indexResources
        let reviewResources = sortedRecords().flatMap { reviewID, record in
            let modified = Self.dateString(record.createdAt)
            let annotations = MCPResourceAnnotations(priority: 0.8, lastModified: modified)
            var resources = [
                MCPResource(
                    uri: "viewlens://reviews/\(reviewID)",
                    name: "review-\(reviewID)",
                    title: "ViewLens Review",
                    description: "Complete structured evidence envelope",
                    mimeType: "application/json",
                    annotations: annotations
                ),
                MCPResource(
                    uri: "viewlens://reviews/\(reviewID)/findings",
                    name: "review-findings-\(reviewID)",
                    title: "Review Findings",
                    description: "Token-efficient findings for this review",
                    mimeType: "application/json",
                    annotations: annotations
                ),
                MCPResource(
                    uri: "viewlens://reviews/\(reviewID)/report",
                    name: "review-report-\(reviewID)",
                    title: "Review Report",
                    description: "Underlying typed tool report",
                    mimeType: "application/json",
                    annotations: annotations
                )
            ]
            resources.append(contentsOf: record.artifactSnapshots.enumerated().map { index, snapshot in
                let artifact = snapshot.metadata
                return MCPResource(
                    uri: "viewlens://reviews/\(reviewID)/artifacts/\(index)",
                    name: "\(artifact.kind)-\(index)",
                    title: artifact.kind.capitalized,
                    description: "Generated ViewLens \(artifact.kind) artifact",
                    mimeType: artifact.mediaType,
                    size: snapshot.data?.count,
                    annotations: annotations
                )
            })
            return resources
        }
        return indexes + reviewResources
    }

    func read(uri: String) throws -> MCPResourceContent {
        guard let components = URLComponents(string: uri),
              components.scheme == "viewlens",
              components.host != nil else {
            throw ReadError.notFound
        }

        if components.host != "reviews" {
            return try readIndex(host: components.host ?? "", uri: uri)
        }

        let path = components.path.split(separator: "/").map(String.init)
        if path.isEmpty {
            return jsonContent(uri: uri, value: reviewIndex())
        }
        guard let record = records[path[0]] else { throw ReadError.notFound }

        if path.count == 1 {
            return jsonContent(uri: uri, value: record.envelope)
        }
        if path.count == 2, path[1] == "findings" {
            return jsonContent(uri: uri, value: record.envelope.findings)
        }
        if path.count == 2, path[1] == "report" {
            return jsonContent(uri: uri, jsonValue: record.envelope.data)
        }
        if path.count == 3, path[1] == "artifacts",
           let index = Int(path[2]), record.artifactSnapshots.indices.contains(index) {
            let snapshot = record.artifactSnapshots[index]
            guard let data = snapshot.data else {
                throw ReadError.artifactUnavailable
            }
            guard data.count <= maximumArtifactBytes else {
                throw ReadError.artifactTooLarge
            }
            return MCPResourceContent(
                uri: uri,
                mimeType: snapshot.metadata.mediaType,
                blob: data.base64EncodedString(),
                annotations: MCPResourceAnnotations(priority: 0.7, lastModified: Self.dateString(record.createdAt))
            )
        }
        throw ReadError.notFound
    }

    static let templates: [MCPResourceTemplate] = [
        MCPResourceTemplate(
            uriTemplate: "viewlens://reviews/{reviewId}",
            name: "viewlens-review",
            title: "ViewLens Review Evidence",
            description: "Read a complete evidence envelope by review ID",
            priority: 0.9
        ),
        MCPResourceTemplate(
            uriTemplate: "viewlens://reviews/{reviewId}/findings",
            name: "viewlens-review-findings",
            title: "ViewLens Review Findings",
            description: "Read only the findings for a review",
            priority: 1.0
        ),
        MCPResourceTemplate(
            uriTemplate: "viewlens://reviews/{reviewId}/report",
            name: "viewlens-review-report",
            title: "ViewLens Typed Report",
            description: "Read the underlying doctor, audit, accessibility, matrix, or design report",
            priority: 0.8
        ),
        MCPResourceTemplate(
            uriTemplate: "viewlens://reviews/{reviewId}/artifacts/{artifactId}",
            name: "viewlens-review-artifact",
            title: "ViewLens Review Artifact",
            description: "Read a bounded binary overlay or heatmap by cataloged artifact ID",
            mimeType: "application/octet-stream",
            priority: 0.6
        )
    ]

    private static let indexResources: [MCPResource] = [
        ("reviews", "Review Catalog", "Available structured ViewLens reviews"),
        ("findings", "Finding Catalog", "Findings grouped by review"),
        ("semantic-trees", "Semantic Tree Catalog", "Available native accessibility semantic trees"),
        ("screenshots", "Screenshot Catalog", "Available review screenshots"),
        ("overlays", "Overlay Catalog", "Available annotated overlays"),
        ("baselines", "Baseline Catalog", "Available approved visual baselines"),
        ("task-logs", "Task Log Catalog", "Available bounded task logs"),
        ("reports", "Report Catalog", "Available typed and exported reports")
    ].map { slug, title, description in
        MCPResource(
            uri: "viewlens://\(slug)",
            name: slug,
            title: title,
            description: description,
            mimeType: "application/json",
            annotations: MCPResourceAnnotations(priority: slug == "findings" ? 1.0 : 0.5)
        )
    }

    private func readIndex(host: String, uri: String) throws -> MCPResourceContent {
        guard Self.indexResources.contains(where: { $0.uri == uri }) else { throw ReadError.notFound }
        switch host {
        case "findings":
            let values = sortedRecords().map { id, record in
                JSONValue.object([
                    "reviewId": .string(id),
                    "uri": .string("viewlens://reviews/\(id)/findings"),
                    "count": .number(Double(record.envelope.findings.count))
                ])
            }
            return jsonContent(uri: uri, jsonValue: .object(["available": .array(values)]))
        case "reports":
            let values = sortedRecords().map { id, _ in
                JSONValue.object(["reviewId": .string(id), "uri": .string("viewlens://reviews/\(id)/report")])
            }
            return jsonContent(uri: uri, jsonValue: .object(["available": .array(values)]))
        case "overlays", "screenshots":
            return artifactIndex(uri: uri, kinds: host == "overlays" ? ["overlay"] : ["screenshot"])
        case "reviews":
            return jsonContent(uri: uri, value: reviewIndex())
        case "semantic-trees", "baselines", "task-logs":
            return jsonContent(
                uri: uri,
                jsonValue: .object([
                    "available": .array([]),
                    "status": .string("not_available"),
                    "reason": .string("No \(host) have been produced in this server scope")
                ])
            )
        default:
            throw ReadError.notFound
        }
    }

    private func reviewIndex() -> JSONValue {
        .object([
            "available": .array(sortedRecords().map { id, record in
                .object([
                    "reviewId": .string(id),
                    "uri": .string("viewlens://reviews/\(id)"),
                    "sourceMode": .string(record.envelope.sourceMode),
                    "createdAt": .string(Self.dateString(record.createdAt))
                ])
            }),
            "limit": .number(Double(maximumReviews))
        ])
    }

    private func artifactIndex(uri: String, kinds: Set<String>) -> MCPResourceContent {
        let values = sortedRecords().flatMap { id, record in
            record.artifactSnapshots.enumerated().compactMap { index, snapshot -> JSONValue? in
                let artifact = snapshot.metadata
                guard kinds.contains(artifact.kind) else { return nil }
                return .object([
                    "reviewId": .string(id),
                    "kind": .string(artifact.kind),
                    "uri": .string("viewlens://reviews/\(id)/artifacts/\(index)"),
                    "mimeType": .string(artifact.mediaType)
                ])
            }
        }
        return jsonContent(uri: uri, jsonValue: .object(["available": .array(values)]))
    }

    private func sortedRecords() -> [(key: String, value: ReviewRecord)] {
        records.sorted {
            if $0.value.createdAt == $1.value.createdAt { return $0.key < $1.key }
            return $0.value.createdAt > $1.value.createdAt
        }
    }

    private func jsonContent<T: Encodable>(uri: String, value: T) -> MCPResourceContent {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(value)) ?? Data("{}".utf8)
        return MCPResourceContent(uri: uri, mimeType: "application/json", text: String(decoding: data, as: UTF8.self))
    }

    private func jsonContent(uri: String, jsonValue: JSONValue) -> MCPResourceContent {
        jsonContent(uri: uri, value: jsonValue)
    }

    private static func dateString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
