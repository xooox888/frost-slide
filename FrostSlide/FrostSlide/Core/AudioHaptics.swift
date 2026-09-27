import Foundation
import AVFoundation
import UIKit

final class AudioHaptics {
    static let shared = AudioHaptics()

    private var players: [String: AVAudioPlayer] = [:]
    private var enabledSound = true
    private var enabledHaptics = true
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    private init() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        preload()
    }

    func apply(settings: GameSettings) {
        enabledSound = settings.soundEnabled
        enabledHaptics = settings.hapticsEnabled
    }

    func play(_ name: String, volume: Float = 1) {
        guard enabledSound, let player = players[name] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    func collect() {
        play("collect", volume: 0.7)
        tap(.light)
    }

    func boost() {
        play("boost", volume: 0.85)
        tap(.medium)
    }

    func crash() {
        play("crash", volume: 0.9)
        tap(.heavy)
    }

    func finish() {
        play("finish", volume: 1)
        if enabledHaptics {
            notify.notificationOccurred(.success)
        }
    }

    func countdown() {
        play("tick", volume: 0.55)
        tap(.light)
    }

    func go() {
        play("go", volume: 0.8)
        tap(.medium)
    }

    func whoosh() {
        play("whoosh", volume: 0.6)
    }

    func power() {
        play("power", volume: 0.75)
        tap(.medium)
    }

    func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabledHaptics else { return }
        switch style {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .heavy: heavy.impactOccurred()
        default: medium.impactOccurred()
        }
    }

    private func preload() {
        let names = ["collect", "boost", "crash", "finish", "tick", "go", "whoosh", "power"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
                players[name] = try? AVAudioPlayer(contentsOf: url)
                players[name]?.prepareToPlay()
            }
        }
    }
}
