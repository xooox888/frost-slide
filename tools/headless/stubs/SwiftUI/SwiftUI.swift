// Linux stand-in: only the pieces of SwiftUI that model/engine files touch.
public struct Color: Equatable {
    public var red: Double, green: Double, blue: Double
    public init(red: Double, green: Double, blue: Double) { self.red = red; self.green = green; self.blue = blue }
}
