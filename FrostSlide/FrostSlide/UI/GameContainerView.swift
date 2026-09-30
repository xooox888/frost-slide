import QuartzCore
import RealityKit
import SwiftUI

struct GameContainerView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        GamePlaySurface(engine: app.engine)
    }
}

struct GamePlaySurface: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var ads: AdManager
    @ObservedObject var engine: GameEngine

    var body: some View {
        ZStack {
            RealityKitRaceView(engine: engine)
                .ignoresSafeArea()

            SpeedLinesOverlay(
                speedKph: engine.hud.speedKph,
                band: engine.hud.speedBand,
                boosting: engine.hud.boosting,
                time: engine.hud.time
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)

            RaceHUDView(
                hud: engine.hud,
                paused: engine.paused,
                rewardedReady: ads.rewardedReady,
                showHints: app.persistence.totalRaces < 2
            ) {
                app.pause()
            } boostChanged: { held in
                engine.boostHeld = held
            } dropBanana: {
                engine.dropBananaRequested = true
            } onRewardedTurbo: {
                engine.paused = true
                ads.showRewarded {
                    engine.grantRewardedTurbo()
                    engine.paused = false
                } onSkip: {
                    engine.paused = false
                }
            }

            if engine.paused {
                PauseView()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    engine.steerInput = Float(value.translation.width / 60)
                }
                .onEnded { _ in
                    engine.steerInput = 0
                }
        )
        .onDisappear {
            engine.boostHeld = false
            engine.steerInput = 0
        }
    }
}

/// Edge streaks that fade in on push / turbo so the speed bands read on screen.
struct SpeedLinesOverlay: View {
    let speedKph: Int
    var band: SpeedBand = .cruise
    var boosting: Bool = false
    let time: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fromSpeed = min(1, max(0, (Double(speedKph) - 64) / 26))
        let fromBand: Double
        switch band {
        case .cruise: fromBand = boosting ? 0.22 : 0
        case .push: fromBand = 0.55
        case .turbo: fromBand = 0.95
        }
        let intensity = max(fromSpeed, fromBand)
        Canvas { context, size in
            guard intensity > 0, !reduceMotion else { return }
            let center = CGPoint(x: size.width / 2, y: size.height * 0.46)
            let reach = max(size.width, size.height) * 0.75
            let count = 36
            for i in 0..<count {
                let seed = Double(i) * 12.9898
                let jitter = seed - seed.rounded(.down)
                let angle = Double(i) / Double(count) * 2 * .pi + sin(seed) * 0.12
                let speed = 2.2 + jitter * 1.6
                let phase = (time * speed + jitter * 3.1).truncatingRemainder(dividingBy: 1)
                let inner = reach * (0.42 + phase * 0.5)
                let length = reach * (0.08 + intensity * 0.16)
                let dir = CGPoint(x: cos(angle), y: sin(angle))
                var line = Path()
                line.move(to: CGPoint(x: center.x + dir.x * inner, y: center.y + dir.y * inner))
                line.addLine(to: CGPoint(x: center.x + dir.x * (inner + length), y: center.y + dir.y * (inner + length)))
                context.stroke(
                    line,
                    with: .color(Color(red: 0.62, green: 0.86, blue: 1.0).opacity(0.5 * intensity * (1 - phase * 0.5))),
                    lineWidth: 1.5 + jitter * 2
                )
            }
        }
    }
}

/// RealityKit game viewport (non-AR). iOS 17 has no RealityView; ARView is the embed.
struct RealityKitRaceView: UIViewRepresentable {
    let engine: GameEngine

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.white)
        engine.worldController.attach(to: view)
        if let level = engine.level, let path = engine.path {
            engine.worldController.build(level: level, path: path, racers: engine.racers)
        }
        context.coordinator.attach()
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.engine = engine
        _ = uiView
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.detach()
        _ = uiView
    }

    final class Coordinator {
        var engine: GameEngine
        private var link: CADisplayLink?
        private var lastStamp: CFTimeInterval = 0

        init(engine: GameEngine) {
            self.engine = engine
        }

        func attach() {
            detach()
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        func detach() {
            link?.invalidate()
            link = nil
            lastStamp = 0
        }

        @objc func step(_ link: CADisplayLink) {
            let now = link.timestamp
            let dt = lastStamp == 0 ? 1.0 / 60.0 : now - lastStamp
            lastStamp = now
            engine.tick(dt: dt)
        }
    }
}
