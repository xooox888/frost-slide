import SwiftUI

struct LevelSelectView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FrostTheme.snow, Color.white, FrostTheme.ice.opacity(0.18)],
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
                            .foregroundStyle(FrostTheme.ink)
                            .padding(12)
                            .background(Circle().fill(.white.opacity(0.8)))
                    }
                    Text("Course Map")
                        .font(.custom("AvenirNext-Heavy", size: 30))
                        .foregroundStyle(FrostTheme.ink)
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
                    .padding(.bottom, 28)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%02d", level.id.order + 1))
                        .font(.custom("AvenirNext-Heavy", size: 22))
                        .foregroundStyle(accent.opacity(0.9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.name)
                            .font(.custom("AvenirNext-Bold", size: 22))
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
                    .font(.custom("AvenirNext-Medium", size: 13.5))
                    .foregroundStyle(FrostTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Label("\(level.rivals.count + 1) racers", systemImage: "person.3.fill")
                    Spacer()
                    if let record, record.bestPlace < 90 {
                        Text("Best \(FrostTheme.placeWord(record.bestPlace))  ·  \(FrostTheme.formatTime(record.bestTime))")
                    } else {
                        Text(unlocked ? "Tap to race" : "Finish previous course")
                    }
                }
                .font(FrostTheme.captionFont)
                .foregroundStyle(FrostTheme.ink.opacity(0.7))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(unlocked ? 0.86 : 0.55))
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

    private var accent: Color {
        switch level.theme {
        case .village: return FrostTheme.ochre
        case .market: return Color(red: 0.86, green: 0.38, blue: 0.24)
        case .cave: return Color(red: 0.30, green: 0.72, blue: 0.95)
        case .aurora: return Color(red: 0.40, green: 0.92, blue: 0.62)
        case .harbor: return Color(red: 0.22, green: 0.50, blue: 0.68)
        case .summit: return FrostTheme.ice
        }
    }
}
