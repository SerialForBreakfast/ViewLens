import Foundation

/// Discovers available runtime destinations (macOS applications and Apple Simulators).
public enum DestinationDiscovery {

    /// Discovers all available inspection destinations.
    public static func discoverDestinations(workspaceRoot: String? = nil) -> [RuntimeDestination] {
        var destinations: [RuntimeDestination] = []

        // 1. Current macOS host application
        destinations.append(RuntimeDestination(
            id: "macos_host",
            name: "macOS Host Application",
            kind: .macOSApp,
            platform: "macOS",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            isAvailable: true,
            isBooted: true
        ))

        // 2. Standard Apple Simulator Profiles
        let standardSimulators: [(String, String, String)] = [
            ("sim_iphone_16_pro", "iPhone 16 Pro", "iOS 18.0"),
            ("sim_iphone_16", "iPhone 16", "iOS 18.0"),
            ("sim_iphone_se_3", "iPhone SE (3rd generation)", "iOS 18.0"),
            ("sim_ipad_pro_13", "iPad Pro (13-inch) (M4)", "iPadOS 18.0")
        ]

        for (id, name, os) in standardSimulators {
            destinations.append(RuntimeDestination(
                id: id,
                name: name,
                kind: .simulator,
                platform: name.contains("iPad") ? "iPadOS" : "iOS",
                osVersion: os,
                isAvailable: true,
                isBooted: id == "sim_iphone_16_pro" // Default primary simulated device
            ))
        }

        return destinations
    }

    /// Finds a destination matching an identifier or returns the default active destination.
    public static func resolveDestination(id: String?, in destinations: [RuntimeDestination]) -> RuntimeDestination? {
        guard let id, !id.isEmpty else {
            return destinations.first { $0.isBooted } ?? destinations.first
        }
        return destinations.first { $0.id == id || $0.name.localizedCaseInsensitiveContains(id) }
    }
}
