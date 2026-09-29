import SwiftUI

enum FrostTheme {
    static let ink = Color(red: 0.10, green: 0.20, blue: 0.30)
    static let inkSoft = Color(red: 0.22, green: 0.36, blue: 0.48)
    static let ice = Color(red: 0.18, green: 0.62, blue: 1.00)
    static let iceDeep = Color(red: 0.08, green: 0.38, blue: 0.78)
    static let cream = Color(red: 0.96, green: 0.98, blue: 1.00)
    static let snow = Color(red: 0.91, green: 0.95, blue: 0.99)
    static let ochre = Color(red: 0.90, green: 0.70, blue: 0.30)
    static let berry = Color(red: 1.00, green: 0.31, blue: 0.45)
    static let pine = Color(red: 0.18, green: 0.55, blue: 0.42)
    static let grape = Color(red: 0.55, green: 0.38, blue: 0.82)
    static let night = Color(red: 0.07, green: 0.10, blue: 0.22)

    static let titleFont = Font.custom("AvenirNext-Heavy", size: 44)
    static let displayFont = Font.custom("AvenirNext-Bold", size: 28)
    static let bodyFont = Font.custom("AvenirNext-Medium", size: 16)
    static let captionFont = Font.custom("AvenirNext-DemiBold", size: 13)

    static func placeWord(_ place: Int) -> String {
        switch place {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(place)th"
        }
    }

    static func formatTime(_ t: TimeInterval) -> String {
        guard t < 9000 else { return "--'--\"" }
        let minutes = Int(t) / 60
        let seconds = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%d'%05.2f\"", minutes, seconds)
    }

    /// Whole-second target such as a par time: 0'42".
    static func formatPar(_ t: TimeInterval) -> String {
        let whole = Int(t.rounded())
        return String(format: "%d'%02d\"", whole / 60, whole % 60)
    }

    /// A signed gap in seconds, always with its sign: +0.42 or -1.30.
    static func formatGap(_ seconds: TimeInterval) -> String {
        String(format: "%+.2f", seconds)
    }
}

struct SnowfallOverlay: View {
    var density: Int = 28
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Also still under unit tests, so snapshot pictures don't depend on the clock.
        if reduceMotion || RuntimeEnvironment.isTesting {
            Color.clear
        } else {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<density {
                    let seed = Double(i * 97)
                    let x = (sin(seed) * 0.5 + 0.5) * size.width
                    let speed = 18 + Double(i % 7) * 7
                    let y = (t * speed + seed * 13).truncatingRemainder(dividingBy: Double(size.height + 40)) - 20
                    let r = 1.2 + CGFloat(i % 4)
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55)))
                }
            }
        }
        .allowsHitTesting(false)
        }
    }
}

struct FrostCard<Content: View>: View {
    var tint: Color = .white
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(tint.opacity(0.78))
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: FrostTheme.iceDeep.opacity(0.12), radius: 18, y: 8)
    }
}

struct FrostButton: View {
    var title: String
    var subtitle: String?
    var icon: String?
    var color: Color = FrostTheme.ice
    var foreground: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                }
                VStack(spacing: 1) {
                    Text(title)
                        .font(.custom("AvenirNext-Bold", size: 18))
                    if let subtitle {
                        Text(subtitle)
                            .font(.custom("AvenirNext-DemiBold", size: 12))
                            .opacity(0.85)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 16 : 11)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: color.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

/// Course metadata for menus. Building a `LevelDefinition` creates every prop in the course,
/// so the menu and map read from one cached copy instead of rebuilding levels on each redraw.
enum CourseInfo {
    /// Filled on demand from the main thread, so launching to the menu builds one course, not 24.
    private static var cache: [LevelID: LevelDefinition] = [:]

    static func of(_ id: LevelID) -> LevelDefinition {
        if let cached = cache[id] { return cached }
        let level = LevelCatalog.level(id)
        cache[id] = level
        return level
    }
}
