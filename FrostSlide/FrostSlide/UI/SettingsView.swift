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
                toggle("Haptics", subtitle: "Taps for boost, collect, crash, and finish.", key: \.hapticsEnabled)
                toggle("Sound", subtitle: "Arcade blips bundled with the app.", key: \.soundEnabled)
                toggle("Unlock all courses", subtitle: "Debug skip for designers and testers.", key: \.unlockAll)

                FrostButton(title: "Reset progress", icon: "trash", color: FrostTheme.berry) {
                    app.persistence.resetProgress()
                }
                .padding(.top, 8)

                Spacer()
                Text("Frost Slide  ·  iOS 17+  ·  SceneKit")
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
