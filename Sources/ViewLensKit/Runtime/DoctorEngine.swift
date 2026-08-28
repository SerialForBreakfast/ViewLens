import Foundation
#if os(macOS) && !targetEnvironment(macCatalyst)
import ApplicationServices
import CoreGraphics
#endif

/// Category of an environment-readiness diagnostic check performed by ``DoctorEngine``.
public enum DoctorCheckCategory: String, Codable, Sendable, CaseIterable {
    case model
    case xcode
    case simulator
    case permissions
    case signing
    case destination
    case fixture
}

/// Single source of truth for ViewLens environment-readiness diagnostics.
///
/// Consolidates logic previously duplicated across the CLI (`viewlens doctor`), the MCP
/// `viewlens_doctor` tool, and the companion macOS app's status view.
public enum DoctorEngine {

    /// Categories whose failures are load-bearing for `DoctorReport.status == "ready"`.
    /// Every other category's failures still appear in `checks`, but are advisory only —
    /// many ViewLens workflows (screenshot audit, template rendering) never need Xcode,
    /// simulators, or system permissions at all.
    static let readinessBlockingCategories: Set<DoctorCheckCategory> = [.model, .destination]

    /// Injectable shell-command seam so tests can stub Xcode/simctl/security output
    /// deterministically instead of depending on the host machine's actual toolchain state.
    /// Only ever mutated serially by tests, never concurrently in production, so the
    /// unchecked-Sendable escape hatch is safe here.
    nonisolated(unsafe) static var runShellCommand: (_ executablePath: String, _ arguments: [String]) -> (exitCode: Int32, stdout: String) = { executablePath, arguments in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, "")
        }
    }

    /// Runs the full diagnostic suite, or a subset restricted to `categories`.
    public static func run(
        customModelPath: String? = nil,
        workspaceRoot: String? = nil,
        categories: Set<DoctorCheckCategory> = Set(DoctorCheckCategory.allCases)
    ) async -> DoctorReport {
        var checks: [DiagnosticCheck] = []
        var blockingFailure = false

        func append(_ category: DoctorCheckCategory, _ newChecks: [DiagnosticCheck]) {
            checks.append(contentsOf: newChecks)
            if readinessBlockingCategories.contains(category), newChecks.contains(where: { $0.status == "failed" }) {
                blockingFailure = true
            }
        }

        if categories.contains(.model) {
            append(.model, modelChecks(customPath: customModelPath))
        }
        if categories.contains(.xcode) {
            append(.xcode, xcodeChecks())
        }
        if categories.contains(.simulator) {
            append(.simulator, simulatorChecks())
        }
        if categories.contains(.permissions) {
            append(.permissions, permissionChecks())
        }
        if categories.contains(.signing) {
            append(.signing, signingChecks(workspaceRoot: workspaceRoot))
        }
        if categories.contains(.destination) {
            append(.destination, destinationChecks(workspaceRoot: workspaceRoot))
        }
        if categories.contains(.fixture) {
            append(.fixture, await fixtureChecks())
        }

        let overallStatus = blockingFailure ? "not_ready" : "ready"
        let recommendedNextCommand = blockingFailure
            ? recommendedRecoveryCommand(from: checks)
            : "viewlens scan <image-path>"

        return DoctorReport(status: overallStatus, checks: checks, recommendedNextCommand: recommendedNextCommand)
    }

    // MARK: - Model

    static func modelChecks(customPath: String?) -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []

        let modelResult = ModelLocator.resolve(customPath: customPath)
        let resolvedURL: URL?

        switch modelResult {
        case .success(let url):
            resolvedURL = url
            checks.append(DiagnosticCheck(name: "model_found", status: "confirmed", detail: url.path))
        case .failure(let error):
            resolvedURL = nil
            checks.append(DiagnosticCheck(name: "model_found", status: "failed", detail: error.localizedDescription))
        }

        if let url = resolvedURL {
            do {
                let sizeBytes = try ModelLocator.calculateSize(at: url)
                let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
                let formattedMB = String(format: "%.1fMB", sizeMB)

                if sizeMB <= ModelLocator.maxExpectedSizeMB && sizeMB > 0.1 {
                    checks.append(DiagnosticCheck(name: "model_size", status: "confirmed", detail: "\(formattedMB) (< \(Int(ModelLocator.maxExpectedSizeMB))MB)"))
                } else {
                    checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: "\(formattedMB) exceeds expectation"))
                }
            } catch {
                checks.append(DiagnosticCheck(name: "model_size", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_size", status: "skipped", detail: "Model not found"))
        }

        if let url = resolvedURL {
            let start = DispatchTime.now()
            do {
                _ = try YOLODetector(modelURL: url)
                let end = DispatchTime.now()
                let elapsedSeconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000.0
                checks.append(DiagnosticCheck(name: "model_loads", status: "confirmed", detail: String(format: "Cold load: %.2fs", elapsedSeconds)))
            } catch {
                checks.append(DiagnosticCheck(name: "model_loads", status: "failed", detail: error.localizedDescription))
            }
        } else {
            checks.append(DiagnosticCheck(name: "model_loads", status: "skipped", detail: "Model not found"))
        }

        return checks
    }

    // MARK: - Xcode

    static func xcodeChecks() -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []

        let versionResult = runShellCommand("/usr/bin/xcrun", ["xcodebuild", "-version"])
        if versionResult.exitCode == 0, let versionLine = versionResult.stdout.split(separator: "\n").first {
            checks.append(DiagnosticCheck(name: "xcode_installed", status: "confirmed", detail: String(versionLine)))
        } else {
            checks.append(DiagnosticCheck(
                name: "xcode_installed",
                status: "failed",
                detail: "xcodebuild is unavailable. A full Xcode install (not just Command Line Tools) is required for live app launch/build workflows."
            ))
        }

        let selectResult = runShellCommand("/usr/bin/xcode-select", ["-p"])
        if selectResult.exitCode == 0, !selectResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            checks.append(DiagnosticCheck(name: "xcode_version", status: "confirmed", detail: selectResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)))
        } else {
            checks.append(DiagnosticCheck(name: "xcode_version", status: "failed", detail: "No active developer directory resolved by xcode-select -p"))
        }

        return checks
    }

    // MARK: - Simulator

    static func simulatorChecks() -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []

        let listResult = runShellCommand("/usr/bin/xcrun", ["simctl", "list", "devices", "--json"])
        guard listResult.exitCode == 0, let data = listResult.stdout.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devicesByRuntime = parsed["devices"] as? [String: [[String: Any]]] else {
            checks.append(DiagnosticCheck(name: "simulator_runtime_available", status: "failed", detail: "Unable to list simulator runtimes via xcrun simctl"))
            checks.append(DiagnosticCheck(name: "simulator_device_available", status: "failed", detail: "Unable to list simulator devices via xcrun simctl"))
            return checks
        }

        let hasRuntime = !devicesByRuntime.isEmpty
        checks.append(hasRuntime
            ? DiagnosticCheck(name: "simulator_runtime_available", status: "confirmed", detail: "\(devicesByRuntime.count) simulator runtime(s) installed")
            : DiagnosticCheck(name: "simulator_runtime_available", status: "failed", detail: "No simulator runtimes installed"))

        let allDevices = devicesByRuntime.values.flatMap { $0 }
        let availableDevices = allDevices.filter { ($0["isAvailable"] as? Bool) == true }
        checks.append(!availableDevices.isEmpty
            ? DiagnosticCheck(name: "simulator_device_available", status: "confirmed", detail: "\(availableDevices.count) available simulator device(s)")
            : DiagnosticCheck(name: "simulator_device_available", status: "failed", detail: "No available simulator devices found"))

        return checks
    }

    // MARK: - Permissions

    static func permissionChecks() -> [DiagnosticCheck] {
        var checks: [DiagnosticCheck] = []

        #if os(macOS) && !targetEnvironment(macCatalyst)
        let accessibilityTrusted = AXIsProcessTrusted()
        checks.append(DiagnosticCheck(
            name: "accessibility_permission",
            status: accessibilityTrusted ? "confirmed" : "failed",
            detail: accessibilityTrusted
                ? "Accessibility access is granted"
                : "Grant Accessibility access to this process in System Settings \u{2192} Privacy & Security \u{2192} Accessibility"
        ))

        let screenRecordingGranted = CGPreflightScreenCaptureAccess()
        checks.append(DiagnosticCheck(
            name: "screen_recording_permission",
            status: screenRecordingGranted ? "confirmed" : "failed",
            detail: screenRecordingGranted
                ? "Screen Recording access is granted"
                : "Grant Screen Recording access to this process in System Settings \u{2192} Privacy & Security \u{2192} Screen Recording"
        ))
        #else
        checks.append(DiagnosticCheck(name: "accessibility_permission", status: "skipped", detail: "Not applicable on this platform"))
        checks.append(DiagnosticCheck(name: "screen_recording_permission", status: "skipped", detail: "Not applicable on this platform"))
        #endif

        // Automation (AppleEvents) permission has no non-invasive preflight API. Triggering a
        // real AppleEvent just to test it would show a first-run consent prompt and fail on
        // headless/CI runs, so this is deliberately reported as unevaluated rather than guessed.
        checks.append(DiagnosticCheck(
            name: "automation_permission",
            status: "skipped",
            detail: "Automation permission cannot be preflighted without triggering a consent prompt; verify manually via System Settings \u{2192} Privacy & Security \u{2192} Automation."
        ))

        return checks
    }

    // MARK: - Signing

    static func signingChecks(workspaceRoot: String?) -> [DiagnosticCheck] {
        guard workspaceRoot != nil else {
            return [DiagnosticCheck(name: "signing_identity", status: "skipped", detail: "No workspace root supplied")]
        }

        let result = runShellCommand("/usr/bin/security", ["find-identity", "-v", "-p", "codesigning"])
        let hasValidIdentity = result.exitCode == 0 && !result.stdout.contains("0 valid identities found")
        return [DiagnosticCheck(
            name: "signing_identity",
            status: hasValidIdentity ? "confirmed" : "failed",
            detail: hasValidIdentity ? "A valid codesigning identity was found" : "No valid codesigning identity found via security find-identity"
        )]
    }

    // MARK: - Destination

    static func destinationChecks(workspaceRoot: String?) -> [DiagnosticCheck] {
        let destinations = DestinationDiscovery.discoverDestinations(workspaceRoot: workspaceRoot)
        let available = destinations.filter(\.isAvailable)
        return [DiagnosticCheck(
            name: "destination_resolved",
            status: available.isEmpty ? "failed" : "confirmed",
            detail: available.isEmpty
                ? "No available inspection destinations resolved"
                : "\(available.count) destination(s) available, including \(available.first?.name ?? "unknown")"
        )]
    }

    // MARK: - Fixture

    static func fixtureChecks() async -> [DiagnosticCheck] {
        let requiredTemplates = [
            "FixtureFlowNavigation", "FixtureFlowForm", "FixtureFlowScroll", "FixtureFlowDialog",
            "FixtureFlowMenu", "FixtureFlowValidation", "FixtureFlowLoading", "FixtureFlowFailure",
            "FixtureFlowAccessibility"
        ]
        let available = await MainActor.run { TemplateRegistry.shared.availableTemplates }
        let missing = requiredTemplates.filter { name in !available.contains { $0.localizedCaseInsensitiveCompare(name) == .orderedSame } }

        if missing.isEmpty && !available.isEmpty {
            return [DiagnosticCheck(name: "fixture_app_ready", status: "confirmed", detail: "All \(requiredTemplates.count) fixture templates are registered")]
        }
        return [DiagnosticCheck(name: "fixture_app_ready", status: "skipped", detail: "Fixture templates not yet registered: \(missing.joined(separator: ", "))")]
    }

    // MARK: - Recovery

    private static func recommendedRecoveryCommand(from checks: [DiagnosticCheck]) -> String {
        if checks.contains(where: { $0.name == "model_found" && $0.status == "failed" }) {
            return "export VIEWLENS_MODEL_PATH=/path/to/best.mlpackage"
        }
        if checks.contains(where: { $0.name == "destination_resolved" && $0.status == "failed" }) {
            return "Confirm a booted simulator or the macOS host is reachable, then retry"
        }
        return "export VIEWLENS_MODEL_PATH=/path/to/best.mlpackage"
    }
}
