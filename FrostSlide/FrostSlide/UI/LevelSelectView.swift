import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FrostTheme.night.opacity(0.92), FrostTheme.iceDeep.opacity(0.55), FrostTheme.snow],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            SnowfallOverlay(density: 18)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        app.screen = .menu
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(.white.opacity(0.18)))
                    }
                    .accessibilityLabel("Back to menu")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Course Map")
                            .font(.custom("AvenirNext-Heavy", size: 28))
                            .foregroundStyle(.white)
                        Text("\(app.persistence.totalStars) of \(LevelID.allCases.count * 3) stars  ·  \(LevelID.allCases.count) courses")
                            .font(FrostTheme.captionFont)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        dailyCard
                        ForEach(CourseWorld.allCases) { world in
                            worldSection(world)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                }

                BannerAdView()
                    .padding(.bottom, 6)
            }
        }
    }

    private var dailyCard: some View {
        let pick = app.dailyPick
        let level = CourseInfo.of(pick.level)
        let done = app.persistence.dailyDoneToday
        let streak = app.persistence.activeDailyStreak
        return Button {
            app.playDaily()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark" : pick.goal.symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(done ? FrostTheme.pine : FrostTheme.berry))
                VStack(alignment: .leading, spacing: 3) {
                    Text(done ? "Daily complete" : "Daily · \(pick.goal.title)")
                        .font(.custom("AvenirNext-Heavy", size: 16))
                        .foregroundStyle(FrostTheme.ink)
                    Text("\(level.name)  ·  \(pick.goal.detail(parTime: level.parTime, crystalGoal: level.crystalStar))")
                        .font(FrostTheme.captionFont)
                        .foregroundStyle(FrostTheme.inkSoft)
                        .lineLimit(2)
                }
                Spacer()
                if streak > 0 {
                    VStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(FrostTheme.berry)
                        Text("\(streak)")
                            .font(.custom("AvenirNext-Heavy", size: 13))
                            .foregroundStyle(FrostTheme.ink)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(streak)-day streak")
                }
                Image(systemName: "play.fill")
                    .foregroundStyle(FrostTheme.iceDeep)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.92)))
        }
        .buttonStyle(.plain)
    }

    private func worldSection(_ world: CourseWorld) -> some View {
        let stars = world.courses.reduce(0) { $0 + (app.persistence.records[$1]?.bestStars ?? 0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: world.symbol)
                    .foregroundStyle(.white)
                Text(world.title)
                    .font(.custom("AvenirNext-Heavy", size: 16))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(stars)/\(world.courses.count * 3)")
                    .font(FrostTheme.captionFont)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(world.blurb)
                .font(FrostTheme.captionFont)
                .foregroundStyle(.white.opacity(0.65))
            ForEach(world.courses, id: \.self) { id in
                LevelCard(
                    level: CourseInfo.of(id),
                    unlocked: app.persistence.isUnlocked(id),
                    record: app.persistence.records[id]
                ) {
                    app.play(id)
                }
            }
        }
    }
}

struct LevelCard: View {
    let level: LevelDefinition
    let unlocked: Bool
    let record: LevelRecord?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%02d", level.id.order + 1))
                            .font(.custom("AvenirNext-Heavy", size: 20))
                            .foregroundStyle(accent.opacity(0.95))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.name)
                                .font(.custom("AvenirNext-Bold", size: 18))
                                .foregroundStyle(FrostTheme.ink)
                            Text(level.subtitle)
                                .font(FrostTheme.captionFont)
                                .foregroundStyle(FrostTheme.inkSoft)
                        }
                        Spacer()
                        if unlocked {
                            starRow
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(FrostTheme.inkSoft)
                        }
                    }
                    Text(level.blurb)
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundStyle(FrostTheme.inkSoft)
                        .lineLimit(2)
                    HStack {
                        Label("\(level.rivals.count + 1) racers", systemImage: "person.3.fill")
                        Spacer()
                        Text(footer)
                    }
                    .font(FrostTheme.captionFont)
                    .foregroundStyle(FrostTheme.ink.opacity(0.7))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(unlocked ? 0.9 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(accent.opacity(unlocked ? 0.45 : 0.15), lineWidth: 1.4)
            )
            .opacity(unlocked ? 1 : 0.62)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(unlocked ? "Starts the race" : "Finish the previous course to unlock")
    }

    /// Best result so far, or the par time to aim for on a course that has not been finished.
    private var footer: String {
        guard unlocked else { return "Finish previous" }
        if let record, record.bestTime < 9000 {
            return "Best \(FrostTheme.placeWord(record.bestPlace)) · \(FrostTheme.formatTime(record.bestTime))"
        }
        return "Par \(FrostTheme.formatPar(level.parTime))"
    }

    private var stars: Int { record?.bestStars ?? 0 }

    private var starRow: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { i in
                Image(systemName: i <= stars ? "star.fill" : "star")
                    .foregroundStyle(i <= stars ? FrostTheme.ochre : FrostTheme.ink.opacity(0.2))
            }
            if record?.perfect == true {
                Image(systemName: "seal.fill")
                    .foregroundStyle(FrostTheme.berry)
                    .padding(.leading, 2)
            }
        }
    }

    private var accessibilityText: String {
        var text = "Course \(level.id.order + 1), \(level.name). \(level.subtitle)."
        if !unlocked {
            return text + " Locked."
        }
        text += " \(stars) of 3 stars."
        if record?.perfect == true { text += " Perfect run." }
        return text + " " + footer + "."
    }

    /// A top-down sketch of the course itself, so every card is recognisably its own track.
    private var thumbnail: some View {
        ZStack {
            LinearGradient(colors: [accent, accent.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let name = thumbName {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.32)
            }
            TrackPreview(level: level, color: .white)
        }
        .frame(width: 72, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var thumbName: String? {
        switch level.id {
        case .villageDash: return "ThumbVillage"
        case .iceCaveSpiral: return "ThumbCave"
        case .auroraNight: return "ThumbAurora"
        default: return nil
        }
    }

    private var accent: Color {
        switch level.theme {
        case .village: return FrostTheme.ice
        case .market: return Color(red: 0.86, green: 0.38, blue: 0.24)
        case .cave: return Color(red: 0.30, green: 0.72, blue: 0.95)
        case .aurora: return Color(red: 0.40, green: 0.92, blue: 0.62)
        case .harbor: return Color(red: 0.22, green: 0.50, blue: 0.68)
        case .summit: return FrostTheme.ice
        case .forest: return FrostTheme.pine
        case .canyon: return Color(red: 0.45, green: 0.75, blue: 1.0)
        case .steam: return Color(red: 0.95, green: 0.55, blue: 0.28)
        case .blizzard: return Color(red: 0.70, green: 0.82, blue: 0.95)
        case .neon: return Color(red: 1.0, green: 0.28, blue: 0.72)
        case .carnival: return Color(red: 1.0, green: 0.42, blue: 0.38)
        }
    }
}

/// The course's centre line seen from above, start at the top, drawn from the same curve
/// data the track is built from, so a hairpin course looks like a hairpin course.
struct TrackPreview: View {
    let level: LevelDefinition
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let points = Self.outline(for: level)
            guard points.count > 1 else { return }
            var minX = points[0].x, maxX = points[0].x
            var minY = points[0].y, maxY = points[0].y
            for p in points {
                minX = min(minX, p.x)
                maxX = max(maxX, p.x)
                minY = min(minY, p.y)
                maxY = max(maxY, p.y)
            }
            let inset: CGFloat = 14
            let spanX = max(maxX - minX, 1)
            let spanY = max(maxY - minY, 1)
            let scale = min((size.width - inset * 2) / spanX, (size.height - inset * 2) / spanY)
            let originX = (size.width - spanX * scale) / 2 - minX * scale
            let originY = (size.height - spanY * scale) / 2 - minY * scale

            var line = Path()
            for (index, p) in points.enumerated() {
                let mapped = CGPoint(x: p.x * scale + originX, y: p.y * scale + originY)
                if index == 0 {
                    line.move(to: mapped)
                } else {
                    line.addLine(to: mapped)
                }
            }
            let style = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            let shadow = StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)
            context.stroke(line, with: .color(.black.opacity(0.28)), style: shadow)
            context.stroke(line, with: .color(color), style: style)

            if let first = points.first, let last = points.last {
                let start = CGPoint(x: first.x * scale + originX, y: first.y * scale + originY)
                let finish = CGPoint(x: last.x * scale + originX, y: last.y * scale + originY)
                context.fill(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)), with: .color(.green))
                context.fill(Path(ellipseIn: CGRect(x: finish.x - 4, y: finish.y - 4, width: 8, height: 8)), with: .color(.red))
            }
        }
        .accessibilityHidden(true)
    }

    /// Centre line in map space: x to the right, y down the screen. The track heads along +z
    /// with yaw measured toward +x, which on a top-down map with the start at the top puts
    /// +z down the screen and +x to the right.
    static func outline(for level: LevelDefinition, samples: Int = 90) -> [CGPoint] {
        var points: [CGPoint] = []
        points.reserveCapacity(samples)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var yaw: CGFloat = 0
        let step = CGFloat(level.length) / CGFloat(samples - 1)
        for i in 0..<samples {
            let t = Float(i) / Float(samples - 1)
            var delta: Float = 0
            for curve in level.curves where t >= curve.start && t <= curve.end {
                delta += curve.yawRadians / max(0.001, curve.end - curve.start) / Float(samples - 1)
            }
            yaw += CGFloat(delta)
            points.append(CGPoint(x: x, y: y))
            x += step * sin(yaw)
            y += step * cos(yaw)
        }
        return points
    }
}
