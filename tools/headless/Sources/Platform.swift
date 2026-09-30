// Stand-ins for the Apple-only pieces the engine talks to, so Core/ and Engine/ compile unchanged
// on Linux. AudioHaptics records what the engine asked for instead of playing it, and the
// renderer does nothing.
import Foundation

// ---- Combine stand-ins (on Apple platforms Foundation/SwiftUI expose these) ----
@propertyWrapper
struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
struct ObjectWillChangePublisher { func send() {} }
protocol ObservableObject: AnyObject {}
extension ObservableObject {
    var objectWillChange: ObjectWillChangePublisher { ObjectWillChangePublisher() }
}

// ---- AudioHaptics: records what the engine asked for instead of playing it ----
enum HapticStyle { case light, medium, heavy }
final class AudioHaptics {
    static let shared = AudioHaptics()
    var counts: [String: Int] = [:]
    func reset() { counts = [:] }
    private func note(_ s: String) { counts[s, default: 0] += 1 }
    func apply(settings: GameSettings) {}
    func collect() { note("collect") }
    func boost() { note("boost") }
    func crash() { note("crash") }
    func finish() { note("finish") }
    func countdown() { note("countdown") }
    func go() { note("go") }
    func whoosh() { note("whoosh") }
    func comboHit() { note("combo") }
    func nearMiss() { note("nearmiss") }
    func power() { note("power") }
    func tap(_ style: HapticStyle) { note("tap") }
}

// ---- Renderer stub ----
final class WorldController {
    func build(level: LevelDefinition, path: TrackPath, racers: [Racer]) {}
    func apply(engine: GameEngine, dt: Float) {}
}
