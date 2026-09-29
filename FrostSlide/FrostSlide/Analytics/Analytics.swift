import Foundation
import TelemetryDeck

/// Anonymous usage stats: which courses get raced, finished and abandoned, so hard spots and
/// dead ends show up. Nothing typed by the player, no names and no advertising ID is sent;
/// TelemetryDeck hashes a per-install identifier before it leaves the phone.
///
/// The player can switch it off in Settings (the SDK is then stopped, not just muted), and it
/// stays off until `AnalyticsConfig.appID` is filled in.
@MainActor
enum Analytics {
    enum Event {
        case raceStarted(course: Int, daily: Bool)
        case raceFinished(course: Int, place: Int, stars: Int, perfect: Bool, seconds: Double, crashes: Int)
        /// Left a race before the finish line, `progress` being how far along in percent.
        case raceAbandoned(course: Int, progress: Int)
        case dailyCompleted(streak: Int)
        case adsRemoved

        var name: String {
            switch self {
            case .raceStarted: return "Race.started"
            case .raceFinished: return "Race.finished"
            case .raceAbandoned: return "Race.abandoned"
            case .dailyCompleted: return "Daily.completed"
            case .adsRemoved: return "Store.adsRemoved"
            }
        }

        var parameters: [String: String] {
            switch self {
            case .raceStarted(let course, let daily):
                return ["course": "\(course)", "daily": daily ? "yes" : "no"]
            case .raceFinished(let course, let place, let stars, let perfect, _, let crashes):
                return [
                    "course": "\(course)",
                    "place": "\(place)",
                    "stars": "\(stars)",
                    "perfect": perfect ? "yes" : "no",
                    "crashes": "\(crashes)"
                ]
            case .raceAbandoned(let course, let progress):
                return ["course": "\(course)", "progress": "\(progress)"]
            case .dailyCompleted(let streak):
                return ["streak": "\(streak)"]
            case .adsRemoved:
                return [:]
            }
        }

        /// Numeric value shown in the dashboard: finishing time in seconds.
        var floatValue: Double? {
            if case .raceFinished(_, _, _, _, let seconds, _) = self { return seconds }
            return nil
        }
    }

    private static var running = false

    /// Starts or stops the SDK to match the player's setting. Safe to call again and again.
    static func apply(settings: GameSettings) {
        setEnabled(settings.shareUsageData)
    }

    static func setEnabled(_ enabled: Bool) {
        // Unit tests use the app as their host and must not talk to the network.
        guard AnalyticsConfig.isConfigured, !RuntimeEnvironment.isTesting else { return }
        if enabled, !running {
            TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: AnalyticsConfig.appID))
            running = true
        } else if !enabled, running {
            TelemetryDeck.terminate()
            running = false
        }
    }

    static func track(_ event: Event) {
        guard running else { return }
        TelemetryDeck.signal(event.name, parameters: event.parameters, floatValue: event.floatValue)
    }
}
