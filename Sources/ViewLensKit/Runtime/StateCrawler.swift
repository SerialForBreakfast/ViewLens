import Foundation

/// Discovered UI state types classified during state space crawling.
public enum DiscoveredStateType: String, Codable, Sendable, Equatable {
    case empty
    case loading
    case content
    case validation
    case error
    case disabled
    case expanded
    case modal
}

/// A unique UI state discovered during automated exploration.
public struct CrawledState: Codable, Sendable, Equatable {
    public let id: String
    public let stateType: DiscoveredStateType
    public let templateName: String
    public let elementCount: Int
    public let actionPath: [String]

    public init(
        id: String,
        stateType: DiscoveredStateType,
        templateName: String,
        elementCount: Int,
        actionPath: [String]
    ) {
        self.id = id
        self.stateType = stateType
        self.templateName = templateName
        self.elementCount = elementCount
        self.actionPath = actionPath
    }
}

/// Report summarizing the automated exploration of UI state space.
public struct CrawlReport: Codable, Sendable, Equatable {
    public let discoveredStates: [CrawledState]
    public let visitedStateCount: Int
    public let traversalDepth: Int
    public let detectedLoops: Int
    public let durationMs: Double

    public init(
        discoveredStates: [CrawledState],
        visitedStateCount: Int,
        traversalDepth: Int,
        detectedLoops: Int,
        durationMs: Double
    ) {
        self.discoveredStates = discoveredStates
        self.visitedStateCount = visitedStateCount
        self.traversalDepth = traversalDepth
        self.detectedLoops = detectedLoops
        self.durationMs = durationMs
    }
}

/// Bounded state space crawler exploring UI transitions and discovering interactive states (MCP-16.9, MCP-16.10).
public enum StateCrawler {

    /// Explores reachable states from a root template subject to exploration budgets.
    public static func crawl(
        templateName: String,
        nodes: [NativeAccessibilityNode],
        maxDepth: Int = 3,
        maxStates: Int = 10,
        maxDurationMs: Double = 5000
    ) -> CrawlReport {
        var states: [CrawledState] = []
        var visitedHashes = Set<String>()
        var loopCount = 0
        let startTime = Date()
        func budgetExceeded() -> Bool {
            Date().timeIntervalSince(startTime) * 1000.0 >= maxDurationMs
        }

        // 1. Initial Root State
        let rootHash = "state_root_\(nodes.count)"
        visitedHashes.insert(rootHash)

        let rootType = classifyState(nodes: nodes)
        let rootState = CrawledState(
            id: rootHash,
            stateType: rootType,
            templateName: templateName,
            elementCount: nodes.count,
            actionPath: ["initial_load"]
        )
        states.append(rootState)

        // 2. Explore interactive controls (e.g. tap buttons, expand disclosures)
        let interactiveNodes = nodes.filter { $0.traits.contains(.isButton) }

        for (idx, node) in interactiveNodes.enumerated() {
            guard states.count < maxStates else { break }
            guard idx < maxDepth else { break }
            guard !budgetExceeded() else { break }

            let path = ["initial_load", "tap(\(node.id.rawValue))"]
            let stateHash = "state_after_\(node.id.rawValue)"

            if visitedHashes.contains(stateHash) {
                loopCount += 1
                continue
            }

            visitedHashes.insert(stateHash)
            let derivedType: DiscoveredStateType = node.label?.localizedCaseInsensitiveContains("error") == true ? .error : .content
            let nextState = CrawledState(
                id: stateHash,
                stateType: derivedType,
                templateName: templateName,
                elementCount: nodes.count,
                actionPath: path
            )
            states.append(nextState)
        }

        let elapsed = Date().timeIntervalSince(startTime) * 1000.0
        return CrawlReport(
            discoveredStates: states,
            visitedStateCount: states.count,
            traversalDepth: min(maxDepth, states.count),
            detectedLoops: loopCount,
            durationMs: elapsed
        )
    }

    /// Classifies the semantic state type based on visible accessibility cues.
    public static func classifyState(nodes: [NativeAccessibilityNode]) -> DiscoveredStateType {
        if nodes.isEmpty { return .empty }
        let labels = nodes.compactMap(\.label).joined(separator: " ").lowercased()

        if labels.contains("loading") || labels.contains("please wait") { return .loading }
        if labels.contains("error") || labels.contains("failed") || labels.contains("invalid") { return .error }
        if labels.contains("empty") || labels.contains("no items") { return .empty }
        if nodes.contains(where: { $0.traits.contains(.notEnabled) }) { return .disabled }

        return .content
    }
}
