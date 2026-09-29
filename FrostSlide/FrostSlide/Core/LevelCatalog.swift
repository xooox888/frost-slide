import Foundation
import simd

enum LevelCatalog {
    static func level(_ id: LevelID) -> LevelDefinition {
        switch id {
        case .villageDash: return villageDash()
        case .marketMayhem: return marketMayhem()
        case .alleySprint: return alleySprint()
        case .iceCaveSpiral: return iceCaveSpiral()
        case .crystalGrotto: return crystalGrotto()
        case .frozenHollow: return frozenHollow()
        case .auroraNight: return auroraNight()
        case .polarVeil: return polarVeil()
        case .midnightRibbon: return midnightRibbon()
        case .harborFreeze: return harborFreeze()
        case .driftwoodDocks: return driftwoodDocks()
        case .tideGate: return tideGate()
        case .summitRush: return summitRush()
        case .glacierDrop: return glacierDrop()
        case .icefallRun: return icefallRun()
        case .pineWhisper: return pineWhisper()
        case .timberSwitchback: return timberSwitchback()
        case .owlHollow: return owlHollow()
        case .canyonGlow: return canyonGlow()
        case .prismCut: return prismCut()
        case .steamVeil: return steamVeil()
        case .whiteoutPeak: return whiteoutPeak()
        case .neonSlalom: return neonSlalom()
        case .carnivalParade: return carnivalParade()
        }
    }

    static var all: [LevelDefinition] {
        LevelID.allCases.map(level)
    }

    static func villageDash() -> LevelDefinition {
        let b = LevelBuilder(
            id: .villageDash,
            name: "Village Dash",
            subtitle: "Ice-crystal arches & wide streets",
            blurb: "Race the first snowfall through a painted alpine town. Thread the cyan arches, pop the ramps, and learn the carve.",
            theme: .village,
            palette: .village
        )
        b.length = 560
        b.baseWidth = 17
        b.slope = 0.11
        b.parTime = 28
        b.crystalStar = 29
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
            .pico(skill: 1.016, lateral: -3.2),
            .ruby(skill: 0.996, lateral: 3.4),
            .violet(skill: 0.966, lateral: 0.6)
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
        b.parTime = 28
        b.crystalStar = 24
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
            .pico(skill: 1.053, lateral: -2.4),
            .ruby(skill: 1.032, lateral: 2.6),
            .violet(skill: 0.992, lateral: 0.2),
            .navy(skill: 1.022, lateral: -0.8)
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
        b.parTime = 30.5
        b.crystalStar = 25
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
            .violet(skill: 1.000, lateral: 2.8),
            .pico(skill: 1.030, lateral: -2.6),
            .ruby(skill: 0.970, lateral: 0.4)
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
        b.parTime = 31
        b.crystalStar = 26
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
            .ruby(skill: 1.006, lateral: 3.0),
            .pico(skill: 0.976, lateral: -3.2),
            .violet(skill: 0.916, lateral: 0.8),
            .amber(skill: 0.956, lateral: -1.0)
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
        b.parTime = 30
        b.crystalStar = 20
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
            .navy(skill: 0.989, lateral: -2.2),
            .pico(skill: 0.978, lateral: 2.4),
            .violet(skill: 0.918, lateral: 0.3)
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
        b.parTime = 30
        b.crystalStar = 25
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
            .pico(skill: 1.082, lateral: -4.0),
            .ruby(skill: 1.063, lateral: 4.2),
            .violet(skill: 0.991, lateral: 1.2),
            .navy(skill: 1.032, lateral: -1.6),
            .amber(skill: 1.042, lateral: 0.2)
        ])
        return b.build()
    }

    static func alleySprint() -> LevelDefinition {
        let b = LevelBuilder(id: .alleySprint, name: "Alley Sprint", subtitle: "Squeeze + shortcut gates", blurb: "The market's back streets. Hit the cyan gate on the left for a dirty cut.", theme: .market, palette: .market)
        b.length = 500; b.baseWidth = 10.4; b.slope = 0.105; b.parTime = 26; b.crystalStar = 25
        b.curve(0.00, 0.16, yaw: 1.15); b.curve(0.16, 0.34, yaw: -1.35); b.curve(0.34, 0.52, yaw: 1.05)
        b.curve(0.52, 0.72, yaw: -1.20); b.curve(0.72, 0.94, yaw: 0.80)
        b.width(0.28, 8.2, span: 0.10); b.width(0.60, 7.8, span: 0.10)
        b.ramp(0.22); b.ramp(0.58, lateral: 1.2); b.turbo(0.14); b.turbo(0.48); b.turbo(0.82)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.20, 0.30, lateral: 2.0, count: 6)
        b.crystalLane(0.36, 0.46, lateral: -2.2, count: 7)
        b.crystalLane(0.56, 0.66, lateral: 1.4, count: 6)
        b.crystalLane(0.76, 0.88, lateral: 0, count: 7)
        b.power(.ghost, 0.18, lateral: -2.6); b.power(.magnet, 0.40, lateral: 2.8)
        b.power(.banana, 0.62, lateral: 0); b.power(.rocket, 0.80, lateral: -1.6)
        b.shortcut(0.41, lateral: -3.6, skip: 0.028)
        b.hazard(.stall, 0.15, lateral: -3.8, radius: 1.0)
        b.hazard(.crate, 0.26, lateral: 1.0); b.hazard(.npc, 0.33, lateral: 0, radius: 0.75)
        b.hazard(.cart, 0.50, lateral: 0.6, radius: 1.1); b.hazard(.crate, 0.68, lateral: -1.2)
        b.hazard(.npc, 0.77, lateral: 1.4, radius: 0.75); b.hazard(.stall, 0.88, lateral: 3.6, radius: 1.0)
        b.lineMarket(every: 0.05)
        b.rivals([.pico(skill: 0.984, lateral: -2.0), .ruby(skill: 0.954, lateral: 2.2), .coral(skill: 0.934, lateral: 0.2)])
        return b.build()
    }

    static func crystalGrotto() -> LevelDefinition {
        let b = LevelBuilder(id: .crystalGrotto, name: "Crystal Grotto", subtitle: "Spires & ice patches", blurb: "A glittering chamber. Spires split the lane; ice patches steal your grip.", theme: .canyon, palette: .canyon)
        b.length = 590; b.baseWidth = 13.5; b.slope = 0.12; b.parTime = 30.5; b.crystalStar = 28
        b.curve(0.00, 0.22, yaw: 0.85); b.curve(0.22, 0.48, yaw: -1.15); b.curve(0.48, 0.74, yaw: 1.05); b.curve(0.74, 1.00, yaw: -0.70)
        b.width(0.36, 11.0, span: 0.12)
        b.ramp(0.24); b.ramp(0.62, lateral: -1.5); b.turbo(0.16); b.turbo(0.44); b.turbo(0.78)
        b.crystalLane(0.06, 0.16, lateral: 2.4, count: 7)
        b.crystalLane(0.22, 0.34, lateral: -2.6, count: 7)
        b.crystalLane(0.42, 0.54, lateral: 0, count: 8)
        b.crystalLane(0.62, 0.74, lateral: 3.0, count: 7)
        b.crystalLane(0.82, 0.92, lateral: -2.0, count: 7)
        b.power(.magnet, 0.20, lateral: 0); b.power(.ghost, 0.48, lateral: -3.4)
        b.power(.rocket, 0.70, lateral: 3.2); b.power(.flare, 0.86, lateral: 0)
        for p in stride(from: Float(0.14), through: 0.88, by: 0.10) {
            b.hazard(.crystalSpire, p, lateral: sin(p * 22) * 3.4, radius: 0.9)
            b.hazard(.icePatch, p + 0.04, lateral: 0, radius: 3.0)
        }
        b.decorateCanyon()
        b.rivals([.violet(skill: 1.019, lateral: 2.6), .pico(skill: 1.039, lateral: -2.4), .mint(skill: 0.979, lateral: 0.3)])
        return b.build()
    }

    static func frozenHollow() -> LevelDefinition {
        let b = LevelBuilder(id: .frozenHollow, name: "Frozen Hollow", subtitle: "Tight helix + avalanche", blurb: "The cave narrows and the ceiling lets go. Stay ahead of the white wall.", theme: .cave, palette: .cave)
        b.length = 620; b.baseWidth = 11.2; b.slope = 0.14; b.parTime = 31; b.crystalStar = 31
        b.curve(0.00, 1.00, yaw: 6.4)
        b.width(0.24, 9.4, span: 0.10); b.width(0.58, 8.8, span: 0.12)
        b.ramp(0.20); b.ramp(0.52); b.ramp(0.80)
        b.turbo(0.12); b.turbo(0.40); b.turbo(0.68)
        b.crystalLane(0.06, 0.16, lateral: 1.8, count: 7)
        b.crystalLane(0.22, 0.34, lateral: -2.2, count: 7)
        b.crystalLane(0.40, 0.50, lateral: 0, count: 7)
        b.crystalLane(0.58, 0.70, lateral: 2.4, count: 7)
        b.crystalLane(0.78, 0.90, lateral: -1.6, count: 8)
        b.power(.ghost, 0.18, lateral: 0); b.power(.magnet, 0.46, lateral: -2.8)
        b.power(.rocket, 0.64, lateral: 2.6); b.power(.banana, 0.84, lateral: 0)
        b.avalanche(from: 0.52, to: 0.90, pace: 1.12)
        for p in stride(from: Float(0.12), through: 0.88, by: 0.08) {
            b.hazard(.stalactite, p, lateral: cos(p * 30) * 2.6, radius: 0.8)
        }
        b.decorateCave()
        b.rivals([.pico(skill: 1.060, lateral: -2.2), .ruby(skill: 1.020, lateral: 2.4), .navy(skill: 0.990, lateral: 0.2), .violet(skill: 0.970, lateral: 1.0)])
        return b.build()
    }

    static func polarVeil() -> LevelDefinition {
        let b = LevelBuilder(id: .polarVeil, name: "Polar Veil", subtitle: "Flares & hidden cut", blurb: "Grab a flare or race blind. A shortcut hides under the left aurora.", theme: .aurora, palette: .aurora)
        b.length = 600; b.baseWidth = 14.5; b.slope = 0.11; b.parTime = 31.5; b.crystalStar = 27
        b.curve(0.04, 0.26, yaw: -1.05); b.curve(0.26, 0.50, yaw: 1.30); b.curve(0.50, 0.74, yaw: -1.15); b.curve(0.74, 0.96, yaw: 0.70)
        b.ramp(0.20, lateral: 1.5); b.ramp(0.56); b.turbo(0.12); b.turbo(0.38); b.turbo(0.64); b.turbo(0.86)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.22, 0.32, lateral: -3.0, count: 6)
        b.crystalLane(0.40, 0.50, lateral: 3.2, count: 7)
        b.crystalLane(0.58, 0.68, lateral: 0, count: 6)
        b.crystalLane(0.80, 0.92, lateral: -2.2, count: 7)
        b.power(.flare, 0.16, lateral: 3.6); b.power(.rocket, 0.34, lateral: 0)
        b.power(.magnet, 0.52, lateral: -4); b.power(.ghost, 0.74, lateral: 4)
        b.shortcut(0.47, lateral: -4.2, skip: 0.032)
        b.hazard(.snowman, 0.18, lateral: 5); b.hazard(.crate, 0.36, lateral: -2)
        b.hazard(.cart, 0.60, lateral: 0); b.hazard(.snowman, 0.78, lateral: -5)
        b.decorateAurora()
        b.rivals([.ruby(skill: 1.041, lateral: 2.8), .pico(skill: 1.002, lateral: -3.0), .amber(skill: 0.983, lateral: 0.6), .frost(skill: 0.963, lateral: -1.0)])
        return b.build()
    }

    static func midnightRibbon() -> LevelDefinition {
        let b = LevelBuilder(id: .midnightRibbon, name: "Midnight Ribbon", subtitle: "Night chase", blurb: "A thin glowing ribbon and an avalanche of powder at your back.", theme: .aurora, palette: .aurora)
        b.length = 610; b.baseWidth = 12.8; b.slope = 0.12; b.parTime = 31.5; b.crystalStar = 26
        b.curve(0.00, 0.20, yaw: 0.95); b.curve(0.20, 0.42, yaw: -1.40); b.curve(0.42, 0.66, yaw: 1.20); b.curve(0.66, 0.90, yaw: -0.85)
        b.width(0.32, 10.2, span: 0.10); b.width(0.70, 9.8, span: 0.10)
        b.ramp(0.18); b.ramp(0.50, lateral: -1.2); b.ramp(0.78)
        b.turbo(0.10); b.turbo(0.36); b.turbo(0.62); b.turbo(0.84)
        b.crystalLane(0.06, 0.14, lateral: 1.6, count: 6)
        b.crystalLane(0.22, 0.32, lateral: -2.4, count: 7)
        b.crystalLane(0.40, 0.50, lateral: 2.6, count: 7)
        b.crystalLane(0.58, 0.68, lateral: 0, count: 6)
        b.crystalLane(0.80, 0.90, lateral: -1.8, count: 7)
        b.power(.flare, 0.14, lateral: -3.2); b.power(.ghost, 0.30, lateral: 0)
        b.power(.rocket, 0.56, lateral: 3); b.power(.banana, 0.80, lateral: 0)
        b.avalanche(from: 0.48, to: 0.92, pace: 1.14)
        b.hazard(.crate, 0.24, lateral: 1.4); b.hazard(.snowman, 0.44, lateral: -4)
        b.hazard(.crate, 0.66, lateral: 3); b.hazard(.snowman, 0.84, lateral: 0)
        b.decorateAurora()
        b.rivals([.pico(skill: 1.024, lateral: -2.6), .ruby(skill: 0.995, lateral: 2.8), .violet(skill: 0.955, lateral: 0.4), .frost(skill: 0.975, lateral: -0.8)])
        return b.build()
    }

    static func driftwoodDocks() -> LevelDefinition {
        let b = LevelBuilder(id: .driftwoodDocks, name: "Driftwood Docks", subtitle: "Narrow planks + cut", blurb: "Skip the long pier through the hanging gate if you dare the edge.", theme: .harbor, palette: .harbor)
        b.length = 550; b.baseWidth = 11.0; b.slope = 0.095; b.parTime = 29.5; b.crystalStar = 22
        b.curve(0.05, 0.26, yaw: 0.70); b.curve(0.26, 0.50, yaw: -1.05); b.curve(0.50, 0.74, yaw: 0.90); b.curve(0.74, 0.94, yaw: -0.55)
        b.width(0.22, 7.6, span: 0.12); b.width(0.48, 7.0, span: 0.12); b.width(0.76, 7.8, span: 0.10)
        b.ramp(0.30); b.ramp(0.64); b.turbo(0.18); b.turbo(0.46); b.turbo(0.80)
        b.crystalLane(0.08, 0.16, lateral: 0, count: 5)
        b.crystalLane(0.24, 0.34, lateral: 1.6, count: 6)
        b.crystalLane(0.44, 0.54, lateral: -1.4, count: 6)
        b.crystalLane(0.66, 0.80, lateral: 0, count: 7)
        b.power(.ghost, 0.20, lateral: 2.0); b.power(.magnet, 0.40, lateral: -2.0)
        b.power(.banana, 0.58, lateral: 0); b.power(.rocket, 0.76, lateral: 1.4)
        b.shortcut(0.39, lateral: 3.4, skip: 0.026)
        b.hazard(.crate, 0.16, lateral: 1); b.hazard(.cart, 0.36, lateral: 0)
        b.hazard(.bridge, 0.56, lateral: 0, radius: 1.3); b.hazard(.crate, 0.72, lateral: -1.6)
        for p in stride(from: Float(0.12), through: 0.90, by: 0.07) {
            b.hazard(.water, p, lateral: -8.8, radius: 4.2)
            b.hazard(.water, p + 0.02, lateral: 8.8, radius: 4.2)
        }
        b.decorateHarbor()
        b.rivals([.navy(skill: 1.010, lateral: -2.0), .pico(skill: 0.990, lateral: 2.2), .violet(skill: 0.930, lateral: 0.3)])
        return b.build()
    }

    static func tideGate() -> LevelDefinition {
        let b = LevelBuilder(id: .tideGate, name: "Tide Gate", subtitle: "Moving bridges", blurb: "The harbor gates swing. Time the moving bridges or kiss the drink.", theme: .harbor, palette: .harbor)
        b.length = 560; b.baseWidth = 10.6; b.slope = 0.10; b.parTime = 31; b.crystalStar = 24
        b.curve(0.04, 0.28, yaw: 0.80); b.curve(0.28, 0.54, yaw: -1.10); b.curve(0.54, 0.80, yaw: 0.95); b.curve(0.80, 0.96, yaw: -0.50)
        b.width(0.20, 7.4, span: 0.10); b.width(0.50, 6.8, span: 0.12); b.width(0.78, 7.6, span: 0.10)
        b.ramp(0.26); b.ramp(0.60); b.turbo(0.14); b.turbo(0.42); b.turbo(0.74)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 5)
        b.crystalLane(0.22, 0.32, lateral: 1.4, count: 6)
        b.crystalLane(0.40, 0.50, lateral: -1.2, count: 6)
        b.crystalLane(0.62, 0.74, lateral: 0.8, count: 6)
        b.crystalLane(0.82, 0.90, lateral: 0, count: 5)
        b.power(.ghost, 0.18, lateral: 1.8); b.power(.magnet, 0.36, lateral: -1.8)
        b.power(.rocket, 0.58, lateral: 0); b.power(.banana, 0.80, lateral: 1.2)
        b.hazard(.movingBridge, 0.24, lateral: 0, radius: 1.5)
        b.hazard(.movingBridge, 0.48, lateral: 0, radius: 1.5)
        b.hazard(.movingBridge, 0.72, lateral: 0, radius: 1.5)
        b.hazard(.crate, 0.34, lateral: 1.2); b.hazard(.cart, 0.64, lateral: -0.6)
        for p in stride(from: Float(0.10), through: 0.92, by: 0.06) {
            b.hazard(.water, p, lateral: -8.4, radius: 4.0)
            b.hazard(.water, p + 0.02, lateral: 8.4, radius: 4.0)
        }
        b.decorateHarbor()
        b.rivals([.navy(skill: 1.071, lateral: -1.8), .pico(skill: 1.050, lateral: 2.0), .coral(skill: 1.020, lateral: 0.2), .violet(skill: 0.990, lateral: 1.0)])
        return b.build()
    }

    static func glacierDrop() -> LevelDefinition {
        let b = LevelBuilder(id: .glacierDrop, name: "Glacier Drop", subtitle: "Big air + cut", blurb: "A hanging glacier with a high-line shortcut over the crevasse.", theme: .summit, palette: .summit)
        b.length = 660; b.baseWidth = 17.0; b.slope = 0.17; b.parTime = 31.5; b.crystalStar = 26
        b.curve(0.04, 0.22, yaw: 0.55); b.curve(0.22, 0.44, yaw: -0.85); b.curve(0.44, 0.66, yaw: 1.00); b.curve(0.66, 0.90, yaw: -0.60)
        b.elevation(0.20, height: 4.2, span: 0.07); b.elevation(0.48, height: 6.4, span: 0.09); b.elevation(0.74, height: 5.0, span: 0.08)
        b.ramp(0.18); b.ramp(0.46); b.ramp(0.72)
        b.turbo(0.10); b.turbo(0.32); b.turbo(0.56); b.turbo(0.84)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.24, 0.34, lateral: 4.2, count: 7)
        b.crystalLane(0.42, 0.52, lateral: -3.8, count: 8)
        b.crystalLane(0.60, 0.70, lateral: 2.0, count: 7)
        b.crystalLane(0.80, 0.92, lateral: 0, count: 8)
        b.power(.rocket, 0.16, lateral: 0); b.power(.magnet, 0.38, lateral: -5)
        b.power(.ghost, 0.58, lateral: 5); b.power(.banana, 0.78, lateral: 0)
        b.shortcut(0.50, lateral: 5.4, skip: 0.034)
        b.hazard(.wind, 0.28, lateral: 0, radius: 8); b.hazard(.wind, 0.62, lateral: 0, radius: 8)
        b.hazard(.snowman, 0.14, lateral: -6); b.hazard(.crate, 0.36, lateral: 3)
        b.hazard(.snowman, 0.68, lateral: 6)
        b.decorateSummit()
        b.rivals([.pico(skill: 1.074, lateral: -3.8), .ruby(skill: 1.064, lateral: 4.0), .amber(skill: 1.034, lateral: 0.4), .navy(skill: 0.994, lateral: -1.4)])
        return b.build()
    }

    static func icefallRun() -> LevelDefinition {
        let b = LevelBuilder(id: .icefallRun, name: "Icefall Run", subtitle: "Steep + white wall", blurb: "The icefall calves. Five rivals and an avalanche share the face.", theme: .summit, palette: .summit)
        b.length = 680; b.baseWidth = 16.0; b.slope = 0.18; b.parTime = 31; b.crystalStar = 26
        b.curve(0.02, 0.20, yaw: 0.40); b.curve(0.20, 0.40, yaw: -0.80); b.curve(0.40, 0.62, yaw: 1.05); b.curve(0.62, 0.82, yaw: -0.90); b.curve(0.82, 0.98, yaw: 0.45)
        b.elevation(0.24, height: 5.0, span: 0.07); b.elevation(0.52, height: 7.2, span: 0.10); b.elevation(0.76, height: 4.6, span: 0.07)
        b.ramp(0.22); b.ramp(0.50); b.ramp(0.74)
        b.turbo(0.10); b.turbo(0.34); b.turbo(0.58); b.turbo(0.82)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.22, 0.32, lateral: 3.8, count: 7)
        b.crystalLane(0.40, 0.50, lateral: -3.4, count: 8)
        b.crystalLane(0.58, 0.68, lateral: 2.2, count: 7)
        b.crystalLane(0.80, 0.92, lateral: 0, count: 8)
        b.power(.rocket, 0.16, lateral: 0); b.power(.ghost, 0.36, lateral: 4.5)
        b.power(.magnet, 0.54, lateral: -4.5); b.power(.banana, 0.70, lateral: 0); b.power(.rocket, 0.88, lateral: 2)
        b.avalanche(from: 0.46, to: 0.94, pace: 1.18)
        b.hazard(.wind, 0.30, lateral: 0, radius: 8); b.hazard(.wind, 0.64, lateral: 0, radius: 8)
        b.hazard(.snowman, 0.18, lateral: 6); b.hazard(.crate, 0.42, lateral: -3)
        b.decorateSummit()
        b.rivals([.pico(skill: 1.151, lateral: -4.0), .ruby(skill: 1.131, lateral: 4.2), .amber(skill: 1.101, lateral: 0.2), .navy(skill: 1.061, lateral: -1.6), .frost(skill: 1.111, lateral: 1.4)])
        return b.build()
    }

    static func pineWhisper() -> LevelDefinition {
        let b = LevelBuilder(id: .pineWhisper, name: "Pine Whisper", subtitle: "Soft forest carve", blurb: "A quiet pine corridor. Wide enough to breathe, tight enough to learn the woods.", theme: .forest, palette: .forest)
        b.length = 570; b.baseWidth = 15.0; b.slope = 0.11; b.parTime = 29; b.crystalStar = 29
        b.curve(0.04, 0.24, yaw: 0.75); b.curve(0.24, 0.48, yaw: -1.00); b.curve(0.48, 0.72, yaw: 0.90); b.curve(0.72, 0.94, yaw: -0.60)
        b.ramp(0.22); b.ramp(0.54, lateral: 1.6); b.turbo(0.14); b.turbo(0.40); b.turbo(0.76)
        b.crystalLane(0.08, 0.16, lateral: 0, count: 6)
        b.crystalLane(0.24, 0.34, lateral: 3.0, count: 7)
        b.crystalLane(0.42, 0.52, lateral: -2.8, count: 7)
        b.crystalLane(0.60, 0.70, lateral: 1.4, count: 6)
        b.crystalLane(0.80, 0.90, lateral: 0, count: 7)
        b.power(.magnet, 0.20, lateral: 4); b.power(.ghost, 0.46, lateral: -4)
        b.power(.banana, 0.64, lateral: 0); b.power(.rocket, 0.84, lateral: 2)
        b.hazard(.snowman, 0.18, lateral: -5); b.hazard(.crate, 0.36, lateral: 2)
        b.hazard(.snowman, 0.58, lateral: 5); b.hazard(.crate, 0.78, lateral: -2)
        b.decorateForest()
        b.rivals([.mint(skill: 1.087, lateral: -3.0), .pico(skill: 1.057, lateral: 3.2), .violet(skill: 1.007, lateral: 0.4)])
        return b.build()
    }

    static func timberSwitchback() -> LevelDefinition {
        let b = LevelBuilder(id: .timberSwitchback, name: "Timber Switchback", subtitle: "Hairpins + gate", blurb: "Stacked hairpins through old timber. Cut the last switch if you clip the gate.", theme: .forest, palette: .forest)
        b.length = 600; b.baseWidth = 13.0; b.slope = 0.125; b.parTime = 30.5; b.crystalStar = 27
        b.curve(0.00, 0.16, yaw: 1.35); b.curve(0.16, 0.34, yaw: -1.55); b.curve(0.34, 0.52, yaw: 1.40)
        b.curve(0.52, 0.70, yaw: -1.45); b.curve(0.70, 0.88, yaw: 1.10)
        b.width(0.24, 10.4, span: 0.08); b.width(0.56, 9.8, span: 0.08)
        b.ramp(0.28); b.ramp(0.66); b.turbo(0.12); b.turbo(0.38); b.turbo(0.62); b.turbo(0.84)
        b.crystalLane(0.06, 0.14, lateral: 2.0, count: 6)
        b.crystalLane(0.20, 0.30, lateral: -2.4, count: 7)
        b.crystalLane(0.38, 0.48, lateral: 2.2, count: 7)
        b.crystalLane(0.56, 0.66, lateral: -1.8, count: 6)
        b.crystalLane(0.78, 0.90, lateral: 0, count: 8)
        b.power(.ghost, 0.18, lateral: 0); b.power(.magnet, 0.42, lateral: 3.4)
        b.power(.rocket, 0.60, lateral: -3.2); b.power(.banana, 0.82, lateral: 0)
        b.shortcut(0.71, lateral: -3.8, skip: 0.030)
        b.hazard(.crate, 0.16, lateral: 1.2); b.hazard(.snowman, 0.32, lateral: -4)
        b.hazard(.crate, 0.50, lateral: 3); b.hazard(.snowman, 0.74, lateral: 4)
        b.decorateForest()
        b.rivals([.mint(skill: 1.104, lateral: -2.6), .pico(skill: 1.083, lateral: 2.8), .ruby(skill: 1.033, lateral: 0.2), .navy(skill: 1.012, lateral: -0.8)])
        return b.build()
    }

    static func owlHollow() -> LevelDefinition {
        let b = LevelBuilder(id: .owlHollow, name: "Owl Hollow", subtitle: "Dark timber chase", blurb: "Night forest. Flares help. The hollow coughs an avalanche of snow.", theme: .forest, palette: .forestNight)
        b.length = 620; b.baseWidth = 12.4; b.slope = 0.13; b.parTime = 30.5; b.crystalStar = 28
        b.curve(0.04, 0.26, yaw: 1.10); b.curve(0.26, 0.50, yaw: -1.25); b.curve(0.50, 0.74, yaw: 1.15); b.curve(0.74, 0.96, yaw: -0.80)
        b.width(0.40, 10.0, span: 0.10)
        b.ramp(0.20); b.ramp(0.48); b.ramp(0.76)
        b.turbo(0.12); b.turbo(0.36); b.turbo(0.60); b.turbo(0.84)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.22, 0.32, lateral: 2.6, count: 7)
        b.crystalLane(0.40, 0.50, lateral: -2.4, count: 7)
        b.crystalLane(0.58, 0.68, lateral: 1.6, count: 6)
        b.crystalLane(0.80, 0.92, lateral: 0, count: 8)
        b.power(.flare, 0.16, lateral: 3.2); b.power(.ghost, 0.34, lateral: 0)
        b.power(.rocket, 0.56, lateral: -3); b.power(.magnet, 0.78, lateral: 3)
        b.avalanche(from: 0.54, to: 0.92, pace: 1.16)
        b.hazard(.snowman, 0.18, lateral: -5); b.hazard(.crate, 0.38, lateral: 2)
        b.hazard(.snowman, 0.64, lateral: 5); b.hazard(.crate, 0.82, lateral: -2)
        b.decorateForest()
        b.rivals([.mint(skill: 1.095, lateral: -2.8), .pico(skill: 1.065, lateral: 3.0), .frost(skill: 1.034, lateral: 0.2), .violet(skill: 0.996, lateral: -1.0)])
        return b.build()
    }

    static func canyonGlow() -> LevelDefinition {
        let b = LevelBuilder(id: .canyonGlow, name: "Canyon Glow", subtitle: "Crystal walls", blurb: "A glowing slot canyon. Spires force you to pick a wall.", theme: .canyon, palette: .canyon)
        b.length = 600; b.baseWidth = 12.6; b.slope = 0.13; b.parTime = 31; b.crystalStar = 30
        b.curve(0.00, 0.22, yaw: 0.70); b.curve(0.22, 0.46, yaw: -1.20); b.curve(0.46, 0.70, yaw: 1.10); b.curve(0.70, 0.94, yaw: -0.75)
        b.width(0.30, 10.0, span: 0.10); b.width(0.64, 9.6, span: 0.10)
        b.ramp(0.24); b.ramp(0.58); b.turbo(0.12); b.turbo(0.40); b.turbo(0.72)
        b.crystalLane(0.06, 0.16, lateral: 2.2, count: 7)
        b.crystalLane(0.22, 0.32, lateral: -2.4, count: 7)
        b.crystalLane(0.40, 0.50, lateral: 0, count: 8)
        b.crystalLane(0.58, 0.68, lateral: 2.8, count: 7)
        b.crystalLane(0.80, 0.90, lateral: -2.0, count: 7)
        b.power(.magnet, 0.18, lateral: 0); b.power(.ghost, 0.44, lateral: -3)
        b.power(.rocket, 0.66, lateral: 3); b.power(.flare, 0.84, lateral: 0)
        for p in stride(from: Float(0.14), through: 0.86, by: 0.09) {
            b.hazard(.crystalSpire, p, lateral: (Int(p * 20) % 2 == 0) ? -2.8 : 2.8, radius: 0.95)
        }
        b.decorateCanyon()
        b.rivals([.frost(skill: 1.104, lateral: 2.4), .pico(skill: 1.085, lateral: -2.6), .ruby(skill: 1.045, lateral: 0.4), .mint(skill: 1.024, lateral: -0.8)])
        return b.build()
    }

    static func prismCut() -> LevelDefinition {
        let b = LevelBuilder(id: .prismCut, name: "Prism Cut", subtitle: "Razor lane + gate", blurb: "The canyon pinches to a prism. The right wall hides a skip.", theme: .canyon, palette: .canyon)
        b.length = 610; b.baseWidth = 11.0; b.slope = 0.14; b.parTime = 30.5; b.crystalStar = 25
        b.curve(0.00, 0.18, yaw: 1.05); b.curve(0.18, 0.40, yaw: -1.35); b.curve(0.40, 0.64, yaw: 1.25); b.curve(0.64, 0.90, yaw: -0.95)
        b.width(0.26, 8.6, span: 0.10); b.width(0.54, 8.2, span: 0.10); b.width(0.78, 9.0, span: 0.08)
        b.ramp(0.22); b.ramp(0.52, lateral: -1); b.ramp(0.80)
        b.turbo(0.10); b.turbo(0.36); b.turbo(0.62); b.turbo(0.86)
        b.crystalLane(0.06, 0.14, lateral: 1.6, count: 6)
        b.crystalLane(0.20, 0.30, lateral: -2.0, count: 7)
        b.crystalLane(0.38, 0.48, lateral: 2.2, count: 7)
        b.crystalLane(0.56, 0.66, lateral: 0, count: 7)
        b.crystalLane(0.78, 0.90, lateral: -1.6, count: 8)
        b.power(.ghost, 0.16, lateral: 0); b.power(.magnet, 0.40, lateral: 2.6)
        b.power(.rocket, 0.58, lateral: -2.6); b.power(.banana, 0.82, lateral: 0)
        b.shortcut(0.45, lateral: 3.6, skip: 0.033)
        for p in stride(from: Float(0.12), through: 0.88, by: 0.08) {
            b.hazard(.crystalSpire, p, lateral: sin(p * 26) * 2.4, radius: 0.85)
        }
        b.decorateCanyon()
        b.rivals([.frost(skill: 1.094, lateral: 2.2), .pico(skill: 1.063, lateral: -2.4), .amber(skill: 1.023, lateral: 0.2), .navy(skill: 1.003, lateral: -0.8)])
        return b.build()
    }

    static func steamVeil() -> LevelDefinition {
        let b = LevelBuilder(id: .steamVeil, name: "Steam Veil", subtitle: "Geysers & mist", blurb: "Hot springs under snow. Geysers hide the line; an avalanche rides the steam.", theme: .steam, palette: .steam)
        b.length = 590; b.baseWidth = 13.2; b.slope = 0.12; b.parTime = 31; b.crystalStar = 26
        b.curve(0.04, 0.26, yaw: 0.80); b.curve(0.26, 0.50, yaw: -1.10); b.curve(0.50, 0.74, yaw: 1.00); b.curve(0.74, 0.94, yaw: -0.65)
        b.ramp(0.22); b.ramp(0.56); b.turbo(0.14); b.turbo(0.40); b.turbo(0.70); b.turbo(0.88)
        b.crystalLane(0.08, 0.16, lateral: 0, count: 6)
        b.crystalLane(0.24, 0.34, lateral: 2.8, count: 7)
        b.crystalLane(0.42, 0.52, lateral: -2.6, count: 7)
        b.crystalLane(0.60, 0.70, lateral: 1.6, count: 6)
        b.crystalLane(0.80, 0.90, lateral: 0, count: 7)
        b.power(.ghost, 0.18, lateral: 3); b.power(.magnet, 0.38, lateral: -3)
        b.power(.rocket, 0.62, lateral: 0); b.power(.flare, 0.80, lateral: 2.4)
        b.avalanche(from: 0.56, to: 0.92, pace: 1.18)
        for p in stride(from: Float(0.14), through: 0.86, by: 0.08) {
            b.hazard(.geyser, p, lateral: sin(p * 18) * 3.0, radius: 1.15)
        }
        b.hazard(.crate, 0.30, lateral: 2); b.hazard(.snowman, 0.68, lateral: -4)
        b.decorateSteam()
        b.rivals([.coral(skill: 1.144, lateral: -2.6), .pico(skill: 1.114, lateral: 2.8), .ruby(skill: 1.094, lateral: 0.3), .mint(skill: 1.064, lateral: -1.0)])
        return b.build()
    }

    static func whiteoutPeak() -> LevelDefinition {
        let b = LevelBuilder(id: .whiteoutPeak, name: "Whiteout Peak", subtitle: "Blizzard + flares", blurb: "You cannot see the mountain. Flares punch holes in the white. Keep moving.", theme: .blizzard, palette: .blizzard)
        b.length = 640; b.baseWidth = 14.0; b.slope = 0.155; b.parTime = 30.5; b.crystalStar = 30
        b.curve(0.02, 0.20, yaw: 0.60); b.curve(0.20, 0.42, yaw: -1.00); b.curve(0.42, 0.64, yaw: 1.15); b.curve(0.64, 0.86, yaw: -0.85)
        b.elevation(0.28, height: 4.0, span: 0.07); b.elevation(0.58, height: 5.6, span: 0.08)
        b.ramp(0.20); b.ramp(0.46); b.ramp(0.74)
        b.turbo(0.10); b.turbo(0.34); b.turbo(0.58); b.turbo(0.82)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 6)
        b.crystalLane(0.22, 0.32, lateral: 3.4, count: 7)
        b.crystalLane(0.40, 0.50, lateral: -3.2, count: 8)
        b.crystalLane(0.60, 0.70, lateral: 1.8, count: 7)
        b.crystalLane(0.80, 0.90, lateral: 0, count: 8)
        b.power(.flare, 0.12, lateral: -3.6); b.power(.flare, 0.36, lateral: 3.6)
        b.power(.rocket, 0.52, lateral: 0); b.power(.ghost, 0.70, lateral: -4); b.power(.magnet, 0.86, lateral: 3)
        b.avalanche(from: 0.50, to: 0.94, pace: 1.20)
        b.hazard(.wind, 0.26, lateral: 0, radius: 9); b.hazard(.wind, 0.54, lateral: 0, radius: 9)
        b.hazard(.wind, 0.78, lateral: 0, radius: 9)
        b.hazard(.snowman, 0.18, lateral: 5); b.hazard(.crate, 0.44, lateral: -2)
        b.decorateBlizzard()
        b.rivals([.frost(skill: 1.118, lateral: -3.4), .pico(skill: 1.089, lateral: 3.6), .ruby(skill: 1.049, lateral: 0.4), .amber(skill: 1.029, lateral: -1.2), .navy(skill: 1.010, lateral: 1.6)])
        return b.build()
    }

    static func neonSlalom() -> LevelDefinition {
        let b = LevelBuilder(id: .neonSlalom, name: "Neon Slalom", subtitle: "Resort gates + cut", blurb: "A night ski resort painted in cyan and magenta. Slalom the arches; clip the VIP gate.", theme: .neon, palette: .neon)
        b.length = 600; b.baseWidth = 13.6; b.slope = 0.135; b.parTime = 30; b.crystalStar = 27
        b.curve(0.00, 0.18, yaw: 1.10); b.curve(0.18, 0.38, yaw: -1.30); b.curve(0.38, 0.58, yaw: 1.20)
        b.curve(0.58, 0.78, yaw: -1.15); b.curve(0.78, 0.96, yaw: 0.70)
        b.width(0.28, 10.6, span: 0.08); b.width(0.62, 10.2, span: 0.08)
        b.ramp(0.20); b.ramp(0.50, lateral: 1.4); b.ramp(0.78)
        b.turbo(0.10); b.turbo(0.34); b.turbo(0.58); b.turbo(0.84)
        b.crystalLane(0.06, 0.14, lateral: 2.0, count: 6)
        b.crystalLane(0.20, 0.30, lateral: -2.4, count: 7)
        b.crystalLane(0.38, 0.48, lateral: 2.2, count: 7)
        b.crystalLane(0.56, 0.66, lateral: -1.8, count: 7)
        b.crystalLane(0.78, 0.90, lateral: 0, count: 8)
        b.power(.rocket, 0.16, lateral: 0); b.power(.flare, 0.32, lateral: 3.4)
        b.power(.ghost, 0.54, lateral: -3.4); b.power(.magnet, 0.74, lateral: 0); b.power(.banana, 0.88, lateral: 2)
        b.shortcut(0.43, lateral: 4.0, skip: 0.031)
        for p in stride(from: Float(0.12), through: 0.88, by: 0.08) {
            b.hazard(.neonArch, p, lateral: 0, radius: 0)
        }
        b.hazard(.crate, 0.26, lateral: 1.6); b.hazard(.cart, 0.60, lateral: 0)
        b.decorateNeon()
        b.rivals([.coral(skill: 1.129, lateral: -2.8), .pico(skill: 1.109, lateral: 3.0), .ruby(skill: 1.070, lateral: 0.2), .amber(skill: 1.039, lateral: -1.2)])
        return b.build()
    }

    static func carnivalParade() -> LevelDefinition {
        let b = LevelBuilder(id: .carnivalParade, name: "Carnival Parade", subtitle: "Festive finale", blurb: "Floats, lights, and a late avalanche of confetti-snow. The pack is hungry.", theme: .carnival, palette: .carnival)
        b.length = 630; b.baseWidth = 14.8; b.slope = 0.14; b.parTime = 30; b.crystalStar = 32
        b.curve(0.02, 0.20, yaw: 0.85); b.curve(0.20, 0.40, yaw: -1.15); b.curve(0.40, 0.62, yaw: 1.20)
        b.curve(0.62, 0.82, yaw: -1.00); b.curve(0.82, 0.98, yaw: 0.55)
        b.ramp(0.18); b.ramp(0.44, lateral: -1.4); b.ramp(0.70)
        b.turbo(0.10); b.turbo(0.32); b.turbo(0.54); b.turbo(0.76); b.turbo(0.90)
        b.crystalLane(0.06, 0.14, lateral: 0, count: 7)
        b.crystalLane(0.20, 0.30, lateral: 3.2, count: 7)
        b.crystalLane(0.38, 0.48, lateral: -3.0, count: 8)
        b.crystalLane(0.56, 0.66, lateral: 2.0, count: 7)
        b.crystalLane(0.78, 0.90, lateral: 0, count: 8)
        b.power(.rocket, 0.14, lateral: 0); b.power(.magnet, 0.30, lateral: 4)
        b.power(.ghost, 0.48, lateral: -4); b.power(.flare, 0.64, lateral: 0); b.power(.banana, 0.82, lateral: 3)
        b.avalanche(from: 0.58, to: 0.95, pace: 1.22)
        b.shortcut(0.36, lateral: -4.6, skip: 0.028)
        for p in stride(from: Float(0.12), through: 0.86, by: 0.10) {
            b.hazard(.carnivalFloat, p, lateral: (Int(p * 16) % 2 == 0) ? -5.2 : 5.2, radius: 1.3)
        }
        b.hazard(.npc, 0.22, lateral: 0.8, radius: 0.8)
        b.hazard(.npc, 0.50, lateral: -1.0, radius: 0.8)
        b.hazard(.cart, 0.68, lateral: 0)
        b.decorateCarnival()
        b.rivals([.coral(skill: 1.167, lateral: -3.2), .pico(skill: 1.126, lateral: 3.4), .ruby(skill: 1.106, lateral: 0.2), .amber(skill: 1.086, lateral: -1.4), .frost(skill: 1.116, lateral: 1.6)])
        return b.build()
    }
}

extension UUID {
    /// A repeatable id made from two small integers (SplitMix64 mixing, so neighbours look unrelated).
    init(stable a: Int, _ b: Int) {
        var state = UInt64(truncatingIfNeeded: a) &* 0x9E3779B97F4A7C15 &+ UInt64(truncatingIfNeeded: b) &* 0xD1B54A32D192ED03
        func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        let high = next()
        let low = next()
        let text = String(
            format: "%08llX-%04llX-%04llX-%04llX-%012llX",
            high >> 32, (high >> 16) & 0xFFFF, high & 0xFFFF, (low >> 48) & 0xFFFF, low & 0xFFFF_FFFF_FFFF
        )
        self = UUID(uuidString: text) ?? UUID()
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
    var events: [CourseEvent] = []

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
        case .flare: kind = .flare
        }
        entities.append(PlacedEntity(kind: kind, progress: progress, lateral: lateral, scale: 1, radius: 0.95))
    }

    func hazard(_ kind: PropKind, _ progress: Float, lateral: Float, radius: Float = 1.05) {
        entities.append(PlacedEntity(kind: kind, progress: progress, lateral: lateral, scale: 1, radius: radius))
    }

    func rivals(_ list: [RivalConfig]) {
        rivalConfigs = list
    }

    /// A wall of snow that starts running when the player reaches `from` and dies out at `to`.
    /// `pace` is its speed as a fraction of the player's cruising speed on this course, so
    /// 0.9 means a clean run slowly pulls away while every crash gives the wall ground back.
    /// Set `length` and `slope` before calling this.
    func avalanche(from: Float, to: Float, pace: Float = 0.9) {
        let cruise = 13.5 + slope * 22
        events.append(CourseEvent(kind: .avalanche, start: from, end: to, lateral: 0, magnitude: cruise * pace / length))
        entities.append(PlacedEntity(kind: .avalanche, progress: from, lateral: 0, scale: 1, radius: 12))
    }

    func shortcut(_ progress: Float, lateral: Float, skip: Float = 0.03) {
        events.append(CourseEvent(kind: .shortcut, start: progress, end: progress + 0.02, lateral: lateral, magnitude: skip))
        entities.append(PlacedEntity(kind: .shortcut, progress: progress, lateral: lateral, scale: 1, radius: 1.55))
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
        // Authored content gets stable ids. Rivals decide which obstacles they overlook from
        // these, so a course plays the same way on every launch instead of reshuffling itself.
        for index in all.indices {
            all[index].id = UUID(stable: id.order, index)
        }
        for index in rivalConfigs.indices {
            rivalConfigs[index].id = UUID(stable: id.order, 10_000 + index)
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
            crystalStar: crystalStar,
            events: events
        )
    }

    func decorateForest() {
        for p in stride(from: Float(0.04), through: 0.96, by: 0.045) {
            entities.append(PlacedEntity(kind: .pine, progress: p, lateral: -10 - Float.random(in: 0...2.4), scale: Float.random(in: 0.95...1.5), radius: 0))
            entities.append(PlacedEntity(kind: .pine, progress: p + 0.02, lateral: 10 + Float.random(in: 0...2.4), scale: Float.random(in: 0.95...1.5), radius: 0))
        }
        for p in stride(from: Float(0.10), through: 0.90, by: 0.14) {
            entities.append(PlacedEntity(kind: .lantern, progress: p, lateral: (Int(p * 18) % 2 == 0) ? -6.4 : 6.4, scale: 1, radius: 0))
        }
    }

    func decorateCanyon() {
        for p in stride(from: Float(0.06), through: 0.94, by: 0.06) {
            entities.append(PlacedEntity(kind: .crystalSpire, progress: p, lateral: -8.5, scale: 1.3, radius: 0))
            entities.append(PlacedEntity(kind: .crystalSpire, progress: p + 0.03, lateral: 8.5, scale: 1.4, radius: 0))
        }
    }

    func decorateSteam() {
        for p in stride(from: Float(0.08), through: 0.92, by: 0.07) {
            entities.append(PlacedEntity(kind: .geyser, progress: p, lateral: (Int(p * 12) % 2 == 0) ? -7 : 7, scale: 1, radius: 0))
            entities.append(PlacedEntity(kind: .pine, progress: p, lateral: -12, scale: 0.9, radius: 0))
        }
    }

    func decorateBlizzard() {
        decorateSummit()
        for p in stride(from: Float(0.10), through: 0.90, by: 0.10) {
            entities.append(PlacedEntity(kind: .wind, progress: p, lateral: 0, scale: 1, radius: 0))
        }
    }

    func decorateNeon() {
        for p in stride(from: Float(0.08), through: 0.92, by: 0.07) {
            entities.append(PlacedEntity(kind: .neonArch, progress: p, lateral: 0, scale: 1, radius: 0))
            entities.append(PlacedEntity(kind: .lantern, progress: p, lateral: (Int(p * 16) % 2 == 0) ? -7.2 : 7.2, scale: 1, radius: 0))
        }
    }

    func decorateCarnival() {
        for p in stride(from: Float(0.07), through: 0.93, by: 0.08) {
            entities.append(PlacedEntity(kind: .carnivalFloat, progress: p, lateral: (Int(p * 10) % 2 == 0) ? -9 : 9, scale: 1, radius: 0))
            entities.append(PlacedEntity(kind: .lantern, progress: p + 0.03, lateral: (Int(p * 14) % 2 == 0) ? -6 : 6, scale: 1, radius: 0))
        }
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

    static let forest = LevelPalette(
        snow: SIMD3(0.90, 0.95, 0.92),
        ice: SIMD3(0.45, 0.78, 0.62),
        skyTop: SIMD3(0.42, 0.62, 0.58),
        skyBottom: SIMD3(0.78, 0.88, 0.82),
        fog: SIMD3(0.72, 0.82, 0.76),
        fogStart: 18,
        fogEnd: 110,
        ambient: SIMD3(0.55, 0.68, 0.58),
        sunColor: SIMD3(0.85, 0.95, 0.80),
        sunIntensity: 700,
        wall: SIMD3(0.28, 0.42, 0.30),
        accent: SIMD3(0.20, 0.72, 0.48),
        wood: SIMD3(0.40, 0.26, 0.16),
        night: false
    )

    static let forestNight = LevelPalette(
        snow: SIMD3(0.70, 0.78, 0.82),
        ice: SIMD3(0.40, 0.70, 0.78),
        skyTop: SIMD3(0.06, 0.10, 0.16),
        skyBottom: SIMD3(0.10, 0.16, 0.22),
        fog: SIMD3(0.12, 0.16, 0.20),
        fogStart: 10,
        fogEnd: 70,
        ambient: SIMD3(0.22, 0.30, 0.28),
        sunColor: SIMD3(0.45, 0.70, 0.80),
        sunIntensity: 260,
        wall: SIMD3(0.16, 0.24, 0.20),
        accent: SIMD3(0.45, 0.90, 0.70),
        wood: SIMD3(0.28, 0.20, 0.14),
        night: true
    )

    static let canyon = LevelPalette(
        snow: SIMD3(0.82, 0.90, 0.98),
        ice: SIMD3(0.55, 0.80, 1.0),
        skyTop: SIMD3(0.18, 0.32, 0.52),
        skyBottom: SIMD3(0.42, 0.58, 0.78),
        fog: SIMD3(0.40, 0.55, 0.72),
        fogStart: 14,
        fogEnd: 90,
        ambient: SIMD3(0.40, 0.52, 0.68),
        sunColor: SIMD3(0.70, 0.88, 1.0),
        sunIntensity: 620,
        wall: SIMD3(0.42, 0.62, 0.82),
        accent: SIMD3(0.45, 0.90, 1.0),
        wood: SIMD3(0.36, 0.28, 0.22),
        night: false
    )

    static let steam = LevelPalette(
        snow: SIMD3(0.92, 0.94, 0.90),
        ice: SIMD3(0.70, 0.86, 0.80),
        skyTop: SIMD3(0.62, 0.70, 0.68),
        skyBottom: SIMD3(0.88, 0.86, 0.78),
        fog: SIMD3(0.82, 0.84, 0.78),
        fogStart: 8,
        fogEnd: 70,
        ambient: SIMD3(0.70, 0.68, 0.60),
        sunColor: SIMD3(1.0, 0.86, 0.62),
        sunIntensity: 540,
        wall: SIMD3(0.62, 0.48, 0.36),
        accent: SIMD3(0.95, 0.55, 0.28),
        wood: SIMD3(0.48, 0.32, 0.20),
        night: false
    )

    static let blizzard = LevelPalette(
        snow: SIMD3(0.96, 0.98, 1.0),
        ice: SIMD3(0.78, 0.90, 1.0),
        skyTop: SIMD3(0.62, 0.70, 0.80),
        skyBottom: SIMD3(0.88, 0.92, 0.96),
        fog: SIMD3(0.90, 0.93, 0.97),
        fogStart: 6,
        fogEnd: 55,
        ambient: SIMD3(0.78, 0.84, 0.90),
        sunColor: SIMD3(0.90, 0.94, 1.0),
        sunIntensity: 380,
        wall: SIMD3(0.80, 0.86, 0.92),
        accent: SIMD3(0.55, 0.78, 1.0),
        wood: SIMD3(0.40, 0.30, 0.22),
        night: false
    )

    static let neon = LevelPalette(
        snow: SIMD3(0.16, 0.18, 0.28),
        ice: SIMD3(0.20, 0.90, 1.0),
        skyTop: SIMD3(0.04, 0.04, 0.12),
        skyBottom: SIMD3(0.10, 0.06, 0.20),
        fog: SIMD3(0.08, 0.06, 0.16),
        fogStart: 12,
        fogEnd: 80,
        ambient: SIMD3(0.18, 0.14, 0.28),
        sunColor: SIMD3(0.80, 0.30, 1.0),
        sunIntensity: 220,
        wall: SIMD3(0.18, 0.10, 0.32),
        accent: SIMD3(1.0, 0.28, 0.72),
        wood: SIMD3(0.22, 0.16, 0.28),
        night: true
    )

    static let carnival = LevelPalette(
        snow: SIMD3(0.96, 0.92, 0.88),
        ice: SIMD3(1.0, 0.45, 0.62),
        skyTop: SIMD3(0.28, 0.10, 0.32),
        skyBottom: SIMD3(0.55, 0.18, 0.36),
        fog: SIMD3(0.42, 0.18, 0.32),
        fogStart: 16,
        fogEnd: 100,
        ambient: SIMD3(0.50, 0.28, 0.36),
        sunColor: SIMD3(1.0, 0.70, 0.35),
        sunIntensity: 520,
        wall: SIMD3(0.72, 0.22, 0.38),
        accent: SIMD3(1.0, 0.82, 0.20),
        wood: SIMD3(0.50, 0.28, 0.18),
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

    static func frost(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Frost", color: SIMD3(0.70, 0.88, 1.0), personality: .aggressive, skill: skill, startLateral: lateral)
    }

    static func mint(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Mint", color: SIMD3(0.32, 0.86, 0.62), personality: .cautious, skill: skill, startLateral: lateral)
    }

    static func coral(skill: Float, lateral: Float) -> RivalConfig {
        RivalConfig(name: "Coral", color: SIMD3(1.0, 0.42, 0.48), personality: .hoarder, skill: skill, startLateral: lateral)
    }
}
