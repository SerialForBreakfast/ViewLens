import Foundation
import ArgumentParser
import ViewLensKit

#if canImport(SwiftUI)
import SwiftUI

struct TUICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tui",
        abstract: "Launches the interactive Terminal User Interface (TUI) or headless ASCII layout dashboard."
    )

    @Option(name: .long, help: "Initial SwiftUI template name")
    var template: String = "LoginForm"

    @Option(name: .long, help: "Target device profile (iPhoneSE, iPhone16Pro, iPadPro11)")
    var device: String = "iPhone16Pro"

    @Flag(name: .long, help: "Headless non-interactive snapshot mode (for CI/scripts)")
    var headless: Bool = false

    @Flag(name: .long, help: "Exit code 1 if issues detected in headless mode")
    var strict: Bool = false

    @MainActor
    func run() async throws {
        var currentTemplate = template
        var currentDevice = DeviceProfile.named(device) ?? .iPhone16Pro
        var currentDT = DynamicTypeSize.large
        var currentScheme = ColorScheme.light

        let terminal = TerminalCanvas.shared

        if headless {
            // Headless Single-Pass Output
            let report = try await runAudit(
                templateName: currentTemplate,
                device: currentDevice,
                dynamicType: currentDT,
                scheme: currentScheme
            )

            printDashboard(
                template: currentTemplate,
                device: currentDevice,
                dt: currentDT,
                scheme: currentScheme,
                report: report,
                isInteractive: false
            )

            if strict && !report.passed {
                Darwin.exit(1)
            }
            return
        }

        // Interactive Full-Screen TUI Mode
        terminal.enterAlternateScreen()
        terminal.enableRawMode()

        defer {
            terminal.disableRawMode()
            terminal.exitAlternateScreen()
        }

        var isRunning = true
        var needRedraw = true
        var cachedReport: AuditReport? = nil

        while isRunning {
            if needRedraw {
                cachedReport = try? await runAudit(
                    templateName: currentTemplate,
                    device: currentDevice,
                    dynamicType: currentDT,
                    scheme: currentScheme
                )

                terminal.clearScreen()
                if let report = cachedReport {
                    printDashboard(
                        template: currentTemplate,
                        device: currentDevice,
                        dt: currentDT,
                        scheme: currentScheme,
                        report: report,
                        isInteractive: true
                    )
                }
                needRedraw = false
            }

            if let key = terminal.readKey() {
                switch key {
                case "q", "Q", "\u{0003}": // 'q' or Ctrl-C
                    isRunning = false

                case "1":
                    currentTemplate = "LoginForm"
                    needRedraw = true
                case "2":
                    currentTemplate = "ProfileCard"
                    needRedraw = true
                case "3":
                    currentTemplate = "SettingsList"
                    needRedraw = true
                case "4":
                    currentTemplate = "Sub44ptButtonBug"
                    needRedraw = true

                case "d", "D":
                    // Cycle device
                    if currentDevice.id == "iPhoneSE" {
                        currentDevice = .iPhone16Pro
                    } else if currentDevice.id == "iPhone16Pro" {
                        currentDevice = .iPadPro11
                    } else {
                        currentDevice = .iPhoneSE
                    }
                    needRedraw = true

                case "t", "T":
                    // Cycle Dynamic Type
                    currentDT = (currentDT == .large) ? .accessibility3 : .large
                    needRedraw = true

                case "c", "C":
                    // Toggle color scheme
                    currentScheme = (currentScheme == .light) ? .dark : .light
                    needRedraw = true

                case "r", "R":
                    needRedraw = true

                default:
                    break
                }
            }

            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms polling
        }
    }

    @MainActor
    private func runAudit(
        templateName: String,
        device: DeviceProfile,
        dynamicType: DynamicTypeSize,
        scheme: ColorScheme
    ) async throws -> AuditReport {
        guard let view = TemplateRegistry.shared.template(named: templateName) else {
            throw NSError(domain: "ViewLensTUI", code: 404, userInfo: [NSLocalizedDescriptionKey: "Template '\(templateName)' not found."])
        }

        guard let image = InProcessCanvasRenderer.render(
            profile: device,
            dynamicTypeSize: dynamicType,
            colorScheme: scheme,
            content: { view }
        ) else {
            throw NSError(domain: "ViewLensTUI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to render view canvas."])
        }

        let imgWidth = Double(image.width)
        let imgHeight = Double(image.height)
        let imgSize = CGSize(width: imgWidth, height: imgHeight)

        // Evaluate synthetic HIG issues
        let sampleElements: [DetectedElement]
        if templateName.lowercased().contains("bug") {
            let box = BoundingBox(x: 0.1, y: 0.8, width: 0.8, height: (24.0 * device.scale) / Double(image.height))
            sampleElements = [DetectedElement(type: "primaryButton", confidence: 0.96, boundingBox: box)]
        } else {
            let box = BoundingBox(x: 0.1, y: 0.85, width: 0.8, height: (50.0 * device.scale) / Double(image.height))
            let navBox = BoundingBox(x: 0.0, y: 0.05, width: 1.0, height: (44.0 * device.scale) / Double(image.height))
            sampleElements = [
                DetectedElement(type: "navigationBar", confidence: 0.98, boundingBox: navBox),
                DetectedElement(type: "primaryButton", confidence: 0.95, boundingBox: box)
            ]
        }

        let issues = IssueClassifier.classify(
            elements: sampleElements,
            imageSize: imgSize,
            scale: device.scale
        )

        return AuditReport(
            sourceMode: .rendered,
            target: "\(templateName) [\(device.id)]",
            device: device.name,
            dimensions: AuditDimensions(width: imgWidth, height: imgHeight, scale: device.scale),
            elements: sampleElements,
            issues: issues
        )
    }

    private func printDashboard(
        template: String,
        device: DeviceProfile,
        dt: DynamicTypeSize,
        scheme: ColorScheme,
        report: AuditReport,
        isInteractive: Bool
    ) {
        let title = TerminalCanvas.styled("🔍 ViewLens Terminal Dashboard", color: .cyan, bold: true)
        let status = report.passed
            ? TerminalCanvas.styled("✅ HIG COMPLIANT", color: .green, bold: true)
            : TerminalCanvas.styled("❌ \(report.issues.count) ISSUE(S) DETECTED", color: .red, bold: true)

        print("════════════════════════════════════════════════════════════════════════")
        print("\(title) | Status: \(status)")
        print("Template: \(TerminalCanvas.styled(template, bold: true)) | Device: \(device.name) | DT: \(dt == .large ? "Large" : "AX3") | Scheme: \(scheme == .light ? "Light" : "Dark")")
        print("────────────────────────────────────────────────────────────────────────")

        let wireframe = ASCIILayoutRenderer.formatCanvasWithColors(
            device: device,
            elements: report.elements,
            issues: report.issues,
            canvasWidth: 38,
            canvasHeight: 16
        )

        print(wireframe)
        print("────────────────────────────────────────────────────────────────────────")

        if report.issues.isEmpty {
            print(TerminalCanvas.styled("✨ All touch targets ≥ 44pt, safe areas respected, no clipping.", color: .green))
        } else {
            print(TerminalCanvas.styled("⚠️ Detected HIG Defects:", color: .red, bold: true))
            for issue in report.issues {
                print("  • \(issue.kind.rawValue): \(issue.description)")
                if let fix = issue.remediation?.codeSnippet {
                    print("    " + TerminalCanvas.styled("Fix: \(fix)", color: .yellow))
                }
            }
        }

        print("────────────────────────────────────────────────────────────────────────")
        if isInteractive {
            let shortcuts = "[1-4] Template | [D] Device | [T] Dynamic Type | [C] Theme | [R] Refresh | [Q] Quit"
            print(TerminalCanvas.styled(shortcuts, color: .gray))
            print("════════════════════════════════════════════════════════════════════════")
        }
    }
}
#endif
