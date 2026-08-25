import Foundation
import CoreGraphics

/// Directional and layout alignments between UI elements.
public enum SpatialDirection: String, Codable, Sendable, Equatable {
    case above
    case below
    case leading
    case trailing
    case inside
    case contains
    case overlapping
    case adjacent
}

/// Token-efficient spatial and hierarchy query engine for AI coding agents and inspect tools.
public enum SpatialQueryEngine {

    /// Finds a node by its identifier.
    public static func findElement(
        byID id: String,
        in nodes: [NativeAccessibilityNode]
    ) -> NativeAccessibilityNode? {
        nodes.first { $0.id.rawValue == id || $0.id.description == id }
    }

    /// Finds all elements containing a given normalized point (0...1 coordinates).
    public static func findElements(
        at point: CGPoint,
        in nodes: [NativeAccessibilityNode]
    ) -> [NativeAccessibilityNode] {
        nodes.filter { node in
            guard let frame = node.frame else { return false }
            return frame.contains(point: point)
        }
    }

    /// Finds the nearest element to a point based on Euclidean center distance.
    public static func findNearestElement(
        to point: CGPoint,
        in nodes: [NativeAccessibilityNode]
    ) -> (node: NativeAccessibilityNode, distance: Double)? {
        guard !nodes.isEmpty else { return nil }

        var closest: (node: NativeAccessibilityNode, distance: Double)?

        for node in nodes {
            guard let frame = node.frame else { continue }
            let dx = frame.midX - Double(point.x)
            let dy = frame.midY - Double(point.y)
            let dist = sqrt(dx * dx + dy * dy)

            if closest == nil || dist < closest!.distance {
                closest = (node, dist)
            }
        }

        return closest
    }

    /// Finds all direct and indirect descendants of an element by ID.
    public static func findDescendants(
        of parentID: String,
        in nodes: [NativeAccessibilityNode]
    ) -> [NativeAccessibilityNode] {
        guard let parent = findElement(byID: parentID, in: nodes) else { return [] }
        let childIDs = Set(parent.children.map(\.rawValue))
        return nodes.filter { childIDs.contains($0.id.rawValue) }
    }

    /// Searches elements by visible text, label, or accessibility trait/role.
    public static func searchElements(
        query: String? = nil,
        role: String? = nil,
        in nodes: [NativeAccessibilityNode]
    ) -> [NativeAccessibilityNode] {
        nodes.filter { node in
            var matchesQuery = true
            if let q = query, !q.isEmpty {
                let labelMatch = node.label?.localizedCaseInsensitiveContains(q) == true
                let valMatch = node.value?.localizedCaseInsensitiveContains(q) == true
                let idMatch = node.id.rawValue.localizedCaseInsensitiveContains(q)
                matchesQuery = labelMatch || valMatch || idMatch
            }

            var matchesRole = true
            if let r = role, !r.isEmpty {
                matchesRole = node.traits.contains { $0.rawValue.localizedCaseInsensitiveContains(r) }
            }

            return matchesQuery && matchesRole
        }
    }

    /// Computes directional and relational layout attributes between two nodes.
    public static func computeRelationships(
        nodeA: NativeAccessibilityNode,
        nodeB: NativeAccessibilityNode
    ) -> [SpatialDirection] {
        guard let fA = nodeA.frame, let fB = nodeB.frame else { return [] }
        var rels: [SpatialDirection] = []

        if fB.contains(other: fA) {
            rels.append(.inside)
        } else if fA.contains(other: fB) {
            rels.append(.contains)
        } else if fA.intersects(other: fB) {
            rels.append(.overlapping)
        }

        if fA.maxY <= fB.minY {
            rels.append(.above)
        } else if fA.minY >= fB.maxY {
            rels.append(.below)
        }

        if fA.maxX <= fB.minX {
            rels.append(.leading)
        } else if fA.minX >= fB.maxX {
            rels.append(.trailing)
        }

        return rels
    }
}
