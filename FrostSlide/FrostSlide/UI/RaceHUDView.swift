import SwiftUI

struct RaceHUDView: View {
    let hud: HUDSnapshot
    let paused: Bool
    var rewardedReady: Bool = false
    /// First races only: spells out the controls.
    var showHints: Bool = false
    var onPause: () -> Void
    var boostChanged: (Bool) -> Void
    var dropBanana: () -> Void
    var onRewardedTurbo: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressRail
            if hud.avalancheGap >= 0 {
                wallWarning
            }
            Spacer()
            if let count = hud.countdown {
                if count > 0 {
                    briefing
                        .padding(.bottom, 14)
                }
                countdownGlyph(count)
            } else if !hud.toast.isEmpty {
                toast
            }
            Spacer()
            if showHints && hud.racing && hud.time < 5 {
                hintBar
                    .padding(.bottom, 10)
            }
            bottomBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 18)
        // No .allowsHitTesting(false) here: children cannot re-enable it, so it
        // killed Pause/Boost/Peel/Refill. Steering drags still reach the parent
        // gesture through the non-interactive HUD views.
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
            .hudPlate()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Position \(hud.place) of \(hud.fieldSize)")
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FrostTheme.formatTime(hud.time))
                    .font(.custom("AvenirNext-Bold", size: 18))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let gap = hud.ghostGap {
                    Text("Ghost \(FrostTheme.formatGap(TimeInterval(gap)))")
                        .font(.custom("AvenirNext-Heavy", size: 12))
                        .foregroundStyle(gap > 0 ? FrostTheme.berry : Color.cyan)
                        .monospacedDigit()
                }
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .foregroundStyle(FrostTheme.ice)
                    Text("\(hud.crystals)/\(hud.crystalTotal)")
                        .font(FrostTheme.captionFont)
                        .foregroundStyle(.white)
                }
                Text("\(hud.speedKph) km/h")
                    .font(.custom("AvenirNext-DemiBold", size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .hudPlate()
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(FrostTheme.ink)
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.9)))
            }
            .padding(.leading, 8)
            .allowsHitTesting(true)
            .accessibilityLabel("Pause")
        }
    }

    private var progressRail: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FrostTheme.night.opacity(0.4))
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                // Ground the avalanche has already swallowed.
                if hud.avalancheGap >= 0 {
                    Capsule()
                        .fill(.white.opacity(0.7))
                        .frame(width: max(6, CGFloat(GameMath.saturate(hud.avalancheProgress)) * geo.size.width))
                }
                ForEach(Array(hud.checkpoints.enumerated()), id: \.offset) { _, cp in
                    Circle()
                        .fill(.white.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .offset(x: CGFloat(cp) * geo.size.width - 2.5)
                }
                ForEach(Array(hud.rivalProgress.enumerated()), id: \.offset) { index, p in
                    Circle()
                        .fill(index < hud.rivalColors.count ? hud.rivalColors[index].color : Color.red)
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1))
                        .frame(width: 8, height: 8)
                        .offset(x: CGFloat(GameMath.saturate(p)) * geo.size.width - 4)
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
        .accessibilityHidden(true)
    }

    /// How far behind the player the avalanche is, so the danger is readable without looking back.
    private var wallWarning: some View {
        let close = hud.avalancheGap < 18
        return HStack(spacing: 6) {
            Image(systemName: "snowflake")
            Text("AVALANCHE  \(Int(hud.avalancheGap)) m")
                .monospacedDigit()
        }
        .font(.custom("AvenirNext-Heavy", size: 15))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill((close ? FrostTheme.berry : FrostTheme.iceDeep).opacity(0.92)))
        .padding(.top, 8)
        .accessibilityLabel("Avalanche \(Int(hud.avalancheGap)) metres behind")
    }

    private var bottomBar: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("TURBO")
                        .font(.custom("AvenirNext-Heavy", size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                    if hud.turbo > 0.98 {
                        Text("FULL")
                            .font(.custom("AvenirNext-Heavy", size: 10))
                            .foregroundStyle(FrostTheme.ochre)
                    }
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22)).frame(width: 130, height: 14)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: hud.turbo < 0.15 ? [FrostTheme.berry, FrostTheme.ochre] : [FrostTheme.ice, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 130 * CGFloat(GameMath.saturate(hud.turbo)), height: 14)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Turbo \(Int(GameMath.saturate(hud.turbo) * 100)) percent")
                HStack(spacing: 6) {
                    if hud.combo >= 2 { comboChip }
                    if hud.magnetActive { chip("Magnet", FrostTheme.ice) }
                    if hud.ghostActive { chip("Ghost", .white) }
                    if hud.rocketActive { chip("Rocket", FrostTheme.berry) }
                    if hud.flareActive { chip("Flare", FrostTheme.ochre) }
                }
            }
            .hudPlate()
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
                .accessibilityLabel("Drop banana peel")
            }
            HoldButton(title: "BOOST", color: FrostTheme.berry, changed: boostChanged)
                .allowsHitTesting(true)
        }
    }

    /// Offered only once the meter is really empty and there is enough race left to use a
    /// refill. Below the start line's 22% it used to sit on screen from the first second.
    private var showRewarded: Bool {
        hud.racing
            && !hud.rewardedTurboUsed
            && rewardedReady
            && hud.turbo < 0.06
            && hud.progress > 0.12
            && hud.progress < 0.85
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

    /// The chain multiplier, filling back from full as the window to keep it alive closes.
    private var comboChip: some View {
        Text("x\(hud.combo)")
            .font(.custom("AvenirNext-Heavy", size: 11))
            .foregroundStyle(FrostTheme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                ZStack(alignment: .leading) {
                    Capsule().fill(FrostTheme.ochre.opacity(0.4))
                    GeometryReader { geo in
                        Capsule()
                            .fill(FrostTheme.ochre)
                            .frame(width: geo.size.width * CGFloat(GameMath.saturate(hud.comboFraction)))
                    }
                }
            )
            .clipShape(Capsule())
            .accessibilityLabel("Combo times \(hud.combo)")
    }

    /// Goals for this course, shown while the lights count down so the player knows
    /// what the stars are asking for before the race starts.
    private var briefing: some View {
        VStack(spacing: 8) {
            Text("COURSE \(hud.courseNumber)")
                .font(.custom("AvenirNext-Heavy", size: 11))
                .foregroundStyle(.white.opacity(0.75))
            Text(hud.levelName)
                .font(.custom("AvenirNext-Heavy", size: 26))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack(spacing: 8) {
                goalChip("timer", "Par \(FrostTheme.formatPar(hud.parTime))")
                goalChip("diamond.fill", "\(hud.crystalGoal) crystals")
                goalChip("flag.checkered", "Win")
            }
            if showHints {
                Text("Tap BOOST as the light turns green for a launch")
                    .font(FrostTheme.captionFont)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(FrostTheme.night.opacity(0.5)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Course \(hud.courseNumber), \(hud.levelName). Par \(FrostTheme.formatPar(hud.parTime)), \(hud.crystalGoal) crystals.")
    }

    private func goalChip(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.custom("AvenirNext-Bold", size: 12))
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.18)))
    }

    private var hintBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
            Text("Drag anywhere to steer  ·  Hold BOOST for speed")
        }
        .font(.custom("AvenirNext-DemiBold", size: 12))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(FrostTheme.night.opacity(0.55)))
    }

    private func countdownGlyph(_ value: Int) -> some View {
        Text(value == 0 ? "GO" : "\(value)")
            .font(.custom("AvenirNext-Heavy", size: 86))
            .foregroundStyle(.white)
            .shadow(color: FrostTheme.night.opacity(0.55), radius: 10, y: 4)
            .transition(.scale)
    }

    private var toast: some View {
        Text(hud.toast)
            .font(.custom("AvenirNext-Heavy", size: 26))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Capsule().fill(FrostTheme.night.opacity(0.5)))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }
}

private extension View {
    /// Dark translucent backing so white HUD text reads on white snow.
    func hudPlate() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FrostTheme.night.opacity(0.42))
            )
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
            .accessibilityLabel(title.capitalized)
            .accessibilityHint("Hold to burn turbo for extra speed")
            .accessibilityAddTraits(.isButton)
    }
}
