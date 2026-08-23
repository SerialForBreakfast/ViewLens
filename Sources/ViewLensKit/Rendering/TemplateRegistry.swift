import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI

/// Registry storing known SwiftUI view templates for headless rendering and agent iteration.
@MainActor
public final class TemplateRegistry {
    public typealias ViewFactory = @MainActor () -> AnyView

    public static let shared = TemplateRegistry()

    private var templates: [String: ViewFactory] = [:]

    private init() {
        registerBuiltInTemplates()
    }

    public func register(name: String, factory: @escaping ViewFactory) {
        templates[name.lowercased()] = factory
    }

    public func template(named name: String) -> AnyView? {
        templates[name.lowercased()]?()
    }

    public var availableTemplates: [String] {
        Array(templates.keys).sorted()
    }

    // MARK: - Built-In Showcase & Audit Templates
    private func registerBuiltInTemplates() {
        // 1. LoginForm - Classic authentication layout with potential touch-target / safe area edge cases
        register(name: "LoginForm") {
            AnyView(LoginFormTemplate())
        }

        // 2. ProfileCard - Layout with overlapping text / avatar and action buttons
        register(name: "ProfileCard") {
            AnyView(ProfileCardTemplate())
        }

        // 3. SettingsList - Standard list with navigation bar and toggles
        register(name: "SettingsList") {
            AnyView(SettingsListTemplate())
        }

        // 4. Sub44ptButtonBug - Explicit buggy template for HIG touch target regression testing
        register(name: "Sub44ptButtonBug") {
            AnyView(Sub44ptButtonBugTemplate())
        }
    }
}

// MARK: - Sample View Templates

public struct LoginFormTemplate: View {
    @State private var email = "alex.apple@developer.com"
    @State private var password = "••••••••••••"
    @State private var rememberMe = true

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            // Navigation / Header Area
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("LoginShieldIcon")

                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("LoginTitleText")
            }
            .padding(.top, 40)

            // Form Inputs
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("EmailTextField")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("PasswordTextField")
                }

                Toggle("Remember Credentials", isOn: $rememberMe)
                    .font(.subheadline)
                    .accessibilityIdentifier("RememberMeToggle")
            }
            .padding(.horizontal, 24)

            Spacer()

            // Primary Action Button (Compliant 50pt height)
            Button(action: {}) {
                Text("Sign In")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityIdentifier("SignInButton")
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

public struct ProfileCardTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)
                )

            Text("Taylor Swift")
                .font(.title3)
                .fontWeight(.bold)

            Text("Senior iOS Engineer")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Message") {}
                    .buttonStyle(.borderedProminent)
                    .frame(height: 44)

                Button("Follow") {}
                    .buttonStyle(.bordered)
                    .frame(height: 44)
            }
        }
        .padding()
    }
}

public struct SettingsListTemplate: View {
    @State private var notifications = true
    @State private var darkMode = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack {
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            Divider()

            List {
                Toggle("Push Notifications", isOn: $notifications)
                Toggle("Dark Appearance", isOn: $darkMode)
                HStack {
                    Text("App Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Deliberately defective template with a 24pt height button for HIG rule validation.
public struct Sub44ptButtonBugTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("Defect Test Screen")
                .font(.headline)

            // Defective button: only 24pt height (below 44pt HIG minimum)
            Button("Sub-44pt Tap Target") {}
                .font(.caption)
                .frame(width: 140, height: 24)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(4)
                .accessibilityIdentifier("BuggySmallButton")
        }
        .padding()
    }
}
#endif
