import AppKit
import CoreGraphics
import Foundation
import ViewLensKit

public enum ReviewPersistenceState: Equatable, Sendable {
    case ready
    case migrated(fromVersion: Int)
    case unavailable(String)
    case corrupt(String)
    case migrationRequired(foundVersion: Int)

    public var displayName: String {
        switch self {
        case .ready: return "Ready"
        case .migrated(let version): return "Migrated from schema \(version)"
        case .unavailable: return "Unavailable"
        case .corrupt: return "Corrupt data"
        case .migrationRequired(let version): return "Schema \(version) requires an app update"
        }
    }
}

@MainActor
public final class FileReviewRepository: ReviewRepository {
    static let currentSchemaVersion = 3

    public private(set) var persistenceState: ReviewPersistenceState = .ready
    public let storageURL: URL?
    private var records: [UUID: ReviewRecord] = [:]
    private let fileManager: FileManager
    private var manifestURL: URL? { storageURL?.appendingPathComponent("reviews.json") }
    private var assetsURL: URL? { storageURL?.appendingPathComponent("Previews", isDirectory: true) }

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let rootURL {
            storageURL = rootURL
        } else if let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            storageURL = applicationSupport.appendingPathComponent("ViewLens/ReviewHistory", isDirectory: true)
        } else {
            storageURL = nil
        }
        prepareAndLoad()
    }

    public func save(_ review: ReviewRecord) {
        records[review.id] = review
        persist()
    }

    public func review(id: UUID) -> ReviewRecord? { records[id] }
    public func allReviews() -> [ReviewRecord] { records.values.sorted { $0.startedAt > $1.startedAt } }

    public func delete(id: UUID) {
        records[id] = nil
        if let assetsURL { try? fileManager.removeItem(at: assetsURL.appendingPathComponent("\(id.uuidString).png")) }
        persist()
    }

    public func deleteAll() {
        records.removeAll()
        if let assetsURL {
            try? fileManager.removeItem(at: assetsURL)
            try? fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        }
        persist()
    }

    public func prune(olderThan cutoff: Date) {
        let removed = records.values.filter { $0.startedAt < cutoff }.map(\.id)
        for id in removed {
            records[id] = nil
            if let assetsURL { try? fileManager.removeItem(at: assetsURL.appendingPathComponent("\(id.uuidString).png")) }
        }
        if !removed.isEmpty { persist() }
    }

    public func prunePreviewAssets(olderThan cutoff: Date?) {
        guard let assetsURL else { return }
        let ids = records.values.filter { cutoff == nil || $0.startedAt < (cutoff ?? .distantPast) }.map(\.id)
        for id in ids {
            guard var review = records[id] else { continue }
            try? fileManager.removeItem(at: assetsURL.appendingPathComponent("\(id.uuidString).png"))
            review.previewImage = nil
            records[id] = review
        }
    }

    public func storageBytes() -> Int64 {
        guard let storageURL, let enumerator = fileManager.enumerator(at: storageURL, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private func prepareAndLoad() {
        guard let storageURL, let assetsURL, let manifestURL else {
            persistenceState = .unavailable("Application Support could not be located.")
            return
        }
        do {
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            guard fileManager.fileExists(atPath: manifestURL.path) else { return }
            let data = try Data(contentsOf: manifestURL)
            let envelope = try JSONDecoder.viewLens.decode(PersistedReviewEnvelope.self, from: data)
            guard envelope.schemaVersion <= Self.currentSchemaVersion else {
                persistenceState = .migrationRequired(foundVersion: envelope.schemaVersion)
                return
            }
            records = Dictionary(uniqueKeysWithValues: envelope.reviews.map { dto in
                let previewURL = assetsURL.appendingPathComponent("\(dto.id.uuidString).png")
                return (dto.id, dto.review(previewImage: Self.loadImage(at: previewURL)))
            })
            if envelope.schemaVersion < Self.currentSchemaVersion {
                persistenceState = .migrated(fromVersion: envelope.schemaVersion)
                persist(preservingState: true)
            }
        } catch {
            persistenceState = .corrupt(error.localizedDescription)
        }
    }

    private func persist(preservingState: Bool = false) {
        guard let manifestURL, let assetsURL else {
            persistenceState = .unavailable("Review storage is unavailable.")
            return
        }
        do {
            let values = allReviews()
            for review in values {
                let imageURL = assetsURL.appendingPathComponent("\(review.id.uuidString).png")
                if let image = review.previewImage, let data = Self.pngData(image) { try data.write(to: imageURL, options: .atomic) }
            }
            let envelope = PersistedReviewEnvelope(schemaVersion: Self.currentSchemaVersion, reviews: values.map(PersistedReview.init))
            try JSONEncoder.viewLens.encode(envelope).write(to: manifestURL, options: .atomic)
            if !preservingState { persistenceState = .ready }
        } catch {
            persistenceState = .unavailable(error.localizedDescription)
        }
    }

    private static func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

private struct PersistedReviewEnvelope: Codable {
    let schemaVersion: Int
    let reviews: [PersistedReview]
}

private struct PersistedReview: Codable {
    let id: UUID
    let source: PersistedSource
    let status: PersistedStatus
    let environment: PersistedEnvironment
    let score: PersistedScore?
    let findings: [PersistedFinding]
    let elements: [DetectedElement]
    let nonvisualScreenModel: NonvisualScreenModel?
    let startedAt: Date
    let finishedAt: Date?
    let duration: TimeInterval?

    init(_ review: ReviewRecord) {
        id = review.id
        source = PersistedSource(review.source)
        status = PersistedStatus(review.status)
        environment = PersistedEnvironment(review.environment)
        if let reviewScore = review.score { score = PersistedScore(reviewScore) } else { score = nil }
        findings = review.findings.map { PersistedFinding(id: $0.id, issue: $0.issue) }
        elements = review.elements
        nonvisualScreenModel = review.nonvisualScreenModel
        startedAt = review.startedAt
        finishedAt = review.finishedAt
        duration = review.duration
    }

    func review(previewImage: CGImage?) -> ReviewRecord {
        ReviewRecord(
            id: id,
            source: source.value,
            status: status.value,
            environment: environment.value,
            score: score?.value,
            findings: findings.map { ReviewFinding(id: $0.id, issue: $0.issue) },
            elements: elements,
            previewImage: previewImage,
            nonvisualScreenModel: nonvisualScreenModel,
            startedAt: startedAt,
            finishedAt: finishedAt,
            duration: duration
        )
    }
}

private struct PersistedFinding: Codable { let id: String; let issue: ViewLensIssue }

private struct PersistedSource: Codable {
    let kind: String; let storedValue: String
    init(_ source: ReviewSource) {
        switch source { case .template(let name): kind = "template"; storedValue = name; case .image(let url): kind = "image"; storedValue = url.path }
    }
    var value: ReviewSource { kind == "template" ? .template(name: storedValue) : .image(url: URL(fileURLWithPath: storedValue)) }

    enum CodingKeys: String, CodingKey { case kind; case storedValue = "value" }
}

private struct PersistedStatus: Codable {
    let kind: String; let message: String?; let phase: ReviewPhase?; let queuePosition: Int?
    init(_ status: ReviewStatus) {
        phase = { if case .running(let phase) = status { return phase }; return nil }()
        queuePosition = { if case .queued(let position) = status { return position }; return nil }()
        switch status {
        case .idle: kind = "idle"; message = nil
        case .preparing: kind = "preparing"; message = nil
        case .queued: kind = "queued"; message = nil
        case .running: kind = "running"; message = nil
        case .completed: kind = "completed"; message = nil
        case .incomplete(let reason): kind = "incomplete"; message = reason
        case .failed(let failure): kind = "failed"; message = failure.message
        case .cancelled: kind = "cancelled"; message = nil
        case .stale(let reason): kind = "stale"; message = reason
        }
    }
    var value: ReviewStatus {
        switch kind {
        case "preparing": return .preparing
        case "queued": return .queued(position: queuePosition)
        case "running": return .running(phase ?? .preparing)
        case "completed": return .completed
        case "incomplete": return .incomplete(reason: message ?? "Limited coverage")
        case "failed": return .failed(ReviewFailure(title: "Review failed", message: message ?? "Unknown persistence error"))
        case "cancelled": return .cancelled
        case "stale": return .stale(reason: message ?? "Source changed")
        default: return .idle
        }
    }
}

private struct PersistedEnvironment: Codable {
    let deviceID: String?; let deviceName: String?; let dynamicType: String?; let appearance: String?; let wcagLevel: String; let detectorName: String?
    init(_ value: ReviewEnvironment) {
        deviceID = value.deviceID; deviceName = value.deviceName; dynamicType = value.dynamicType; appearance = value.appearance; wcagLevel = value.wcagLevel; detectorName = value.detectorName
    }
    var value: ReviewEnvironment { ReviewEnvironment(deviceID: deviceID, deviceName: deviceName, dynamicType: dynamicType, appearance: appearance, wcagLevel: wcagLevel, detectorName: detectorName) }
}

private struct PersistedScore: Codable {
    let valueNumber: Int; let evaluatedCriteria: Int; let totalCriteria: Int
    init(_ score: ReviewScore) { valueNumber = score.value; evaluatedCriteria = score.evaluatedCriteria; totalCriteria = score.totalCriteria }
    var value: ReviewScore { ReviewScore(value: valueNumber, evaluatedCriteria: evaluatedCriteria, totalCriteria: totalCriteria) }

    enum CodingKeys: String, CodingKey { case valueNumber = "value", evaluatedCriteria, totalCriteria }
}

private extension JSONEncoder {
    static var viewLens: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder }
}
private extension JSONDecoder {
    static var viewLens: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}
