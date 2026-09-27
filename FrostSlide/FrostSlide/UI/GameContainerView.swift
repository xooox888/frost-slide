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

            RaceHUDView(
                hud: engine.hud,
                paused: engine.paused,
                rewardedReady: ads.rewardedReady
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
                    engine.steerInput = Float(value.translation.width / 72)
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
