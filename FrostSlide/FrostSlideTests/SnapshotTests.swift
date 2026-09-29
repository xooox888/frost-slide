import SnapshotTesting
import SwiftUI
import XCTest

@testable import FrostSlide

/// Picture tests for the screens that are most likely to break on a different phone size.
///
/// The first run has no reference pictures: every test records one and reports "No reference was
/// found", which is expected. Run the tests again to compare, and commit the `__Snapshots__`
/// folder. Pictures depend on the simulator's device model and iOS version, so record and compare
/// on the same one (an iPhone 15 or 16 on iOS 17 or 18 works well).
///
/// The main menu and the course map are left out on purpose: they show today's daily challenge,
/// so their pictures would change every day.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let phones: [(name: String, config: ViewImageConfig)] = [
        ("small", .iPhoneSe),
        ("large", .iPhone13ProMax)
    ]

    // MARK: - Race HUD

    func testHUDCountdownBriefing() {
        let hud = sampleHUD { $0.countdown = 3 }
        check(hudOverBackdrop(hud, showHints: true), named: "briefing")
    }

    func testHUDRacingWithAvalancheAndRefillOffer() {
        let hud = sampleHUD {
            $0.racing = true
            $0.time = 14.2
            $0.progress = 0.52
            $0.place = 2
            $0.crystals = 14
            $0.turbo = 0
            $0.combo = 4
            $0.comboFraction = 0.6
            $0.speedKph = 78
            $0.avalancheThreat = true
            $0.avalancheGap = 19
            $0.toast = "Near miss x4"
        }
        check(hudOverBackdrop(hud, rewardedReady: true), named: "avalanche")
    }

    func testHUDRacingWithGhostAndFullTurbo() {
        let hud = sampleHUD {
            $0.racing = true
            $0.time = 9.6
            $0.progress = 0.31
            $0.crystals = 9
            $0.turbo = 1
            $0.bananaArmed = true
            $0.ghostGap = -0.42
            $0.speedKph = 91
        }
        check(hudOverBackdrop(hud), named: "ghost")
    }

    // MARK: - Screens

    func testResultsAfterAPerfectRun() {
        let model = makeModel()
        model.lastResult = sampleResult
        check(host(ResultsView(), model: model), named: "perfect")
    }

    func testSettings() {
        check(host(SettingsView(), model: makeModel(), store: freshStore), named: "settings")
    }

    // MARK: - Helpers

    private func check(
        _ view: some View,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        for phone in phones {
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: phone.config, precision: 0.99, perceptualPrecision: 0.97),
                named: "\(name)-\(phone.name)",
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    private func hudOverBackdrop(_ hud: HUDSnapshot, rewardedReady: Bool = false, showHints: Bool = false) -> some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.62, green: 0.80, blue: 0.96), .white], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RaceHUDView(
                hud: hud,
                paused: false,
                rewardedReady: rewardedReady,
                showHints: showHints,
                onPause: {},
                boostChanged: { _ in },
                dropBanana: {}
            )
        }
    }

    private func host(_ view: some View, model: AppModel, store: StoreManager? = nil) -> some View {
        view
            .environmentObject(model)
            .environmentObject(AdManager.shared)
            .environmentObject(store ?? adFreeStore)
    }

    private func makeModel() -> AppModel {
        let records: [LevelID: LevelRecord] = [
            .villageDash: LevelRecord(bestPlace: 1, bestStars: 3, bestTime: 27.4, bestCrystals: 30, timesPlayed: 5, ghost: nil, perfect: true),
            .marketMayhem: LevelRecord(bestPlace: 2, bestStars: 2, bestTime: 29.9, bestCrystals: 22, timesPlayed: 3, ghost: nil, perfect: false)
        ]
        let persistence = GamePersistence(
            unlocked: Set(LevelID.allCases.prefix(4)),
            records: records,
            settings: .default
        )
        return AppModel(persistence: persistence)
    }

    /// A store that says the player has bought Remove Ads, so no banner is drawn.
    private var adFreeStore: StoreManager {
        makeStore(named: "snapshots.adfree", adsRemoved: true)
    }

    private var freshStore: StoreManager {
        makeStore(named: "snapshots.fresh", adsRemoved: false)
    }

    private func makeStore(named suite: String, adsRemoved: Bool) -> StoreManager {
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        defaults.set(adsRemoved, forKey: StoreManager.cacheKey)
        return StoreManager(defaults: defaults)
    }

    private func sampleHUD(_ tweak: (inout HUDSnapshot) -> Void) -> HUDSnapshot {
        var hud = HUDSnapshot.empty
        hud.levelName = "Aurora Night"
        hud.courseNumber = 7
        hud.parTime = 31
        hud.crystalGoal = 26
        hud.crystalTotal = 31
        hud.fieldSize = 4
        hud.rivalProgress = [0.34, 0.27, 0.21]
        hud.rivalColors = [SIMD3(0.22, 0.78, 0.42), SIMD3(0.92, 0.24, 0.32), SIMD3(0.58, 0.38, 0.86)]
        tweak(&hud)
        return hud
    }

    private var sampleResult: RaceResult {
        let you = PodiumEntry(id: "you", name: "You", place: 1, time: 27.84, isPlayer: true, color: SledSkin.cyan.color)
        let rivals = [
            PodiumEntry(id: "pico", name: "Pico", place: 2, time: 28.61, isPlayer: false, color: SIMD3(0.22, 0.78, 0.42)),
            PodiumEntry(id: "ruby", name: "Ruby", place: 3, time: 29.30, isPlayer: false, color: SIMD3(0.92, 0.24, 0.32)),
            PodiumEntry(id: "violet", name: "Violet", place: 4, time: 30.72, isPlayer: false, color: SIMD3(0.58, 0.38, 0.86))
        ]
        var result = RaceResult(
            level: .auroraNight,
            place: 1,
            fieldSize: 4,
            time: 27.84,
            crystals: 27,
            crystalTotal: 31,
            stars: 3,
            podium: [you] + rivals.prefix(2),
            comboMax: 9,
            nearMisses: 4,
            unlockedSkin: nil,
            daily: false
        )
        result.parTime = 28
        result.crystalGoal = 26
        result.crashes = 1
        result.standings = [you] + rivals
        result.previousBest = 29.4
        result.newBest = true
        return result
    }
}
