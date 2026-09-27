import Foundation
import simd

enum LevelCatalog {
    static func level(_ id: LevelID) -> LevelDefinition {
        switch id {
        case .villageDash: return villageDash()
        case .marketMayhem: return marketMayhem()
        case .iceCaveSpiral: return iceCaveSpiral()
        case .auroraNight: return auroraNight()
        case .harborFreeze: return harborFreeze()
        case .summitRush: return summitRush()
        }
    }

    static var all: [LevelDefinition] {
        LevelID.allCases.map(level)
    }

    static func villageDash() -> LevelDefinition {
        let b = LevelBuilder(
            id: .villageDash,
            name: "Village Dash",
            subtitle: "Ochre streets & stone arches",
            blurb: "Race the first snowfall through a painted European town. Thread the arches, pop the yellow ramps, and don't let Pico dive-bomb your line.",
            theme: .village,
            palette: .village
        )
        b.length = 560
        b.baseWidth = 17
        b.slope = 0.11
        b.parTime = 42
        b.crystalStar = 28
        b.curve(0.04, 0.22, yaw: 0.65)
        b.curve(0.22, 0.40, yaw: -1.05)
        b.curve(0.40, 0.58, yaw: 0.95)
        b.curve(0.58, 0.78, yaw: -0.85)
        b.curve(0.78, 0.96, yaw: 0.55)
        b.arch(0.16)
        b.arch(0.37)
        b.arch(0.61)
        b.arch(0.83)
        b.ramp(0.23)
        b.ramp(0.47, lateral: -2)
        b.ramp(0.71, lateral: 1.5)
        b.turbo(0.31)
        b.turbo(0.66)
        b.crystalLane(0.08, 0.18, lateral: 0, count: 7)
        b.crystalLane(0.26, 0.35, lateral: 3.2, count: 6)
        b.crystalLane(0.42, 0.54, lateral: -2.5, count: 8)
        b.crystalLane(0.62, 0.74, lateral: 0.8, count: 7)
        b.crystalLane(0.80, 0.90, lateral: -3, count: 6)
        b.power(.magnet, 0.28, lateral: 4)
        b.power(.banana, 0.44, lateral: -4)
        b.power(.rocket, 0.58, lateral: 0)
        b.power(.ghost, 0.76, lateral: 3.5)
        b.hazard(.snowman, 0.19, lateral: -5)
        b.hazard(.snowman, 0.33, lateral: 5.5)
        b.hazard(.crate, 0.41, lateral: 0)
        b.hazard(.snowman, 0.52, lateral: -4.5)
        b.hazard(.crate, 0.64, lateral: 4)
        b.hazard(.snowman, 0.73, lateral: -6)
        b.hazard(.crate, 0.86, lateral: 2)
        b.lineBuildings(every: 0.028)
        b.rivals([
            .pico(skill: 1.02, lateral: -3.2),
            .ruby(skill: 0.98, lateral: 3.4),
            .violet(skill: 0.94, lateral: 0.6)
        ])
        return b.build()
    }

    static func marketMayhem() -> LevelDefinition {
        let b = LevelBuilder(
            id: .marketMayhem,
            name: "Market Mayhem",
            subtitle: "Tight alleys & darting stalls",
            blurb: "Squeeze through a packed winter market. Crates, carts, and shopkeepers who never look both ways.",
            theme: .market,
            palette: .market
        )
        b.length = 520
        b.baseWidth = 11.5
        b.slope = 0.10
        b.parTime = 44
        b.crystalStar = 26
        b.curve(0.00, 0.18, yaw: 0.9)
        b.curve(0.18, 0.34, yaw: -1.2)
        b.curve(0.34, 0.52, yaw: 1.15)
        b.curve(0.52, 0.70, yaw: -1.0)
        b.curve(0.70, 0.88, yaw: 0.85)
        b.width(0.20, 9.2, span: 0.10)
        b.width(0.48, 8.6, span: 0.12)
        b.width(0.74, 9.0, span: 0.10)
        b.ramp(0.29, lateral: 0)
        b.ramp(0.63, lateral: -1)
        b.turbo(0.17)
        b.turbo(0.55)
        b.turbo(0.81)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.22, 0.32, lateral: 2.2, count: 6)
        b.crystalLane(0.38, 0.48, lateral: -2.0, count: 7)
        b.crystalLane(0.58, 0.68, lateral: 1.6, count: 6)
        b.crystalLane(0.78, 0.90, lateral: 0, count: 7)
        b.power(.ghost, 0.24, lateral: -3)
        b.power(.magnet, 0.46, lateral: 3)
        b.power(.banana, 0.60, lateral: 0)
        b.power(.rocket, 0.84, lateral: -2)
        for p in stride(from: Float(0.12), through: 0.90, by: 0.08) {
            b.hazard(.stall, p, lateral: (Int(p * 40) % 2 == 0) ? -4.4 : 4.4, radius: 1.1)
        }
        b.hazard(.crate, 0.21, lateral: 1.2)
        b.hazard(.crate, 0.35, lateral: -1.4)
        b.hazard(.cart, 0.42, lateral: 0, radius: 1.15)
        b.hazard(.npc, 0.31, lateral: 0, radius: 0.8)
        b.hazard(.npc, 0.50, lateral: 1.5, radius: 0.8)
        b.hazard(.cart, 0.67, lateral: -1, radius: 1.15)
        b.hazard(.npc, 0.73, lateral: -0.5, radius: 0.8)
        b.hazard(.crate, 0.79, lateral: 2)
        b.lineMarket(every: 0.045)
        b.rivals([
            .pico(skill: 1.04, lateral: -2.4),
            .ruby(skill: 1.00, lateral: 2.6),
            .violet(skill: 0.93, lateral: 0.2),
            .navy(skill: 0.97, lateral: -0.8)
        ])
        return b.build()
    }

    static func iceCaveSpiral() -> LevelDefinition {
        let b = LevelBuilder(
            id: .iceCaveSpiral,
            name: "Ice Cave Spiral",
            subtitle: "Blue tunnels & stalactites",
            blurb: "A descending helix of glassy ice. Hold your line through the spiral or kiss a stalactite.",
            theme: .cave,
            palette: .cave
        )
        b.length = 600
        b.baseWidth = 13
        b.slope = 0.13
        b.parTime = 46
        b.crystalStar = 30
        b.curve(0.00, 1.00, yaw: 5.2)
        b.width(0.30, 10.5, span: 0.14)
        b.width(0.62, 10.0, span: 0.12)
        b.ramp(0.26)
        b.ramp(0.54)
        b.ramp(0.78)
        b.turbo(0.20)
        b.turbo(0.48)
        b.turbo(0.73)
        b.crystalLane(0.07, 0.18, lateral: 2.2, count: 7)
        b.crystalLane(0.22, 0.34, lateral: -2.8, count: 7)
        b.crystalLane(0.40, 0.52, lateral: 0, count: 8)
        b.crystalLane(0.58, 0.70, lateral: 3.0, count: 7)
        b.crystalLane(0.80, 0.92, lateral: -2.2, count: 7)
        b.power(.ghost, 0.18, lateral: 0)
        b.power(.magnet, 0.40, lateral: -3.5)
        b.power(.rocket, 0.66, lateral: 3.2)
        b.power(.banana, 0.82, lateral: 0)
        for p in stride(from: Float(0.14), through: 0.90, by: 0.09) {
            b.hazard(.stalactite, p, lateral: sin(p * 28) * 3.2, radius: 0.85)
            b.hazard(.icePatch, p + 0.03, lateral: 0, radius: 3.4)
        }
        b.hazard(.icePatch, 0.25, lateral: 2, radius: 3.2)
        b.decorateCave()
        b.rivals([
            .violet(skill: 1.00, lateral: 2.8),
            .pico(skill: 1.03, lateral: -2.6),
            .ruby(skill: 0.97, lateral: 0.4)
        ])
        return b.build()
    }

    static func auroraNight() -> LevelDefinition {
        let b = LevelBuilder(
            id: .auroraNight,
            name: "Aurora Night",
            subtitle: "Glow pads & low visibility",
            blurb: "Night race under a living sky. Trust the glowing pads — the fog will lie to you.",
            theme: .aurora,
            palette: .aurora
        )
        b.length = 580
        b.baseWidth = 15
        b.slope = 0.105
        b.parTime = 44
        b.crystalStar = 27
        b.curve(0.05, 0.25, yaw: -0.8)
        b.curve(0.25, 0.48, yaw: 1.25)
        b.curve(0.48, 0.70, yaw: -1.1)
        b.curve(0.70, 0.92, yaw: 0.75)
        b.ramp(0.21)
        b.ramp(0.49, lateral: 2)
        b.ramp(0.76, lateral: -1.5)
        b.turbo(0.14)
        b.turbo(0.36)
        b.turbo(0.58)
        b.turbo(0.80)
        b.crystalLane(0.08, 0.16, lateral: 0, count: 6)
        b.crystalLane(0.24, 0.34, lateral: -3.2, count: 6)
        b.crystalLane(0.40, 0.50, lateral: 3.4, count: 7)
        b.crystalLane(0.60, 0.70, lateral: 0, count: 6)
        b.crystalLane(0.82, 0.92, lateral: -2.4, count: 6)
        b.power(.rocket, 0.27, lateral: 0)
        b.power(.magnet, 0.45, lateral: 4)
        b.power(.ghost, 0.68, lateral: -4)
        b.power(.banana, 0.86, lateral: 2)
        b.hazard(.snowman, 0.18, lateral: 5)
        b.hazard(.crate, 0.32, lateral: -2)
        b.hazard(.cart, 0.52, lateral: 0)
        b.hazard(.snowman, 0.64, lateral: -5)
        b.hazard(.crate, 0.74, lateral: 3)
        b.hazard(.snowman, 0.88, lateral: 0)
        b.decorateAurora()
        b.rivals([
            .ruby(skill: 1.05, lateral: 3.0),
            .pico(skill: 1.01, lateral: -3.2),
            .violet(skill: 0.95, lateral: 0.8),
            .amber(skill: 0.99, lateral: -1.0)
        ])
        return b.build()
    }

    static func harborFreeze() -> LevelDefinition {
        let b = LevelBuilder(
            id: .harborFreeze,
            name: "Harbor Freeze",
            subtitle: "Icy planks & black water",
            blurb: "Docks, boats, and no second chances if you kiss the drink. Fall in and you'll respawn with a three-second sting.",
            theme: .harbor,
            palette: .harbor
        )
        b.length = 540
        b.baseWidth = 12
        b.slope = 0.09
        b.parTime = 46
        b.crystalStar = 24
        b.curve(0.06, 0.24, yaw: 0.55)
        b.curve(0.24, 0.44, yaw: -0.95)
        b.curve(0.44, 0.66, yaw: 0.85)
        b.curve(0.66, 0.90, yaw: -0.60)
        b.width(0.18, 8.0, span: 0.12)
        b.width(0.40, 7.2, span: 0.14)
        b.width(0.62, 7.6, span: 0.12)
        b.width(0.82, 8.4, span: 0.10)
        b.ramp(0.28)
        b.ramp(0.57)
        b.turbo(0.22)
        b.turbo(0.50)
        b.turbo(0.78)
        b.crystalLane(0.08, 0.16, lateral: 0, count: 5)
        b.crystalLane(0.26, 0.36, lateral: 1.8, count: 6)
        b.crystalLane(0.46, 0.56, lateral: -1.6, count: 6)
        b.crystalLane(0.68, 0.80, lateral: 0, count: 6)
        b.power(.ghost, 0.20, lateral: 2.4)
        b.power(.magnet, 0.38, lateral: -2.2)
        b.power(.banana, 0.54, lateral: 0)
        b.power(.rocket, 0.72, lateral: 1.8)
        b.hazard(.crate, 0.17, lateral: 1)
        b.hazard(.cart, 0.34, lateral: 0)
        b.hazard(.crate, 0.48, lateral: -1.2)
        b.hazard(.bridge, 0.60, lateral: 0, radius: 1.4)
        b.hazard(.crate, 0.70, lateral: 2)
        b.hazard(.cart, 0.84, lateral: -0.6)
        for p in stride(from: Float(0.12), through: 0.92, by: 0.06) {
            b.hazard(.water, p, lateral: -9.5, radius: 4.6)
            b.hazard(.water, p + 0.02, lateral: 9.5, radius: 4.6)
        }
        b.decorateHarbor()
        b.rivals([
            .navy(skill: 1.02, lateral: -2.2),
            .pico(skill: 1.00, lateral: 2.4),
            .violet(skill: 0.94, lateral: 0.3)
        ])
        return b.build()
    }

    static func summitRush() -> LevelDefinition {
        let b = LevelBuilder(
            id: .summitRush,
            name: "Summit Rush",
            subtitle: "Steep faces & wild wind",
            blurb: "The mountain wants you airborne. Big jumps, bigger gusts, and five hungry rivals on the same face.",
            theme: .summit,
            palette: .summit
        )
        b.length = 640
        b.baseWidth = 18
        b.slope = 0.16
        b.parTime = 38
        b.crystalStar = 32
        b.curve(0.04, 0.20, yaw: 0.45)
        b.curve(0.20, 0.38, yaw: -0.70)
        b.curve(0.38, 0.58, yaw: 0.90)
        b.curve(0.58, 0.78, yaw: -0.75)
        b.curve(0.78, 0.96, yaw: 0.40)
        b.elevation(0.22, height: 3.4, span: 0.06)
        b.elevation(0.46, height: 5.2, span: 0.08)
        b.elevation(0.70, height: 6.0, span: 0.09)
        b.ramp(0.21)
        b.ramp(0.45)
        b.ramp(0.69)
        b.turbo(0.12)
        b.turbo(0.34)
        b.turbo(0.58)
        b.turbo(0.82)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.24, 0.33, lateral: 4, count: 7)
        b.crystalLane(0.40, 0.50, lateral: -3.5, count: 8)
        b.crystalLane(0.56, 0.66, lateral: 2.2, count: 7)
        b.crystalLane(0.78, 0.90, lateral: 0, count: 8)
        b.power(.rocket, 0.18, lateral: 0)
        b.power(.magnet, 0.36, lateral: -5)
        b.power(.ghost, 0.52, lateral: 5)
        b.power(.banana, 0.64, lateral: 0)
        b.power(.rocket, 0.86, lateral: 3)
        b.hazard(.wind, 0.30, lateral: 0, radius: 8)
        b.hazard(.wind, 0.50, lateral: 0, radius: 8)
        b.hazard(.wind, 0.74, lateral: 0, radius: 8)
        b.hazard(.snowman, 0.16, lateral: -6)
        b.hazard(.crate, 0.28, lateral: 3)
        b.hazard(.snowman, 0.42, lateral: 6)
        b.hazard(.crate, 0.60, lateral: -4)
        b.hazard(.snowman, 0.80, lateral: 5)
        b.decorateSummit()
        b.rivals([
            .pico(skill: 1.06, lateral: -4.0),
            .ruby(skill: 1.03, lateral: 4.2),
            .violet(skill: 0.95, lateral: 1.2),
            .navy(skill: 0.99, lateral: -1.6),
            .amber(skill: 1.01, lateral: 0.2)
        ])
        return b.build()
    }
}

final class LevelBuilder {
    let id: LevelID
    let name: String
    let subtitle: String
    let blurb: String
    let theme: LevelTheme
    let palette: LevelPalette
    var length: Float = 520
    var baseWidth: Float = 16
    var slope: Float = 0.11
    var parTime: TimeInterval = 50
    var crystalStar: Int = 24
    var curves: [CurveKey] = []
    var widths: [WidthKey] = []
    var elevations: [ElevKey] = []
    var entities: [PlacedEntity] = []
    var rivalConfigs: [RivalConfig] = []

    init(
        id: LevelID,
        name: String,
        subtitle: String,
        blurb: String,
        theme: LevelTheme,
        palette: LevelPalette
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.blurb = blurb
        self.theme = theme
        self.palette = palette
    }

    func curve(_ start: Float, _ end: Float, yaw: Float) {
        curves.append(CurveKey(start: start, end: end, yawRadians: yaw))
    }

    func width(_ at: Float, _ width: Float, span: Float) {
        widths.append(WidthKey(at: at, width: width, span: span))
    }

    func elevation(_ at: Float, height: Float, span: Float) {
        elevations.append(ElevKey(at: at, height: height, span: span))
    }

    func arch(_ progress: Float) {
        entities.append(PlacedEntity(kind: .arch, progress: progress, scale: 1, radius: 0))
    }

    func ramp(_ progress: Float, lateral: Float = 0) {
        entities.append(PlacedEntity(kind: .ramp, progress: progress, lateral: lateral, scale: 1, radius: 2.4))
    }

    func turbo(_ progress: Float, lateral: Float = 0) {
        entities.append(PlacedEntity(kind: .turboPad, progress: progress, lateral: lateral, scale: 1, radius: 2.1))
    }

    func crystalLane(_ from: Float, _ to: Float, lateral: Float, count: Int) {
        guard count > 1 else { return }
        for i in 0..<count {
            let t = Float(i) / Float(count - 1)
            let p = from + (to - from) * t
            entities.append(PlacedEntity(kind: .crystal, progress: p, lateral: lateral, scale: 1, radius: 0.85))
        }
    }

    func power(_ type: PowerUpType, _ progress: Float, lateral: Float) {
        let kind: PropKind
        switch type {
        case .rocket: kind = .rocket
        case .magnet: kind = .magnet
        case .ghost: kind = .ghost
        case .banana: kind = .banana
        }
        entities.append(PlacedEntity(kind: kind, progress: progress, lateral: lateral, scale: 1, radius: 0.95))
    }

    func hazard(_ kind: PropKind, _ progress: Float, lateral: Float, radius: Float = 1.05) {
        entities.append(PlacedEntity(kind: kind, progress: progress, lateral: lateral, scale: 1, radius: radius))
    }

    func rivals(_ list: [RivalConfig]) {
        rivalConfigs = list
    }

    func lineBuildings(every step: Float) {
        var p: Float = 0.03
        var flip = false
        while p < 0.96 {
            if abs(p - 0.16) > 0.03 && abs(p - 0.37) > 0.03 && abs(p - 0.61) > 0.03 && abs(p - 0.83) > 0.03 {
                let side: Float = flip ? 1 : -1
                entities.append(PlacedEntity(
                    kind: .building,
                    progress: p,
                    lateral: side * (baseWidth * 0.5 + 5.5 + Float.random(in: 0...1.4)),
                    yaw: Float.random(in: -0.12...0.12),
                    scale: Float.random(in: 0.85...1.25),
                    radius: 0
                ))
                if Int(p * 100) % 4 == 0 {
                    entities.append(PlacedEntity(
                        kind: .chimney,
                        progress: p + 0.01,
                        lateral: side * (baseWidth * 0.5 + 3.2),
                        scale: 1,
                        radius: 0
                    ))
                }
            }
            flip.toggle()
            p += step
        }
    }

    func lineMarket(every step: Float) {
        var p: Float = 0.04
        var flip = false
        while p < 0.95 {
            let side: Float = flip ? 1 : -1
            entities.append(PlacedEntity(
                kind: .stall,
                progress: p,
                lateral: side * (baseWidth * 0.5 + 2.8),
                yaw: side > 0 ? Float.pi : 0,
                scale: Float.random(in: 0.9...1.15),
                radius: 0
            ))
            if Int(p * 50) % 3 == 0 {
                entities.append(PlacedEntity(
                    kind: .barrel,
                    progress: p + 0.015,
                    lateral: side * (baseWidth * 0.5 + 1.6),
                    scale: 1,
                    radius: 0.6
                ))
            }
            flip.toggle()
            p += step
        }
    }

    func decorateCave() {
        for p in stride(from: Float(0.05), through: 0.95, by: 0.04) {
            entities.append(PlacedEntity(kind: .icicle, progress: p, lateral: -6.5, scale: Float.random(in: 0.8...1.4), radius: 0))
            entities.append(PlacedEntity(kind: .icicle, progress: p + 0.02, lateral: 6.5, scale: Float.random(in: 0.8...1.4), radius: 0))
        }
    }

    func decorateAurora() {
        for p in stride(from: Float(0.08), through: 0.92, by: 0.07) {
            entities.append(PlacedEntity(kind: .lantern, progress: p, lateral: (Int(p * 20) % 2 == 0) ? -7 : 7, scale: 1, radius: 0))
            entities.append(PlacedEntity(kind: .auroraRibbon, progress: p, lateral: 0, scale: 1, radius: 0))
        }
        for p in stride(from: Float(0.10), through: 0.90, by: 0.12) {
            entities.append(PlacedEntity(kind: .pine, progress: p, lateral: -11, scale: 1.1, radius: 0))
            entities.append(PlacedEntity(kind: .pine, progress: p + 0.05, lateral: 11, scale: 1.2, radius: 0))
        }
    }

    func decorateHarbor() {
        for p in stride(from: Float(0.06), through: 0.94, by: 0.07) {
            entities.append(PlacedEntity(kind: .dock, progress: p, lateral: 0, scale: 1, radius: 0))
            if Int(p * 100) % 2 == 0 {
                entities.append(PlacedEntity(kind: .boat, progress: p, lateral: (Int(p * 10) % 2 == 0) ? -12 : 12, scale: 1, radius: 0))
            }
            entities.append(PlacedEntity(kind: .lamp, progress: p, lateral: (Int(p * 14) % 2 == 0) ? -5.5 : 5.5, scale: 1, radius: 0))
        }
    }

    func decorateSummit() {
        for p in stride(from: Float(0.05), through: 0.95, by: 0.05) {
            entities.append(PlacedEntity(kind: .pine, progress: p, lateral: -12 - Float.random(in: 0...3), scale: Float.random(in: 1.0...1.6), radius: 0))
            entities.append(PlacedEntity(kind: .pine, progress: p + 0.02, lateral: 12 + Float.random(in: 0...3), scale: Float.random(in: 1.0...1.6), radius: 0))
        }
    }

    func build() -> LevelDefinition {
        var all = entities
        all.append(PlacedEntity(kind: .startBanner, progress: 0.018, scale: 1, radius: 0))
        all.append(PlacedEntity(kind: .finish, progress: 0.992, scale: 1, radius: 2.5))
        for cp in [Float(0.25), 0.50, 0.75] {
            all.append(PlacedEntity(kind: .checkpoint, progress: cp, scale: 1, radius: 0))
        }
        let crystals = all.filter { $0.kind == .crystal }.count
        return LevelDefinition(
            id: id,
            name: name,
            subtitle: subtitle,
            blurb: blurb,
            theme: theme,
            palette: palette,
            length: length,
            baseWidth: baseWidth,
            slope: slope,
            startHeight: length * slope + 10,
            curves: curves,
            widths: widths,
            elevations: elevations,
            entities: all,
            rivals: rivalConfigs,
            checkpoints: [0.0, 0.25, 0.50, 0.75],
            parTime: parTime,
            crystalTarget: crystals,
            crystalStar: crystalStar
        )
    }
}

extension LevelPalette {
    static let village = LevelPalette(
        snow: SIMD3(0.96, 0.98, 1.0),
        ice: SIMD3(0.55, 0.82, 1.0),
        skyTop: SIMD3(0.72, 0.88, 0.98),
        skyBottom: SIMD3(0.90, 0.95, 1.0),
        fog: SIMD3(0.88, 0.93, 0.98),
        fogStart: 28,
        fogEnd: 140,
        ambient: SIMD3(0.78, 0.82, 0.88),
        sunColor: SIMD3(1.0, 0.96, 0.88),
        sunIntensity: 900,
        wall: SIMD3(0.89, 0.70, 0.36),
        accent: SIMD3(0.20, 0.62, 1.0),
        wood: SIMD3(0.55, 0.36, 0.22),
        night: false
    )

    static let market = LevelPalette(
        snow: SIMD3(0.95, 0.96, 0.93),
        ice: SIMD3(0.60, 0.80, 0.95),
        skyTop: SIMD3(0.78, 0.86, 0.92),
        skyBottom: SIMD3(0.94, 0.93, 0.88),
        fog: SIMD3(0.90, 0.90, 0.86),
        fogStart: 22,
        fogEnd: 110,
        ambient: SIMD3(0.80, 0.76, 0.70),
        sunColor: SIMD3(1.0, 0.90, 0.72),
        sunIntensity: 800,
        wall: SIMD3(0.82, 0.42, 0.28),
        accent: SIMD3(0.95, 0.55, 0.18),
        wood: SIMD3(0.50, 0.32, 0.18),
        night: false
    )

    static let cave = LevelPalette(
        snow: SIMD3(0.62, 0.82, 0.95),
        ice: SIMD3(0.35, 0.72, 0.95),
        skyTop: SIMD3(0.05, 0.12, 0.22),
        skyBottom: SIMD3(0.10, 0.22, 0.34),
        fog: SIMD3(0.18, 0.32, 0.46),
        fogStart: 8,
        fogEnd: 70,
        ambient: SIMD3(0.22, 0.36, 0.48),
        sunColor: SIMD3(0.45, 0.75, 1.0),
        sunIntensity: 400,
        wall: SIMD3(0.22, 0.40, 0.55),
        accent: SIMD3(0.35, 0.85, 1.0),
        wood: SIMD3(0.30, 0.24, 0.22),
        night: true
    )

    static let aurora = LevelPalette(
        snow: SIMD3(0.78, 0.84, 0.95),
        ice: SIMD3(0.45, 0.95, 0.75),
        skyTop: SIMD3(0.05, 0.08, 0.18),
        skyBottom: SIMD3(0.08, 0.16, 0.28),
        fog: SIMD3(0.12, 0.16, 0.28),
        fogStart: 16,
        fogEnd: 90,
        ambient: SIMD3(0.20, 0.28, 0.40),
        sunColor: SIMD3(0.55, 0.80, 1.0),
        sunIntensity: 280,
        wall: SIMD3(0.28, 0.24, 0.42),
        accent: SIMD3(0.45, 1.0, 0.70),
        wood: SIMD3(0.32, 0.26, 0.22),
        night: true
    )

    static let harbor = LevelPalette(
        snow: SIMD3(0.90, 0.93, 0.95),
        ice: SIMD3(0.50, 0.72, 0.82),
        skyTop: SIMD3(0.62, 0.74, 0.82),
        skyBottom: SIMD3(0.82, 0.86, 0.88),
        fog: SIMD3(0.74, 0.80, 0.84),
        fogStart: 20,
        fogEnd: 120,
        ambient: SIMD3(0.62, 0.70, 0.76),
        sunColor: SIMD3(0.90, 0.92, 0.95),
        sunIntensity: 650,
        wall: SIMD3(0.46, 0.34, 0.26),
        accent: SIMD3(0.18, 0.48, 0.70),
        wood: SIMD3(0.46, 0.30, 0.18),
        night: false
    )

    static let summit = LevelPalette(
        snow: SIMD3(0.97, 0.98, 1.0),
        ice: SIMD3(0.70, 0.88, 1.0),
        skyTop: SIMD3(0.45, 0.70, 0.92),
        skyBottom: SIMD3(0.86, 0.92, 0.98),
        fog: SIMD3(0.90, 0.94, 0.98),
        fogStart: 30,
        fogEnd: 160,
        ambient: SIMD3(0.82, 0.86, 0.92),
        sunColor: SIMD3(1.0, 0.98, 0.94),
        sunIntensity: 1100,
        wall: SIMD3(0.78, 0.82, 0.88),
        accent: SIMD3(0.20, 0.62, 1.0),
        wood: SIMD3(0.38, 0.26, 0.18),
        night: false
    )
}

extension RivalConfig {
    static func pico(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Pico", color: SIMD3(0.22, 0.78, 0.42), personality: .aggressive, skill: skill, startLateral: lateral)
    }

    static func ruby(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Ruby", color: SIMD3(0.92, 0.24, 0.32), personality: .hoarder, skill: skill, startLateral: lateral)
    }

    static func violet(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Violet", color: SIMD3(0.58, 0.38, 0.86), personality: .cautious, skill: skill, startLateral: lateral)
    }

    static func navy(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Navy", color: SIMD3(0.16, 0.38, 0.78), personality: .cautious, skill: skill, startLateral: lateral)
    }

    static func amber(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Amber", color: SIMD3(0.96, 0.62, 0.18), personality: .aggressive, skill: skill, startLateral: lateral)
    }
}
