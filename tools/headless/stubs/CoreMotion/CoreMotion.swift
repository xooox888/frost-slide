import Foundation
public struct CMAcceleration { public var x: Double = 0, y: Double = 0, z: Double = 0 }
public struct CMAccelerometerData { public var acceleration = CMAcceleration() }
public final class CMMotionManager {
    public init() {}
    public var isAccelerometerAvailable: Bool { false }
    public var accelerometerUpdateInterval: TimeInterval = 0
    public var accelerometerData: CMAccelerometerData? { nil }
    public func startAccelerometerUpdates() {}
    public func stopAccelerometerUpdates() {}
}
