import QuartzCore
import SceneKit
import SwiftUI

struct GameContainerView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        GamePlaySurface(engine: app.engine)
    }
}

struct GamePlaySurface: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject var engine: GameEngine

    var body: some View {
        ZStack {
            SceneKitRaceView(engine: engine)
                .ignoresSafeArea()

            RaceHUDView(hud: engine.hud, paused: engine.paused) {
                app.pause()
            } boostChanged: { held in
                engine.boostHeld = held
            } dropBanana: {
                engine.dropBananaRequested = true
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

struct SceneKitRaceView: UIViewRepresentable {
    let engine: GameEngine

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        engine.sceneController.configure(view)
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.engine = engine
        if uiView.scene !== engine.sceneController.scene {
            engine.sceneController.configure(uiView)
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.detach()
        uiView.isPlaying = false
    }

    final class Coordinator {
        var engine: GameEngine
        private var link: CADisplayLink?
        private var lastStamp: CFTimeInterval = 0

        init(engine: GameEngine) {
            self.engine = engine
        }

        func attach(to view: SCNView) {
            detach()
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            self.link = link
            _ = view
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
