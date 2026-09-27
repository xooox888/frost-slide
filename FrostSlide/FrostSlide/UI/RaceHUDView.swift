import SwiftUI

struct RaceHUDView: View {
    let hud: HUDSnapshot
    let paused: Bool
    var rewardedReady: Bool = false
    var onPause: () -> Void
    var boostChanged: (Bool) -> Void
    var dropBanana: () -> Void
    var onRewardedTurbo: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressRail
            Spacer()
            if let count = hud.countdown {
                countdownGlyph(count)
            } else if !hud.toast.isEmpty {
                toast
            }
            Spacer()
            bottomBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(FrostTheme.placeWord(hud.place))
                    .font(.custom("AvenirNext-Heavy", size: 34))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                Text("of \(hud.fieldSize)")
                    .font(FrostTheme.captionFont)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FrostTheme.formatTime(hud.time))
                    .font(.custom("AvenirNext-Bold", size: 18))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .foregroundStyle(FrostTheme.ice)
                    Text("\(hud.crystals)/\(hud.crystalTotal)")
                        .font(FrostTheme.captionFont)
                        .foregroundStyle(.white)
                }
                Text("\(hud.speedKph) km/h")
                    .font(.custom("AvenirNext-DemiBold", size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(FrostTheme.ink)
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.9)))
            }
            .padding(.leading, 8)
            .allowsHitTesting(true)
        }
    }

    private var progressRail: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28))
                ForEach(Array(hud.checkpoints.enumerated()), id: \.offset) { _, cp in
                    Circle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .offset(x: CGFloat(cp) * geo.size.width - 2.5)
                }
                ForEach(Array(hud.rivalProgress.enumerated()), id: \.offset) { _, p in
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 7, height: 7)
                        .offset(x: CGFloat(GameMath.saturate(p)) * geo.size.width - 3.5)
                }
                Circle()
                    .fill(FrostTheme.ice)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .frame(width: 12, height: 12)
                    .offset(x: CGFloat(GameMath.saturate(hud.progress)) * geo.size.width - 6)
            }
        }
        .frame(height: 12)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TURBO")
                    .font(.custom("AvenirNext-Heavy", size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22)).frame(width: 130, height: 14)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [FrostTheme.ice, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 130 * CGFloat(GameMath.saturate(hud.turbo)), height: 14)
                }
                HStack(spacing: 6) {
                    if hud.magnetActive { chip("Magnet", FrostTheme.ice) }
                    if hud.ghostActive { chip("Ghost", .white) }
                    if hud.rocketActive { chip("Rocket", FrostTheme.berry) }
                }
            }
            Spacer()
            if showRewarded {
                Button(action: onRewardedTurbo) {
                    VStack(spacing: 3) {
                        Image(systemName: "play.rectangle.fill")
                        Text("REFILL")
                            .font(.custom("AvenirNext-Heavy", size: 9))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(FrostTheme.iceDeep))
                }
                .allowsHitTesting(true)
                .accessibilityLabel("Watch a short video to refill turbo")
            }
            if hud.bananaArmed {
                Button(action: dropBanana) {
                    VStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                        Text("PEEL")
                            .font(.custom("AvenirNext-Heavy", size: 10))
                    }
                    .foregroundStyle(FrostTheme.ink)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(FrostTheme.ochre))
                }
                .allowsHitTesting(true)
            }
            HoldButton(title: "BOOST", color: FrostTheme.berry, changed: boostChanged)
                .allowsHitTesting(true)
        }
    }

    private var showRewarded: Bool {
        hud.racing
            && !hud.rewardedTurboUsed
            && rewardedReady
            && hud.turbo < 0.28
            && hud.countdown == nil
    }

    private func chip(_ title: String, _ color: Color) -> some View {
        Text(title)
            .font(.custom("AvenirNext-Bold", size: 10))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.9)))
            .foregroundStyle(FrostTheme.ink)
    }

    private func countdownGlyph(_ value: Int) -> some View {
        Text(value == 0 ? "GO" : "\(value)")
            .font(.custom("AvenirNext-Heavy", size: 86))
            .foregroundStyle(.white)
            .shadow(color: FrostTheme.iceDeep.opacity(0.5), radius: 10, y: 4)
            .transition(.scale)
    }

    private var toast: some View {
        Text(hud.toast)
            .font(.custom("AvenirNext-Heavy", size: 28))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }
}

struct HoldButton: View {
    var title: String
    var color: Color
    var changed: (Bool) -> Void
    @State private var pressed = false

    var body: some View {
        Text(title)
            .font(.custom("AvenirNext-Heavy", size: 16))
            .foregroundStyle(.white)
            .frame(width: 108, height: 108)
            .background(
                Circle().fill(
                    LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                )
            )
            .shadow(color: color.opacity(0.4), radius: 10, y: 5)
            .scaleEffect(pressed ? 0.94 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            changed(true)
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        changed(false)
                    }
            )
    }
}
