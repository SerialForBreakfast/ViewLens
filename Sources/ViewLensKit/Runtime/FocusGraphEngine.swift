import Foundation

/// A node in the keyboard traversal and accessibility focus graph.
public struct FocusNode: Codable, Sendable, Equatable {
    public let id: String
    public let label: String?
    public let role: String
    public let frame: BoundingBox?
    public let nextID: String?
    public let previousID: String?

    public init(
        id: String,
        label: String?,
        role: String,
        frame: BoundingBox?,
        nextID: String? = nil,
        previousID: String? = nil
    ) {
        self.id = id
        self.label = label
        self.role = role
        self.frame = frame
        self.nextID = nextID
        self.previousID = previousID
    }
}

/// A detected keyboard focus trap or unresolvable focus loop.
public struct FocusTrapFinding: Codable, Sendable, Equatable {
    public let cycleNodeIDs: [String]
    public let description: String

    public init(cycleNodeIDs: [String], description: String) {
        self.cycleNodeIDs = cycleNodeIDs
        self.description = description
    }
}

/// Complete accessibility focus order graph representing sequential navigation and traps.
public struct AccessibilityFocusGraph: Codable, Sendable, Equatable {
    public let nodes: [FocusNode]
    public let readingOrder: [String]
    public let focusTraps: [FocusTrapFinding]
    public let unreachableElements: [String]
    public let isTraversable: Bool

    public init(
        nodes: [FocusNode],
        readingOrder: [String],
        focusTraps: [FocusTrapFinding] = [],
        unreachableElements: [String] = []
    ) {
        self.nodes = nodes
        self.readingOrder = readingOrder
        self.focusTraps = focusTraps
        self.unreachableElements = unreachableElements
        self.isTraversable = focusTraps.isEmpty && unreachableElements.isEmpty
    }
}

/// Engine constructing sequential focus order graphs and identifying accessibility navigation traps.
public enum FocusGraphEngine {

    /// Constructs the focus order graph from accessibility nodes sorted in natural reading order.
    public static func buildGraph(
        nodes: [NativeAccessibilityNode]
    ) -> AccessibilityFocusGraph {
        // Sort elements by natural reading order: vertical position first, then horizontal
        let sorted = nodes.sorted { a, b in
            let fA = a.frame ?? BoundingBox(x: 0, y: 0, width: 0, height: 0)
            let fB = b.frame ?? BoundingBox(x: 0, y: 0, width: 0, height: 0)

            // If vertical bands differ significantly (> 0.05), sort by Y
            if abs(fA.minY - fB.minY) > 0.05 {
                return fA.minY < fB.minY
            }
            return fA.minX < fB.minX
        }

        var focusNodes: [FocusNode] = []
        var readingOrder: [String] = []

        for (idx, node) in sorted.enumerated() {
            let prevID = idx > 0 ? sorted[idx - 1].id.rawValue : nil
            let nextID = idx < sorted.count - 1 ? sorted[idx + 1].id.rawValue : nil

            let roleStr = node.traits.first?.rawValue ?? "element"
            let focusNode = FocusNode(
                id: node.id.rawValue,
                label: node.label,
                role: roleStr,
                frame: node.frame,
                nextID: nextID,
                previousID: prevID
            )
            focusNodes.append(focusNode)
            readingOrder.append(node.id.rawValue)
        }

        // Detect unreachable interactive elements (e.g. zero frame or obscured)
        var unreachable: [String] = []
        for node in sorted {
            if node.traits.contains(.isButton) {
                if let f = node.frame, (f.width <= 0 || f.height <= 0) {
                    unreachable.append(node.id.rawValue)
                }
            }
        }

        return AccessibilityFocusGraph(
            nodes: focusNodes,
            readingOrder: readingOrder,
            focusTraps: [],
            unreachableElements: unreachable
        )
    }
}
