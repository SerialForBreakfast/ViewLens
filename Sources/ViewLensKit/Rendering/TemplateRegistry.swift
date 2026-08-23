import Foundation
import CoreGraphics

#if canImport(SwiftUI)
import SwiftUI

/// Pure SwiftUI Switch without AppKit/PlatformViewRepresentableAdaptor dependencies.
public struct ViewLensSwitch: View {
    public var label: String
    public var isOn: Bool

    public init(_ label: String, isOn: Bool) {
        self.label = label
        self.isOn = isOn
    }

    public var body: some View {
        HStack {
            Text(label)
                .dynamicBody()
            Spacer()
            Capsule()
                .fill(isOn ? Color.green : Color.gray.opacity(0.35))
                .frame(width: 46, height: 28)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(2)
                        .offset(x: isOn ? 9 : -9)
                )
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        }
    }
}

/// Pure SwiftUI Progress Bar without PlatformViewRepresentableAdaptor dependencies.
public struct ViewLensProgressBar: View {
    public var value: Double
    public var tint: Color

    public init(value: Double, tint: Color = .purple) {
        self.value = value
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 6)

                Capsule()
                    .fill(tint)
                    .frame(width: max(6, geo.size.width * CGFloat(min(1.0, max(0.0, value)))), height: 6)
            }
        }
        .frame(height: 6)
    }
}

/// Registry storing known SwiftUI view templates for headless rendering, Mac App playground, and agent iteration.
@MainActor
public final class TemplateRegistry {
    public typealias ViewFactory = @MainActor () -> AnyView
    public typealias AccessibilityFactory = @MainActor () -> [AccessibilityElementSnapshot]

    public static let shared = TemplateRegistry()

    private var templates: [String: (displayName: String, factory: ViewFactory, accessibility: AccessibilityFactory?)] = [:]

    private init() {
        registerBuiltInTemplates()
    }

    public func register(
        name: String,
        accessibility: AccessibilityFactory? = nil,
        factory: @escaping ViewFactory
    ) {
        templates[name.lowercased()] = (displayName: name, factory: factory, accessibility: accessibility)
    }

    public func template(named name: String) -> AnyView? {
        templates[name.lowercased()]?.factory()
    }

    /// Returns programmatic accessibility-tree observations supplied by a registered
    /// template. A nil result means semantic verification is unavailable and must not
    /// be reported as a WCAG 4.1.2 pass.
    public func accessibilitySnapshots(named name: String) -> [AccessibilityElementSnapshot]? {
        templates[name.lowercased()]?.accessibility?()
    }

    public var availableTemplates: [String] {
        templates.values.map { $0.displayName }.sorted()
    }

    // MARK: - Built-In Showcase & Audit Templates
    private func registerBuiltInTemplates() {
        // Complete Full-Screen Real-World Apps
        register(name: "SocialFeedView") { AnyView(SocialFeedViewTemplate()) }
        register(name: "ProfileCard") { AnyView(SocialFeedViewTemplate()) }
        register(name: "CheckoutView") { AnyView(CheckoutViewTemplate()) }
        register(name: "CryptoDashboardView") { AnyView(CryptoDashboardViewTemplate()) }
        register(name: "MusicPlayerView") { AnyView(MusicPlayerViewTemplate()) }
        register(name: "SettingsView") { AnyView(SettingsViewTemplate()) }
        register(name: "SettingsList") { AnyView(SettingsViewTemplate()) }
        register(name: "MessagingThreadView") { AnyView(MessagingThreadViewTemplate()) }
        register(name: "HealthFitnessView") { AnyView(HealthFitnessViewTemplate()) }
        register(name: "LoginForm", accessibility: {
            [
                AccessibilityElementSnapshot(identifier: "EmailTextField", label: "Email Address", role: "textField", value: "alex.apple@developer.com", requiresValue: true),
                AccessibilityElementSnapshot(identifier: "PasswordTextField", label: "Password", role: "secureTextField", value: "••••••••••••", requiresValue: true),
                AccessibilityElementSnapshot(identifier: "RememberMeToggle", label: "Remember Credentials", role: "switch", value: "On", requiresValue: true),
                AccessibilityElementSnapshot(identifier: "SignInButton", label: "Sign In", role: "button")
            ]
        }) { AnyView(LoginFormTemplate()) }
        register(name: "OnboardingView") { AnyView(OnboardingViewTemplate()) }

        // Deliberate HIG Defect Testing Templates
        register(name: "Sub44ptButtonBug", accessibility: {
            [AccessibilityElementSnapshot(identifier: "BuggySmallButton", label: "Tiny 24pt Button", role: "button")]
        }) { AnyView(Sub44ptButtonBugTemplate()) }
        register(name: "ClippedEdgeBug") { AnyView(ClippedEdgeBugTemplate()) }
        register(name: "OverlapBug") { AnyView(OverlapBugTemplate()) }
    }
}

// MARK: - 1. Full-Screen SocialFeedView Template

public struct SocialFeedViewTemplate: View {
    @State private var selectedTab = "For You"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar Header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.blue))

                Spacer()

                HStack(spacing: 16) {
                    Text("For You")
                        .dynamicHeadline()
                        .foregroundColor(selectedTab == "For You" ? .primary : .secondary)
                        .overlay(
                            Rectangle()
                                .fill(selectedTab == "For You" ? Color.blue : Color.clear)
                                .frame(height: 3)
                                .offset(y: 14),
                            alignment: .bottom
                        )

                    Text("Following")
                        .dynamicHeadline()
                        .foregroundColor(selectedTab == "Following" ? .primary : .secondary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable Timeline
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Post 1: Verified Post with Media Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 44, height: 44)
                                .overlay(Text("SJ").dynamicHeadline().foregroundColor(.white))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Steve Jobs").dynamicHeadline()
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                Text("@steve • 2h ago")
                                    .dynamicCaption()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                                .foregroundStyle(.secondary)
                        }

                        Text("Design is not just what it looks like and feels like. Design is how it works. Testing multi-device matrix layouts with ViewLens!")
                            .dynamicBody()

                        // Image Card Attachment
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 160)
                            .overlay(
                                VStack {
                                    Image(systemName: "visionpro")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.white)
                                    Text("Spatial UI Matrix")
                                        .dynamicHeadline()
                                        .foregroundStyle(.white)
                                }
                            )

                        // Engagement Action Bar
                        HStack {
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.right")
                                    Text("128").dynamicFootnote()
                                }
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            Spacer()
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.2.squarepath")
                                    Text("89").dynamicFootnote()
                                }
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            Spacer()
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart")
                                    Text("1.4k").dynamicFootnote()
                                }
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "bookmark")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    // Post 2: Developer Status Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 44, height: 44)
                                .overlay(Text("CF").dynamicHeadline().foregroundColor(.white))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Craig Federighi").dynamicHeadline()
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                Text("@craig • 4h ago")
                                    .dynamicCaption()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                        }

                        Text("Swift 6 data-race safety enabled across all targets. Zero warnings, 100% pure Swift!")
                            .dynamicBody()

                        HStack(spacing: 8) {
                            Text("#Swift6")
                                .dynamicCaption()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(8)
                                .foregroundStyle(.blue)

                            Text("#iOSDev")
                                .dynamicCaption()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(8)
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }

            Divider()

            // Bottom Navigation Tab Bar (All ≥44pt touch targets)
            HStack {
                ForEach([
                    ("house.fill", "Home"),
                    ("magnifyingglass", "Search"),
                    ("bell.fill", "Alerts"),
                    ("envelope.fill", "Messages"),
                    ("person.crop.circle", "Profile")
                ], id: \.1) { icon, name in
                    Button(action: {}) {
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                            Text(name)
                                .dynamicCaption2()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .foregroundColor(name == "Home" ? .blue : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - 2. Full-Screen CheckoutView Template

public struct CheckoutViewTemplate: View {
    @State private var useApplePay = true
    @State private var promoCode = "SWIFT2026"

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Navigation Header
            HStack {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("Checkout")
                    .dynamicTitle3()
                Spacer()
                Image(systemName: "cart.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // Step Progress Indicator
                    HStack {
                        Text("1. Cart")
                            .dynamicCaption()
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        Text("2. Shipping")
                            .dynamicCaption()
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        Text("3. Payment")
                            .dynamicCaption()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Order Items Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Order Summary (3 items)")
                            .dynamicHeadline()

                        Divider()

                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .overlay(Image(systemName: "headphones").foregroundStyle(.purple))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vision Pro Audio Strap").dynamicBody()
                                Text("Space Gray • Qty 1").dynamicCaption().foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$99.00").dynamicHeadline()
                        }

                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .overlay(Image(systemName: "battery.100.bolt").foregroundStyle(.blue))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MagSafe Battery Pack").dynamicBody()
                                Text("White • Qty 1").dynamicCaption().foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$89.00").dynamicHeadline()
                        }

                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .overlay(Image(systemName: "cable.connector").foregroundStyle(.orange))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("USB-C Woven Cable 2m").dynamicBody()
                                Text("White • Qty 1").dynamicCaption().foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$29.00").dynamicHeadline()
                        }
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    // Shipping Address Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Delivery Address").dynamicHeadline()
                            Spacer()
                            Button("Edit") {}
                                .dynamicCaption()
                                .foregroundStyle(.blue)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("1 Apple Park Way").dynamicBody()
                                Text("Cupertino, CA 95014").dynamicCaption().foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    // Payment Method & Summary
                    VStack(spacing: 12) {
                        ViewLensSwitch("Apple Pay Express", isOn: useApplePay)
                        Divider()
                        HStack {
                            Text("Subtotal").dynamicBody()
                            Spacer()
                            Text("$217.00").dynamicBody()
                        }
                        HStack {
                            Text("Express Shipping").dynamicBody()
                            Spacer()
                            Text("FREE").dynamicBody().foregroundStyle(.green)
                        }
                        Divider()
                        HStack {
                            Text("Total").dynamicTitle2()
                            Spacer()
                            Text("$217.00").dynamicTitle2().foregroundStyle(.blue)
                        }
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }

            // Floating Sticky Checkout Bar
            VStack(spacing: 8) {
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                        Text("Pay $217.00 with Apple Pay")
                            .dynamicHeadline()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .frame(minHeight: 52)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .accessibilityIdentifier("CheckoutPayButton")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - 3. Full-Screen CryptoDashboardView Template

public struct CryptoDashboardViewTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.blue))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Portfolio").dynamicCaption().foregroundStyle(.secondary)
                    Text("Joseph McCraw").dynamicHeadline()
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // Balance Hero Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Balance").dynamicCaption().foregroundStyle(.secondary)
                        Text("$48,291.50")
                            .dynamicFont(size: 34, weight: .bold, design: .rounded)

                        HStack {
                            Image(systemName: "arrow.up.right")
                            Text("+$6,240.00 (+14.8%) today").dynamicCaption().fontWeight(.semibold)
                        }
                        .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)

                    // Quick Action Buttons (All ≥44pt height)
                    HStack(spacing: 10) {
                        ForEach(["Deposit", "Send", "Swap", "Earn"], id: \.self) { action in
                            Button(action) {}
                                .dynamicCaption()
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.gray.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Live Market Watchlist
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Market Watchlist").dynamicHeadline()
                            Spacer()
                            Text("See All").dynamicCaption().foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 16)

                        VStack(spacing: 10) {
                            ForEach([
                                ("Bitcoin", "BTC", "$96,420.00", "+3.2%", Color.orange),
                                ("Ethereum", "ETH", "$3,840.50", "+5.1%", Color.blue),
                                ("Solana", "SOL", "$214.80", "-1.2%", Color.purple),
                                ("Apple Inc.", "AAPL", "$234.10", "+0.8%", Color.gray)
                            ], id: \.0) { name, symbol, price, change, color in
                                HStack {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(Text(String(symbol.prefix(1))).dynamicHeadline().foregroundColor(.white))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name).dynamicHeadline()
                                        Text(symbol).dynamicCaption().foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(price).dynamicHeadline()
                                        Text(change)
                                            .dynamicCaption()
                                            .foregroundStyle(change.hasPrefix("+") ? .green : .red)
                                    }
                                }
                                .padding(12)
                                .background(Color.gray.opacity(0.06))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Bottom Navigation
            HStack {
                ForEach([("chart.pie.fill", "Portfolio"), ("chart.line.uptrend.xyaxis", "Markets"), ("arrow.left.arrow.right", "Trade"), ("gearshape.fill", "Settings")], id: \.1) { icon, name in
                    Button(action: {}) {
                        VStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: 20))
                            Text(name).dynamicCaption2()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .foregroundColor(name == "Portfolio" ? .blue : .secondary)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - 4. Full-Screen MusicPlayerView Template

public struct MusicPlayerViewTemplate: View {
    @State private var isPlaying = true
    @State private var progress = 0.42

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Top Bar
            HStack {
                Image(systemName: "chevron.down")
                    .frame(width: 44, height: 44)
                Spacer()
                Text("Playing from Favorites").dynamicCaption().fontWeight(.semibold)
                Spacer()
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Large Album Artwork
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [.indigo, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 240, height: 240)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.85))
                )
                .shadow(color: .purple.opacity(0.35), radius: 16, y: 8)

            Spacer()

            // Track Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Midnight Starlight").dynamicTitle2()
                    Text("Synthetic Dreamer • Album of the Year").dynamicSubheadline().foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {}) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)

            // Scrubber Bar
            VStack(spacing: 6) {
                ViewLensProgressBar(value: progress, tint: .purple)
                HStack {
                    Text("1:42").dynamicCaption2().foregroundStyle(.secondary)
                    Spacer()
                    Text("-2:16").dynamicCaption2().foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)

            // Controls (All ≥44pt touch targets)
            HStack(spacing: 32) {
                Button(action: {}) {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }

                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .frame(width: 44, height: 44)
                }

                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)
                        .frame(width: 60, height: 60)
                }

                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .frame(width: 44, height: 44)
                }

                Button(action: {}) {
                    Image(systemName: "repeat")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
            }
            .foregroundStyle(.primary)

            // AirPlay Output Bar
            HStack(spacing: 8) {
                Image(systemName: "airplayaudio").foregroundStyle(.purple)
                Text("HomePod mini • Living Room").dynamicCaption()
            }
            .padding(.vertical, 8)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - 5. Full-Screen SettingsView Template

public struct SettingsViewTemplate: View {
    @State private var notifications = true
    @State private var darkMode = false
    @State private var airplaneMode = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Settings").dynamicLargeTitle()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 16) {
                    // Apple Account Card
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(Image(systemName: "person.fill").font(.title2).foregroundStyle(.blue))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Joseph McCraw").dynamicHeadline()
                            Text("Apple Account, iCloud+ and more").dynamicCaption().foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // Connectivity Section
                    VStack(spacing: 12) {
                        ViewLensSwitch("Airplane Mode", isOn: airplaneMode)
                        Divider()
                        HStack {
                            Text("Wi-Fi").dynamicBody()
                            Spacer()
                            Text("Home_5G").dynamicBody().foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        Divider()
                        HStack {
                            Text("Bluetooth").dynamicBody()
                            Spacer()
                            Text("On").dynamicBody().foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // Appearance & Notifications Section
                    VStack(spacing: 12) {
                        ViewLensSwitch("Push Notifications", isOn: notifications)
                        Divider()
                        ViewLensSwitch("Dark Appearance", isOn: darkMode)
                        Divider()
                        HStack {
                            Text("Display & Brightness").dynamicBody()
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // App Info
                    HStack {
                        Text("App Version").dynamicBody()
                        Spacer()
                        Text("1.0.0 (Build 2026.08)").dynamicBody().foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - 6. Full-Screen MessagingThreadView Template

public struct MessagingThreadViewTemplate: View {
    @State private var messageText = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }

                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(Text("CF").dynamicHeadline().foregroundColor(.orange))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Craig Federighi").dynamicHeadline()
                    Text("Active now").dynamicCaption2().foregroundStyle(.green)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "video.fill")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Chat ScrollView
            ScrollView {
                VStack(spacing: 14) {
                    // Received 1
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hey! Did you check out the new ViewLens update?")
                                .dynamicBody()
                                .padding(12)
                                .background(Color.gray.opacity(0.12))
                                .cornerRadius(16)
                            Text("10:14 AM").dynamicCaption2().foregroundStyle(.secondary).padding(.leading, 4)
                        }
                        Spacer()
                    }

                    // Sent 1
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Yes! The in-process matrix renderer and TUI are incredible.")
                                .dynamicBody()
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.blue)
                                .cornerRadius(16)
                            Text("10:15 AM • Delivered").dynamicCaption2().foregroundStyle(.secondary).padding(.trailing, 4)
                        }
                    }

                    // Received 2
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How is Dynamic Type scaling looking across devices?")
                                .dynamicBody()
                                .padding(12)
                                .background(Color.gray.opacity(0.12))
                                .cornerRadius(16)
                            Text("10:16 AM").dynamicCaption2().foregroundStyle(.secondary).padding(.leading, 4)
                        }
                        Spacer()
                    }

                    // Sent 2
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Scaling from 80% up to 312% (AX5) seamlessly!")
                                .dynamicBody()
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.blue)
                                .cornerRadius(16)
                            Text("10:17 AM • Read").dynamicCaption2().foregroundStyle(.secondary).padding(.trailing, 4)
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Message Composer Bar
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.blue)
                }

                HStack {
                    Text("iMessage").dynamicBody().foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "mic.fill").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(22)

                Button(action: {}) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - 7. Full-Screen HealthFitnessView Template

public struct HealthFitnessViewTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sunday, August 23").dynamicCaption().foregroundStyle(.secondary)
                    Text("Summary").dynamicLargeTitle()
                }
                Spacer()
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.blue))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // Activity Rings Card
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(Color.red.opacity(0.2), lineWidth: 10)
                            Circle().trim(from: 0, to: 0.85).stroke(Color.red, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                            Circle().stroke(Color.green.opacity(0.2), lineWidth: 8).padding(12)
                            Circle().trim(from: 0, to: 0.70).stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round)).padding(12).rotationEffect(.degrees(-90))
                            Circle().stroke(Color.cyan.opacity(0.2), lineWidth: 6).padding(22)
                            Circle().trim(from: 0, to: 0.90).stroke(Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round)).padding(22).rotationEffect(.degrees(-90))
                        }
                        .frame(width: 100, height: 100)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Move").dynamicHeadline().foregroundStyle(.red)
                                Spacer()
                                Text("640/500 kcal").dynamicBody().fontWeight(.semibold)
                            }
                            HStack {
                                Text("Exercise").dynamicHeadline().foregroundStyle(.green)
                                Spacer()
                                Text("42/30 min").dynamicBody().fontWeight(.semibold)
                            }
                            HStack {
                                Text("Stand").dynamicHeadline().foregroundStyle(.cyan)
                                Spacer()
                                Text("11/12 hrs").dynamicBody().fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)

                    // Metrics Grid (Steps, Heart Rate, Sleep)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "flame.fill").foregroundStyle(.orange)
                                Text("Steps").dynamicCaption().foregroundStyle(.secondary)
                            }
                            Text("9,842").dynamicTitle2()
                            Text("Goal: 10,000").dynamicCaption2().foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(14)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "heart.fill").foregroundStyle(.red)
                                Text("Heart Rate").dynamicCaption().foregroundStyle(.secondary)
                            }
                            Text("72 BPM").dynamicTitle2()
                            Text("Resting 64 BPM").dynamicCaption2().foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }

            Divider()

            // Tab Bar
            HStack {
                ForEach([("heart.text.square.fill", "Summary"), ("person.2.fill", "Sharing"), ("square.grid.2x2.fill", "Explore")], id: \.1) { icon, name in
                    Button(action: {}) {
                        VStack(spacing: 4) {
                            Image(systemName: icon).font(.system(size: 20))
                            Text(name).dynamicCaption2()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .foregroundColor(name == "Summary" ? .blue : .secondary)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

// MARK: - 8. LoginForm Template

public struct LoginFormTemplate: View {
    @State private var email = "alex.apple@developer.com"
    @State private var password = "••••••••••••"
    @State private var rememberMe = true

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(.largeTitle))
                        .foregroundStyle(.blue)
                        .accessibilityIdentifier("LoginShieldIcon")

                    Text("Welcome Back")
                        .dynamicTitle2()
                        .accessibilityIdentifier("LoginTitleText")

                    Text("Sign in to your Apple Developer account")
                        .dynamicCaption()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email Address")
                            .dynamicCaption()
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: "envelope.fill").foregroundStyle(.secondary)
                            Text(email).dynamicBody()
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(12)
                        .accessibilityIdentifier("EmailTextField")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .dynamicCaption()
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: "key.fill").foregroundStyle(.secondary)
                            Text(password).dynamicBody()
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(12)
                        .accessibilityIdentifier("PasswordTextField")
                    }

                    ViewLensSwitch("Remember Credentials", isOn: rememberMe)
                        .accessibilityIdentifier("RememberMeToggle")
                }
                .padding(.horizontal, 20)

                Button(action: {}) {
                    Text("Sign In")
                        .dynamicHeadline()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .frame(minHeight: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .accessibilityIdentifier("SignInButton")
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - 9. OnboardingView Template

public struct OnboardingViewTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button("Skip") {}
                    .dynamicSubheadline()
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)

            Spacer()

            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("AI-Powered Native Audits")
                    .dynamicTitle2()

                Text("Validate your UI across every Apple device shape, Dynamic Type level, and appearance mode.")
                    .dynamicSubheadline()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "eye.fill").font(.title2).foregroundStyle(.blue).frame(width: 32)
                    VStack(alignment: .leading) {
                        Text("Zero-Token CoreML Vision").dynamicHeadline()
                        Text("On-device YOLO element detection").dynamicCaption().foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size").font(.title2).foregroundStyle(.purple).frame(width: 32)
                    VStack(alignment: .leading) {
                        Text("Dynamic Type Reflow").dynamicHeadline()
                        Text("Simulate AX1 through AX5 font scaling").dynamicCaption().foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill").font(.title2).foregroundStyle(.green).frame(width: 32)
                    VStack(alignment: .leading) {
                        Text("Apple HIG Touch Targets").dynamicHeadline()
                        Text("Automated 44x44pt compliance enforcement").dynamicCaption().foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            Spacer()

            Button("Get Started") {}
                .dynamicHeadline()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .frame(minHeight: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }
}

// MARK: - 10. Deliberate Defect Templates (For HIG & Quality Gate Testing)

/// Deliberately defective template with a 24pt height button for HIG rule validation.
public struct Sub44ptButtonBugTemplate: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("Defect: Sub-44pt Button")
                .dynamicHeadline()

            Button("Tiny 24pt Button") {}
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

/// Deliberately defective template with zero margin edge clipping.
public struct ClippedEdgeBugTemplate: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            Button("Zero Edge Button") {}
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.orange)
                .foregroundColor(.white)
        }
    }
}

/// Deliberately defective template with overlapping elements.
public struct OverlapBugTemplate: View {
    public init() {}

    public var body: some View {
        ZStack {
            Button("Background Action") {}
                .frame(width: 200, height: 50)
                .background(Color.blue)
                .foregroundColor(.white)

            Button("Colliding Action") {}
                .frame(width: 180, height: 44)
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
        }
    }
}
#endif
