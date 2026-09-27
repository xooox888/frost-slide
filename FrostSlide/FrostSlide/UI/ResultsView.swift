import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var ads: AdManager

    var body: some View {
        let result = app.lastResult
        ZStack {
            LinearGradient(
                colors: [FrostTheme.snow, Color.white, FrostTheme.ice.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            SnowfallOverlay(density: 22)

            VStack(spacing: 18) {
                Text("Finish")
                    .font(.custom("AvenirNext-Heavy", size: 36))
                    .foregroundStyle(FrostTheme.ink)
                if let result {
                    Text(FrostTheme.placeWord(result.place))
                        .font(.custom("AvenirNext-Heavy", size: 64))
                        .foregroundStyle(result.place == 1 ? FrostTheme.ochre : FrostTheme.iceDeep)
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { i in
                            Image(systemName: i <= result.stars ? "star.fill" : "star")
                                .font(.title)
                                .foregroundStyle(i <= result.stars ? FrostTheme.ochre : FrostTheme.ink.opacity(0.18))
                        }
                    }
                    HStack(spacing: 18) {
                        stat("Time", FrostTheme.formatTime(result.time))
                        stat("Crystals", "\(result.crystals)/\(result.crystalTotal)")
                    }
                    HStack(spacing: 18) {
                        stat("Combo", "x\(max(1, result.comboMax))")
                        stat("Near miss", "\(result.nearMisses)")
                    }
                    if let skin = result.unlockedSkin {
                        Text("New sled: \(skin.title)")
                            .font(.custom("AvenirNext-Bold", size: 16))
                            .foregroundStyle(FrostTheme.iceDeep)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.85)))
                    }
                    if result.daily {
                        Text("Daily logged")
                            .font(FrostTheme.captionFont)
                            .foregroundStyle(FrostTheme.inkSoft)
                    }
                    podium(result.podium)
                }
                VStack(spacing: 10) {
                    if app.selectedLevel.next != nil {
                        FrostButton(title: "Next Course", icon: "forward.fill", color: FrostTheme.ice) {
                            leaveResults { app.nextLevel() }
                        }
                    }
                    FrostButton(title: "Race Again", icon: "arrow.counterclockwise", color: FrostTheme.ochre, foreground: FrostTheme.ink) {
                        app.restart()
                    }
                    FrostButton(title: "Course Map", icon: "map.fill", color: FrostTheme.inkSoft) {
                        leaveResults { app.backToMap() }
                    }
                    Button("Main Menu") {
                        leaveResults { app.backToMenu() }
                    }
                    .font(FrostTheme.bodyFont)
                    .foregroundStyle(FrostTheme.inkSoft)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 28)
        }
    }

    /// Interstitial only when leaving results — never mid-race, never on rematch.
    private func leaveResults(_ action: @escaping () -> Void) {
        ads.showInterstitialThen(action)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.custom("AvenirNext-Heavy", size: 11))
                .foregroundStyle(FrostTheme.inkSoft)
            Text(value)
                .font(.custom("AvenirNext-Bold", size: 20))
                .foregroundStyle(FrostTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.75)))
    }

    private func podium(_ entries: [PodiumEntry]) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
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
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }

    private func arranged(_ entries: [PodiumEntry]) -> [PodiumEntry] {
        let first = entries.first(where: { $0.place == 1 })
        let second = entries.first(where: { $0.place == 2 })
        let third = entries.first(where: { $0.place == 3 })
        return [second, first, third].compactMap { $0 }
    }
}
