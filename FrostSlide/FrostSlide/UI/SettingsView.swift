import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [FrostTheme.snow, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        app.screen = .menu
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(FrostTheme.ink)
                            .padding(12)
                            .background(Circle().fill(.white.opacity(0.85)))
                    }
                    Text("Settings")
                        .font(.custom("AvenirNext-Heavy", size: 30))
                        .foregroundStyle(FrostTheme.ink)
                    Spacer()
                }

                toggleRow("Swipe steering", subtitle: "Drag left and right anywhere on the slope.", isOn: true, disabled: true)
                toggle("Tilt steering", subtitle: "Add accelerometer lean on top of swipe.", key: \.tiltSteering)
                toggle("Haptics", subtitle: "Taps for boost, collect, crash, and finish. Off when Reduce Motion is on.", key: \.hapticsEnabled)
                toggle("Sound", subtitle: "Arcade blips. Silent switch and other audio are respected.", key: \.soundEnabled)
                toggle("Best-run ghost", subtitle: "Race a translucent copy of your fastest line on this course.", key: \.showGhost)
                #if DEBUG
                toggle("Unlock all courses", subtitle: "DEBUG only — stripped from Release / App Store builds.", key: \.unlockAll)
                #endif

                Text("Sled skins")
                    .font(.custom("AvenirNext-Heavy", size: 18))
                    .foregroundStyle(FrostTheme.ink)
                    .padding(.top, 6)
                Text("Earn stars to unlock recolors. \(app.persistence.totalStars) stars collected.")
                    .font(FrostTheme.captionFont)
                    .foregroundStyle(FrostTheme.inkSoft)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                    ForEach(SledSkin.allCases) { skin in
                        let open = app.persistence.isSkinUnlocked(skin)
                        Button {
                            guard open else { return }
                            app.persistence.updateSettings { $0.selectedSkin = skin }
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(skin.swatch)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(.white, lineWidth: app.persistence.settings.selectedSkin == skin ? 3 : 0))
                                Text(open ? skin.title : "\(skin.starsRequired)★")
                                    .font(.custom("AvenirNext-DemiBold", size: 11))
                                    .foregroundStyle(FrostTheme.ink)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white.opacity(open ? 0.85 : 0.45))
                            )
                        }
                        .disabled(!open)
                    }
                }

                Link(destination: AdConfig.privacyPolicyURL) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Policy")
                                .font(.custom("AvenirNext-Bold", size: 17))
                            Text("TODO: replace https://example.com/frost-slide-privacy")
                                .font(FrostTheme.captionFont)
                                .foregroundStyle(FrostTheme.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(FrostTheme.ink)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.white.opacity(0.78))
                    )
                }

                FrostButton(title: "Reset progress", icon: "trash", color: FrostTheme.berry) {
                    app.persistence.resetProgress()
                }
                .padding(.top, 4)

                Spacer()
                Text("Frost Slide 1.0.0  ·  com.frostslide.FrostSlide")
                    .font(FrostTheme.captionFont)
                    .foregroundStyle(FrostTheme.inkSoft)
                    .frame(maxWidth: .infinity)
            }
            .padding(22)
        }
        .onChange(of: app.persistence.settings) { _, new in
            AudioHaptics.shared.apply(settings: new)
            app.persistence.persist()
        }
    }

    private func toggle(_ title: String, subtitle: String, key: WritableKeyPath<GameSettings, Bool>) -> some View {
        toggleRow(title, subtitle: subtitle, isOn: app.persistence.settings[keyPath: key], disabled: false) { value in
            app.persistence.updateSettings { $0[keyPath: key] = value }
        }
    }

    private func toggleRow(
        _ title: String,
        subtitle: String,
        isOn: Bool,
        disabled: Bool,
        onChange: ((Bool) -> Void)? = nil
    ) -> some View {
        FrostCard {
            Toggle(isOn: Binding(
                get: { isOn },
                set: { onChange?($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("AvenirNext-Bold", size: 17))
                        .foregroundStyle(FrostTheme.ink)
                    Text(subtitle)
                        .font(FrostTheme.captionFont)
                        .foregroundStyle(FrostTheme.inkSoft)
                }
            }
            .tint(FrostTheme.ice)
            .disabled(disabled)
        }
    }
}
