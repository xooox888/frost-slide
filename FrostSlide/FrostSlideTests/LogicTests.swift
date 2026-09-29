import XCTest

@testable import FrostSlide

/// Fast checks that need no simulator pictures. They also show at a glance that the test target
/// builds and runs before any snapshots have been recorded.
@MainActor
final class LogicTests: XCTestCase {
    func testSavesFromBeforeUsageStatsKeepThemOn() throws {
        let old = #"{"tiltSteering":true,"selectedSkin":"gold"}"#
        let settings = try JSONDecoder().decode(GameSettings.self, from: Data(old.utf8))
        XCTAssertTrue(settings.shareUsageData)
        XCTAssertEqual(settings.selectedSkin, .gold)
    }

    func testOptingOutOfUsageStatsSurvivesASave() throws {
        var settings = GameSettings.default
        settings.shareUsageData = false
        let saved = try JSONEncoder().encode(settings)
        XCTAssertFalse(try JSONDecoder().decode(GameSettings.self, from: saved).shareUsageData)
    }

    func testPlayersWhoPaidStartWithoutAds() throws {
        let suite = "logic.store"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        XCTAssertFalse(StoreManager(defaults: defaults).adsRemoved)
        defaults.set(true, forKey: StoreManager.cacheKey)
        XCTAssertTrue(StoreManager(defaults: defaults).adsRemoved)
        defaults.removePersistentDomain(forName: suite)
    }

    func testAnalyticsEventsCarryOnlyTheirFixedFields() {
        let finished = Analytics.Event.raceFinished(course: 7, place: 1, stars: 3, perfect: true, seconds: 27.84, crashes: 1)
        XCTAssertEqual(finished.name, "Race.finished")
        XCTAssertEqual(Set(finished.parameters.keys), ["course", "place", "stars", "perfect", "crashes"])
        XCTAssertEqual(finished.floatValue, 27.84)

        let started = Analytics.Event.raceStarted(course: 3, daily: true)
        XCTAssertEqual(started.parameters, ["course": "3", "daily": "yes"])
        XCTAssertNil(started.floatValue)
        XCTAssertTrue(Analytics.Event.adsRemoved.parameters.isEmpty)
    }

    func testAnalyticsStaysOffWithoutAnAppID() {
        // The shipped placeholder must keep analytics off until a real App ID is pasted in.
        XCTAssertEqual(AnalyticsConfig.isConfigured, !AnalyticsConfig.appID.hasPrefix("YOUR-"))
    }
}
