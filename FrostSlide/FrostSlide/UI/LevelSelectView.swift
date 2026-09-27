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

            VStack(alignment: .leading, spacing: 16) {
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
                    Text("Course Map")
                        .font(.custom("AvenirNext-Heavy", size: 30))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(LevelCatalog.all) { level in
                            LevelCard(
                                level: level,
                                unlocked: app.persistence.isUnlocked(level.id),
                                record: app.persistence.records[level.id]
                            ) {
                                app.play(level.id)
                            }
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
                                .font(.custom("AvenirNext-Bold", size: 20))
                                .foregroundStyle(FrostTheme.ink)
                            Text(level.subtitle)
                                .font(FrostTheme.captionFont)
                                .foregroundStyle(FrostTheme.inkSoft)
                        }
                        Spacer()
                        if unlocked {
                            HStack(spacing: 3) {
                                ForEach(1...3, id: \.self) { i in
                                    Image(systemName: i <= (record?.bestStars ?? 0) ? "star.fill" : "star")
                                        .foregroundStyle(i <= (record?.bestStars ?? 0) ? FrostTheme.ochre : FrostTheme.ink.opacity(0.2))
                                }
                            }
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(FrostTheme.inkSoft)
                        }
                    }
                    Text(level.blurb)
                        .font(.custom("AvenirNext-Medium", size: 13))
                        .foregroundStyle(FrostTheme.inkSoft)
                        .lineLimit(3)
                    HStack {
                        Label("\(level.rivals.count + 1) racers", systemImage: "person.3.fill")
                        Spacer()
                        if let record, record.bestPlace < 90 {
                            Text("Best \(FrostTheme.placeWord(record.bestPlace))")
                        } else {
                            Text(unlocked ? "Tap to race" : "Finish previous")
                        }
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
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let name = thumbName {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [accent, accent.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Image(systemName: "snowflake")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                    )
            }
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
        }
    }
}
