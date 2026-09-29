import Foundation

/// Where the anonymous usage stats go.
///
/// 1. Create an app at https://dashboard.telemetrydeck.com (free tier is enough to start).
/// 2. Paste its App ID below. Until you do, analytics stays completely off.
/// 3. Update the "App Privacy" answers in App Store Connect: usage data (product interaction)
///    and a device identifier, both used for analytics only, neither linked to the player.
enum AnalyticsConfig {
    /// TODO: replace with your TelemetryDeck App ID (a UUID).
    static let appID = "YOUR-TELEMETRYDECK-APP-ID"

    static var isConfigured: Bool { !appID.hasPrefix("YOUR-") }
}
