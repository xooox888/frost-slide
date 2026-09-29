import ConfettiSwiftUI
import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var ads: AdManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Stars revealed so far; they pop in one after another.
    @State private var shownStars = 0
    /// Bumped once to fire the confetti burst after a three-star run.
    @State private var confetti = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FrostTheme.snow, Color.white, FrostTheme.ice.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            SnowfallOverlay(density: 22)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let result = app.lastResult {
                        summary(result)
                        breakdown(result)
                        if let goal = result.dailyGoal {
                            dailyCard(goal, result)
                        }
                        if let skin = result.unlockedSkin {
                            Text("New sled unlocked: \(skin.title)")
                                .font(.custom("AvenirNext-Bold", size: 16))
                                .foregroundStyle(FrostTheme.iceDeep)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.white.opacity(0.85)))
                        } else if let next = app.persistence.nextSkinGoal {
                            Text("\(next.starsToGo) more \(next.starsToGo == 1 ? "star" : "stars") to unlock the \(next.skin.title) sled")
                                .font(FrostTheme.captionFont)
                                .foregroundStyle(FrostTheme.inkSoft)
                        }
                        standings(result)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            actions
        }
        .overlay(
            ConfettiCannon(
                trigger: $confetti,
                num: app.lastResult?.perfect == true ? 70 : 44,
                colors: [FrostTheme.ice, FrostTheme.ochre, FrostTheme.berry, FrostTheme.grape, .white],
                confettiSize: 11,
                rainHeight: 700,
                openingAngle: .degrees(40),
                closingAngle: .degrees(140),
                radius: 380,
                repetitions: app.lastResult?.perfect == true ? 2 : 1,
                repetitionInterval: 0.7,
                hapticFeedback: false
            )
            .allowsHitTesting(false)
        )
        .onAppear(perform: revealStars)
    }

    // MARK: - Sections

    private func summary(_ result: RaceResult) -> some View {
        VStack(spacing: 10) {
            Text(headline(result))
                .font(.custom("AvenirNext-Heavy", size: 30))
                .foregroundStyle(result.newBest && result.previousBest != nil ? FrostTheme.berry : FrostTheme.ink)
            Text(FrostTheme.placeWord(result.place))
                .font(.custom("AvenirNext-Heavy", size: 64))
                .foregroundStyle(result.place == 1 ? FrostTheme.ochre : FrostTheme.iceDeep)
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { i in
                    Image(systemName: i <= shownStars ? "star.fill" : "star")
                        .font(.system(size: 34))
                        .foregroundStyle(i <= shownStars ? FrostTheme.ochre : FrostTheme.ink.opacity(0.18))
                        .scaleEffect(i == shownStars ? 1.18 : 1)
                }
                if result.perfect {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(FrostTheme.berry)
                        .padding(.leading, 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(result.stars) of 3 stars\(result.perfect ? ", perfect run" : "")")
            if result.perfect {
                Text("PERFECT RUN")
                    .font(.custom("AvenirNext-Heavy", size: 12))
                    .foregroundStyle(FrostTheme.berry)
            }
            if let delta = timeDelta(result) {
                Text(delta)
                    .font(.custom("AvenirNext-Bold", size: 14))
                    .foregroundStyle(FrostTheme.inkSoft)
            }
        }
    }

    private func headline(_ result: RaceResult) -> String {
        if result.newBest && result.previousBest != nil { return "New best!" }
        return "Finish"
    }

    /// How this run compares with the previous best on the same course.
    private func timeDelta(_ result: RaceResult) -> String? {
        guard let previous = result.previousBest else { return nil }
        let diff = result.time - previous
        if result.newBest {
            return "\(FrostTheme.formatGap(diff)) s vs your old best"
        }
        return "\(FrostTheme.formatGap(diff)) s off your best"
    }

    /// Where each star came from, and what is still on the table.
    private func breakdown(_ result: RaceResult) -> some View {
        FrostCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("STARS")
                        .font(.custom("AvenirNext-Heavy", size: 12))
                        .foregroundStyle(FrostTheme.inkSoft)
                    Spacer()
                    Text("Bonus points \(result.points)  ·  two earn 3 stars")
                        .font(.custom("AvenirNext-DemiBold", size: 11))
                        .foregroundStyle(FrostTheme.inkSoft)
                }
                row(
                    "Crossed the line",
                    detail: "\(result.fieldSize) racers",
                    earned: true,
                    points: nil
                )
                row(
                    placeTitle(result.place),
                    detail: "Win = 2, second = 1",
                    earned: result.place <= 2,
                    points: result.place == 1 ? "+2" : (result.place == 2 ? "+1" : "0")
                )
                row(
                    "Crystals \(result.crystals)/\(result.crystalTotal)",
                    detail: "Goal \(result.crystalGoal)",
                    earned: result.hitCrystalGoal,
                    points: result.hitCrystalGoal ? "+1" : "0"
                )
                row(
                    "Time \(FrostTheme.formatTime(result.time))",
                    detail: "Par \(FrostTheme.formatPar(result.parTime))",
                    earned: result.beatPar,
                    points: result.beatPar ? "+1" : "0"
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func placeTitle(_ place: Int) -> String {
        place == 1 ? "Won the race" : "Finished \(FrostTheme.placeWord(place))"
    }

    private func row(_ title: String, detail: String, earned: Bool, points: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(earned ? FrostTheme.pine : FrostTheme.ink.opacity(0.25))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.custom("AvenirNext-Bold", size: 15))
                    .foregroundStyle(FrostTheme.ink)
                Text(detail)
                    .font(.custom("AvenirNext-Medium", size: 12))
                    .foregroundStyle(FrostTheme.inkSoft)
            }
            Spacer()
            if let points {
                Text(points)
                    .font(.custom("AvenirNext-Heavy", size: 15))
                    .foregroundStyle(earned ? FrostTheme.pine : FrostTheme.ink.opacity(0.3))
            }
        }
    }

    private func dailyCard(_ goal: DailyChallenge.Goal, _ result: RaceResult) -> some View {
        FrostCard(tint: result.dailyMet ? FrostTheme.pine.opacity(0.12) : .white) {
            HStack(spacing: 12) {
                Image(systemName: result.dailyMet ? "checkmark.seal.fill" : goal.symbol)
                    .font(.title2)
                    .foregroundStyle(result.dailyMet ? FrostTheme.pine : FrostTheme.berry)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily · \(goal.title)")
                        .font(.custom("AvenirNext-Heavy", size: 15))
                        .foregroundStyle(FrostTheme.ink)
                    Text(dailyLine(result))
                        .font(FrostTheme.captionFont)
                        .foregroundStyle(FrostTheme.inkSoft)
                }
                Spacer()
            }
        }
    }

    private func dailyLine(_ result: RaceResult) -> String {
        if result.dailyMet {
            return result.dailyStreak > 1 ? "Complete! \(result.dailyStreak)-day streak" : "Complete! Come back tomorrow to start a streak"
        }
        if app.persistence.dailyDoneToday {
            return "Already complete today"
        }
        return "Goal missed. Race again to have another go."
    }

    private func standings(_ result: RaceResult) -> some View {
        VStack(spacing: 10) {
            podium(result.podium)
            if let you = result.standings.first(where: { $0.isPlayer }), you.place > 3 {
                HStack {
                    Text("You finished \(FrostTheme.placeWord(you.place))")
                    Spacer()
                    if let winner = result.standings.first?.time, let mine = you.time {
                        Text("\(FrostTheme.formatGap(mine - winner)) s")
                            .monospacedDigit()
                    }
                }
                .font(.custom("AvenirNext-Bold", size: 14))
                .foregroundStyle(FrostTheme.inkSoft)
                .padding(.horizontal, 20)
            }
        }
    }

    private func podium(_ entries: [PodiumEntry]) -> some View {
        let winnerTime = entries.first(where: { $0.place == 1 })?.time
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(arranged(entries)) { entry in
                VStack(spacing: 6) {
                    Circle()
                        .fill(entry.color.color)
                        .frame(width: 28, height: 28)
                    Text(entry.isPlayer ? "You" : entry.name)
                        .font(.custom("AvenirNext-Bold", size: 13))
                        .foregroundStyle(FrostTheme.ink)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(entry.place == 1 ? FrostTheme.ochre : FrostTheme.ice.opacity(0.35))
                        .frame(width: 78, height: entry.place == 1 ? 86 : (entry.place == 2 ? 68 : 52))
                        .overlay(Text("\(entry.place)").font(.custom("AvenirNext-Heavy", size: 22)).foregroundStyle(FrostTheme.ink))
                    Text(podiumTime(entry, winnerTime: winnerTime))
                        .font(.custom("AvenirNext-DemiBold", size: 11))
                        .foregroundStyle(FrostTheme.inkSoft)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }

    /// The winner's time, then everyone else's gap to it.
    private func podiumTime(_ entry: PodiumEntry, winnerTime: TimeInterval?) -> String {
        guard let time = entry.time else { return "" }
        if entry.place == 1 || winnerTime == nil {
            return FrostTheme.formatTime(time)
        }
        return FrostTheme.formatGap(time - (winnerTime ?? time))
    }

    private func arranged(_ entries: [PodiumEntry]) -> [PodiumEntry] {
        let first = entries.first(where: { $0.place == 1 })
        let second = entries.first(where: { $0.place == 2 })
        let third = entries.first(where: { $0.place == 3 })
        return [second, first, third].compactMap { $0 }
    }

    // MARK: - Actions

    /// Pinned below the scrolling content so the next step is always in reach.
    private var actions: some View {
        VStack(spacing: 10) {
            if app.selectedLevel.next != nil {
                FrostButton(title: "Next Course", icon: "forward.fill", color: FrostTheme.ice) {
                    leaveResults { app.nextLevel() }
                }
            }
            HStack(spacing: 10) {
                FrostButton(title: "Race Again", icon: "arrow.counterclockwise", color: FrostTheme.ochre, foreground: FrostTheme.ink) {
                    app.restart()
                }
                FrostButton(title: "Course Map", icon: "map.fill", color: FrostTheme.inkSoft) {
                    leaveResults { app.backToMap() }
                }
            }
            Button("Main Menu") {
                leaveResults { app.backToMenu() }
            }
            .font(FrostTheme.bodyFont)
            .foregroundStyle(FrostTheme.inkSoft)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    /// Interstitial only when leaving results — never mid-race, never on rematch.
    private func leaveResults(_ action: @escaping () -> Void) {
        ads.showInterstitialThen(action)
    }

    private func revealStars() {
        guard let stars = app.lastResult?.stars else { return }
        shownStars = 0
        if reduceMotion {
            shownStars = stars
            return
        }
        for i in 1...max(1, stars) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.4 * Double(i)) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    shownStars = i
                }
                AudioHaptics.shared.tap(.light)
            }
        }
        // Three stars earns a burst once the last star has landed. Reduce Motion skips it above.
        if stars == 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.4 * 3 + 0.25) {
                confetti += 1
                AudioHaptics.shared.comboHit()
            }
        }
    }
}
