import Foundation

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Deterministic Fixture Flow Templates (MCP-15.13)
//
// A family of small, purpose-built SwiftUI templates — one per UI state category the
// interaction/state-crawling engines need to exercise (navigation, forms, scroll content,
// dialogs, menus, validation, loading, failure, accessibility). Each is deterministic: fixed
// strings, fixed counts, no `Date()`/network/randomness in rendered content. They pair with
// a matching, non-empty accessibility snapshot so `StateCrawler`/`FlowReplayEngine`/audit
// tools have real, meaningful content to run against today.

public struct FixtureFlowNavigationTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Text("Fixture Flow")
                .dynamicTitle2()
                .padding(.top, 20)
                .accessibilityIdentifier("NavigationTitle")

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(["Home", "Search", "Profile"], id: \.self) { destination in
                        Text(destination)
                            .dynamicBody()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(destination == "Home" ? Color.blue.opacity(0.15) : Color.clear)
                            .cornerRadius(10)
                            .accessibilityIdentifier("NavDestination_\(destination)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Divider()

            HStack {
                ForEach(["Home", "Search", "Profile"], id: \.self) { tab in
                    VStack(spacing: 4) {
                        Image(systemName: tab == "Home" ? "house.fill" : (tab == "Search" ? "magnifyingglass" : "person.fill"))
                        Text(tab).dynamicCaption()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(tab == "Home" ? .blue : .secondary)
                    .accessibilityIdentifier("TabBar_\(tab)")
                }
            }
            .padding(.vertical, 8)
        }
    }
}

public struct FixtureFlowFormTemplate: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Contact Form")
                    .dynamicTitle2()
                    .accessibilityIdentifier("FormTitle")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Full Name").dynamicCaption().foregroundStyle(.secondary)
                    Text("Jordan Rivera")
                        .dynamicBody()
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(10)
                        .accessibilityIdentifier("FullNameField")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email").dynamicCaption().foregroundStyle(.secondary)
                    Text("jordan.rivera@example.com")
                        .dynamicBody()
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(10)
                        .accessibilityIdentifier("EmailField")
                }

                ViewLensSwitch("Subscribe to updates", isOn: true)
                    .accessibilityIdentifier("SubscribeToggle")

                Button(action: {}) {
                    Text("Submit")
                        .dynamicHeadline()
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .accessibilityIdentifier("SubmitButton")
            }
            .padding(20)
        }
    }
}

public struct FixtureFlowScrollTemplate: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(1...40, id: \.self) { index in
                    HStack {
                        Text("Item \(index)")
                            .dynamicBody()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("ScrollRow_\(index)")
                    Divider()
                }
            }
        }
    }
}

public struct FixtureFlowDialogTemplate: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Delete Item?")
                    .dynamicHeadline()
                    .accessibilityIdentifier("DialogTitle")

                Text("This action cannot be undone.")
                    .dynamicBody()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("DialogMessage")

                HStack(spacing: 12) {
                    Button(action: {}) {
                        Text("Cancel")
                            .dynamicBody()
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.gray.opacity(0.18))
                            .cornerRadius(10)
                    }
                    .accessibilityIdentifier("DialogCancelButton")

                    Button(action: {}) {
                        Text("Delete")
                            .dynamicBody()
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .accessibilityIdentifier("DialogDeleteButton")
                }
            }
            .padding(20)
            .background(Color(white: 0.98))
            .cornerRadius(16)
            .padding(40)
            .accessibilityIdentifier("DialogCard")
        }
    }
}

public struct FixtureFlowMenuTemplate: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sort By").dynamicTitle2().padding([.top, .horizontal], 20)

            VStack(spacing: 0) {
                ForEach(["Newest", "Oldest", "Most Popular"], id: \.self) { option in
                    HStack {
                        Text(option).dynamicBody()
                        Spacer()
                        if option == "Newest" {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("MenuOption_\(option.replacingOccurrences(of: " ", with: ""))")
                    Divider()
                }
            }
            .padding(.top, 12)

            Spacer()
        }
    }
}

public struct FixtureFlowValidationTemplate: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign Up").dynamicTitle2().accessibilityIdentifier("ValidationFormTitle")

            VStack(alignment: .leading, spacing: 6) {
                Text("Email").dynamicCaption().foregroundStyle(.secondary)
                Text("not-an-email")
                    .dynamicBody()
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 1))
                    .cornerRadius(10)
                    .accessibilityIdentifier("EmailField")

                Text("Email is invalid")
                    .dynamicCaption()
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("EmailValidationError")
            }

            Button(action: {}) {
                Text("Create Account")
                    .dynamicHeadline()
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityIdentifier("CreateAccountButton")

            Spacer()
        }
        .padding(20)
    }
}

public struct FixtureFlowLoadingTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .accessibilityIdentifier("LoadingSpinner")
            Text("Loading…")
                .dynamicBody()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("LoadingLabel")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

public struct FixtureFlowFailureTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .accessibilityIdentifier("FailureIcon")
            Text("Something went wrong")
                .dynamicHeadline()
                .accessibilityIdentifier("FailureTitle")
            Text("We couldn't load this content. Please try again.")
                .dynamicBody()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("FailureMessage")
            Button(action: {}) {
                Text("Retry")
                    .dynamicBody()
                    .frame(minWidth: 120, minHeight: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .accessibilityIdentifier("RetryButton")
            Spacer()
        }
    }
}

public struct FixtureFlowAccessibilityTemplate: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Accessibility Showcase")
                    .dynamicTitle2()
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ShowcaseHeader")

                Image(systemName: "star.fill")
                    .font(.system(.largeTitle))
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Featured item")
                    .accessibilityIdentifier("FeaturedStarIcon")

                Button(action: {}) {
                    Text("Add to Favorites")
                        .dynamicBody()
                        .frame(minHeight: 50)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(10)
                }
                .accessibilityHint("Adds this item to your favorites list")
                .accessibilityIdentifier("FavoriteButton")

                ViewLensSwitch("Notifications", isOn: false)
                    .accessibilityIdentifier("NotificationsToggle")
                    .accessibilityHint("Turns on push notifications for this item")
            }
            .padding(20)
        }
    }
}

extension TemplateRegistry {
    /// Registers the deterministic fixture-flow template family used by MCP-15.13 (state
    /// crawling, locale stress, and doctor readiness checks all exercise these by name).
    func registerFixtureFlowTemplates() {
        register(name: "FixtureFlowNavigation", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "NavDestination_Home", label: "Home", role: "button"),
                AccessibilityElementSnapshot(identifier: "NavDestination_Search", label: "Search", role: "button"),
                AccessibilityElementSnapshot(identifier: "NavDestination_Profile", label: "Profile", role: "button")
            ]
        }) { AnyView(FixtureFlowNavigationTemplate()) }

        register(name: "FixtureFlowForm", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "FullNameField", label: "Full Name", role: "textField", value: "Jordan Rivera", requiresValue: true),
                AccessibilityElementSnapshot(identifier: "EmailField", label: "Email", role: "textField", value: "jordan.rivera@example.com", requiresValue: true),
                AccessibilityElementSnapshot(identifier: "SubscribeToggle", label: "Subscribe to updates", role: "switch", value: "On", requiresValue: true),
                AccessibilityElementSnapshot(identifier: "SubmitButton", label: "Submit", role: "button")
            ]
        }) { AnyView(FixtureFlowFormTemplate()) }

        register(name: "FixtureFlowScroll", accessibility: {
            (1...40).map { index in
                AccessibilityElementSnapshot(identifier: "ScrollRow_\(index)", label: "Item \(index)", role: "text")
            }
        }) { AnyView(FixtureFlowScrollTemplate()) }

        register(name: "FixtureFlowDialog", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "DialogTitle", label: "Delete Item?", role: "header"),
                AccessibilityElementSnapshot(identifier: "DialogMessage", label: "This action cannot be undone.", role: "text"),
                AccessibilityElementSnapshot(identifier: "DialogCancelButton", label: "Cancel", role: "button"),
                AccessibilityElementSnapshot(identifier: "DialogDeleteButton", label: "Delete", role: "button")
            ]
        }) { AnyView(FixtureFlowDialogTemplate()) }

        register(name: "FixtureFlowMenu", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "MenuOption_Newest", label: "Newest", role: "button"),
                AccessibilityElementSnapshot(identifier: "MenuOption_Oldest", label: "Oldest", role: "button"),
                AccessibilityElementSnapshot(identifier: "MenuOption_MostPopular", label: "Most Popular", role: "button")
            ]
        }) { AnyView(FixtureFlowMenuTemplate()) }

        register(name: "FixtureFlowValidation", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "EmailField", label: "Email", role: "textField", value: "not-an-email", requiresValue: true),
                AccessibilityElementSnapshot(identifier: "EmailValidationError", label: "Email is invalid", role: "text"),
                AccessibilityElementSnapshot(identifier: "CreateAccountButton", label: "Create Account", role: "button")
            ]
        }) { AnyView(FixtureFlowValidationTemplate()) }

        register(name: "FixtureFlowLoading", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "LoadingSpinner", label: "Loading", role: "progressIndicator"),
                AccessibilityElementSnapshot(identifier: "LoadingLabel", label: "Loading…", role: "text")
            ]
        }) { AnyView(FixtureFlowLoadingTemplate()) }

        register(name: "FixtureFlowFailure", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "FailureTitle", label: "Something went wrong", role: "header"),
                AccessibilityElementSnapshot(identifier: "FailureMessage", label: "We couldn't load this content. Please try again.", role: "text"),
                AccessibilityElementSnapshot(identifier: "RetryButton", label: "Retry", role: "button")
            ]
        }) { AnyView(FixtureFlowFailureTemplate()) }

        register(name: "FixtureFlowAccessibility", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "ShowcaseHeader", label: "Accessibility Showcase", role: "header"),
                AccessibilityElementSnapshot(identifier: "FeaturedStarIcon", label: "Featured item", role: "image"),
                AccessibilityElementSnapshot(identifier: "FavoriteButton", label: "Add to Favorites", role: "button"),
                AccessibilityElementSnapshot(identifier: "NotificationsToggle", label: "Notifications", role: "switch", value: "Off", requiresValue: true)
            ]
        }) { AnyView(FixtureFlowAccessibilityTemplate()) }
    }
}
#endif
