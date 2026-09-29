# Frost Slide

A native iOS downhill sled racer. You are a red panda cub in a beanie on a glowing cyan disc, carving an ice trail through 24 original courses.

Built with **Swift + SwiftUI** for menus, HUD, results, and settings, and **RealityKit** for all 3D gameplay (Entity / Component, `ARView` in non-AR game mode embedded in SwiftUI). No SceneKit. Portrait, iPhone first, iOS 17+. Bundle id: **`com.frostslide.FrostSlide`**. Version **1.0.0** (build 1).

Original Frost Slide art and UI only — not Sled Surfers (or any other game) assets or branding.

> **Rebuilt on three.js.** [`web/`](web/README.md) is the whole game rebuilt as a web app
> (TypeScript, three.js, Preact) in a native iOS shell (Capacitor), proven against this Swift
> engine course by course. It ships as version 2.0.0 under the same bundle id and keeps players'
> saves. See [`web/README.md`](web/README.md) and the plan in [`web/PLAN.md`](web/PLAN.md). The
> rest of this page describes the Swift app, which stays until the web build has been played on
> real iPhones.

## Open and run

1. Install Xcode 15 or newer (iOS 17 SDK). Xcode 16+ recommended so Swift Package Manager can resolve Google Mobile Ads.
2. Open `FrostSlide/FrostSlide.xcodeproj`.
3. Let Xcode resolve the Swift packages (first time only, a few minutes):
   **GoogleMobileAds** (ads), **ConfettiSwiftUI** (results screen), **TelemetryDeck** (anonymous stats),
   **SwiftLintPlugins** (lint on every build) and **swift-snapshot-testing** (tests only).
   The first build asks you to *Trust & Enable* the SwiftLint plugin.
4. Select the **FrostSlide** scheme and an iPhone simulator.
5. Set your Personal Team under Signing & Capabilities if asked.
6. Run. Portrait. First launch may prompt App Tracking Transparency (decline is fine; ads still try to fill).

If SPM cannot resolve, File → Add Package Dependencies and paste the package's GitHub URL. CocoaPods is not required.

## How to play

- **Steer:** drag left or right anywhere on the slope. Small drags are precise, a full swipe is full lock. Tune it with **Steering sensitivity** in Settings, or add tilt steering.
- **Turbo:** hold **BOOST**. Crystals fill the meter, so a clean run through the crystal lanes is worth about three seconds. Near misses and combo chains add a little more. Tapping BOOST as the light turns green gives a launch.
- **Racing line:** the inside of a bend is a shorter road, and bends push you toward the outside wall. Hold the inside line to save time; grinding the wall costs speed.
- **Ice:** patches of ice keep you sliding sideways and dull your steering. Plan your line before you reach them.
- **Near miss / combo:** skim a hazard or chain crystals. HUD shows **xN** with a ring that runs down as the chain expires.
- **Ghost:** a translucent copy of your best run on that course, with a live "ahead/behind" readout (Settings toggle).
- **Flares:** night / blizzard pickups that punch a hole in the dark.
- **Shortcuts:** cyan gates skip a bite of track.
- **Avalanche:** on seven later courses a wall of snow starts running when you reach the marked stretch. The HUD counts down how far behind you it is (it also shows on the progress rail) and the screen rumbles as it closes in. Spend your turbo to stay ahead. If it catches you it buries you once: big loss of speed, but it then runs on ahead. Rivals behind you get buried too.
- **Water (harbor courses):** a splash puts you back on the track a little way behind, slowed and stunned. You lose about three seconds.
- **Rewarded refill (optional):** if turbo is low, tap **REFILL** once per race to watch a video. Never forced.
- **Peel:** pick up a banana, tap **PEEL** to drop it behind you. It trips the first sled that hits it and then it is gone. Three peels at most, and they fade after 20 seconds.
- Crystals and power-ups are yours alone: rivals earn their turbo over time and never empty a lane before you reach it.
- The race pauses by itself if you leave the app or a call comes in.
- Finish a course to unlock the next. Stars unlock sled skins in Settings.
- **Daily Challenge** picks one unlocked course and one goal from the UTC date: *Beat par*, *Top 2 finish*, *Crystal hunt* or *Clean run*. The day only counts when the goal is met, a miss can be retried, and consecutive days build a streak.

Unlock-all exists only in **DEBUG** builds. Release / TestFlight / App Store binaries ignore it.

### Stars

Finishing is worth 1 star. Bonus points add up to two more:

| Bonus | Points |
| --- | --- |
| Win the race | 2 |
| Finish 2nd | 1 |
| Reach the crystal goal | 1 |
| Beat the par time | 1 |

Two points make 3 stars. A win alone is enough, but a runner-up (or someone who can't catch the pack on a hard course) can still get there with the crystal and par goals. Score all four and it's a **perfect run** (a seal on the course card). The goals for a course are shown during the countdown and again on the pause menu; the results screen shows where every point came from.

### Courses (24, 8 worlds)

Early worlds are wide and forgiving. Later worlds tighten the lane, add moving bridges, shortcut gates, and avalanche chases. 3–5 AI rivals each. Rival strength is calibrated course by course so a solid player wins the early worlds almost every time and the last courses are a real fight. A smooth rubber band keeps packs readable without stealing the win.

**Village & Market**
1. Village Dash — ice-crystal arches, wide streets  
2. Market Mayhem — alleys, stalls, carts  
3. Alley Sprint — squeeze + first shortcut gate  

**Ice Caves**
4. Ice Cave Spiral — blue helix, stalactites  
5. Crystal Grotto — spires and ice patches  
6. Frozen Hollow — tight helix + avalanche  

**Aurora Night**
7. Aurora Night — glow pads, low visibility  
8. Polar Veil — flares and a hidden cut  
9. Midnight Ribbon — night chase + powder wall  

**Harbor**
10. Harbor Freeze — docks; water = checkpoint + 3s  
11. Driftwood Docks — narrow planks + cut  
12. Tide Gate — moving bridges  

**Summit & Glacier**
13. Summit Rush — steep jumps and wind  
14. Glacier Drop — big air + high-line gate  
15. Icefall Run — five rivals and a white wall  

**Frozen Forest**
16. Pine Whisper — soft forest carve  
17. Timber Switchback — hairpins + gate  
18. Owl Hollow — dark timber chase  

**Canyon & Steam**
19. Canyon Glow — crystal walls  
20. Prism Cut — razor lane + skip  
21. Steam Veil — geysers, mist, avalanche  

**Storm & Spectacle**
22. Whiteout Peak — blizzard + flares  
23. Neon Slalom — resort arches + VIP gate  
24. Carnival Parade — floats, lights, finale chase  

## Ads (AdMob)

Default configuration uses **Google test ad unit IDs**. The game stays playable if ads fail to load.

| Placement | When | Unit |
| --- | --- | --- |
| Banner | Main menu + course map only | Test banner |
| Interstitial | After results, when tapping Next / Map / Menu (not rematch, not mid-race) | Test interstitial |
| Rewarded | Opt-in **REFILL** on the race HUD, once per race | Test rewarded |

### Swap test → production IDs

1. Create an AdMob account and an **iOS app** with bundle id `com.frostslide.FrostSlide`.
2. Create Banner, Interstitial, and Rewarded units.
3. Edit `FrostSlide/FrostSlide/Ads/AdConfig.swift`:
   - Set `useGoogleTestAds = false`
   - Paste `productionAppID`, `productionBanner`, `productionInterstitial`, `productionRewarded`
4. Replace `GADApplicationIdentifier` in `FrostSlide/FrostSlide/Info.plist` with the same production **app** ID (`ca-app-pub-…~…`).
5. Host a real privacy policy and replace `https://example.com/frost-slide-privacy` in `AdConfig.privacyPolicyURL` (Settings link + this README).
6. Run on a device with a non-test unit only after AdMob has approved the app.

Test IDs (already wired):

- App: `ca-app-pub-3940256099942544~1458002511`
- Banner: `ca-app-pub-3940256099942544/2934735716`
- Interstitial: `ca-app-pub-3940256099942544/4411468910`
- Rewarded: `ca-app-pub-3940256099942544/1712485313`

## Remove Ads purchase (StoreKit 2)

One non-consumable, **`com.frostslide.FrostSlide.removeads`**, sold from a card in Settings (with *Restore purchases*). It removes the menu banners and the full-screen ads between screens; the optional **REFILL** video stays because the player asks for it.

- **Before it can sell:** in App Store Connect create an *In-App Purchase → Non-Consumable* with that product ID, a price, a display name and a review screenshot, and add it to the app version you submit.
- **Testing without the store:** Product → Scheme → Edit Scheme → Run → Options → *StoreKit Configuration* → `Store/Products.storekit`. Purchases then work in the Simulator, and Debug → StoreKit → Manage Transactions can refund or reset them.
- `StoreManager` caches the answer between launches, so a paying player never sees an ad flash up, and an offline launch can only switch ads off. Refunds arrive as revoked transactions.

## Usage stats (TelemetryDeck)

Anonymous events for balancing: `Race.started`, `Race.finished` (course, place, stars, crashes, time), `Race.abandoned` (course, percent of the way), `Daily.completed` and `Store.adsRemoved`. No names, no advertising ID; TelemetryDeck hashes a per-install identifier before it leaves the phone.

- **Off until you set it up:** create an app at [telemetrydeck.com](https://telemetrydeck.com) and paste its App ID into `Analytics/AnalyticsConfig.swift`. Until then nothing is sent.
- Players can switch it off in Settings → *Share anonymous stats* (on by default); that stops the SDK rather than muting it. Debug builds send nothing, and neither do unit tests.
- `PrivacyInfo.xcprivacy` declares product-interaction and device-ID data for analytics (not linked, not tracking). Answer the **App Privacy** questions in App Store Connect the same way.

## Tests and lint

- **Run tests:** Product → Test (⌘U). `LogicTests` are plain checks. `ScreenSnapshotTests` (swift-snapshot-testing) draw the race HUD, results and settings screens on a small and a large iPhone. **The first run only records reference pictures and reports "No reference was found": run again to compare, then commit the `FrostSlideTests/__Snapshots__` folder.** Record and compare on the same simulator model and iOS version.
- **Lint:** SwiftLint runs on every build as a build-tool plugin, with the rules in `FrostSlide/.swiftlint.yml` (it has to sit next to the `.xcodeproj` for the plugin to find it). Nothing there is an error, so lint warns but never blocks a build. From a terminal, `swiftlint lint` in the `FrostSlide` folder does the same. On CI, pass `-skipPackagePluginValidation` to `xcodebuild` so the plugin can run without the trust prompt.
- The engine has its own Linux test tool: [`tools/headless`](tools/headless/README.md).

## Privacy policy

**TODO — placeholder:** [https://example.com/frost-slide-privacy](https://example.com/frost-slide-privacy)

Publish a real page (what you collect, AdMob/ATT, kids) and paste that URL into `AdConfig.privacyPolicyURL` and App Store Connect.

## App Store notes (age / content)

Suggested questionnaire answers:

- Age rating **4+** (or 9+ if you prefer a slightly firmer cartoon-crash label)
- Cartoon / fantasy violence only (sled bumps, splash respawn) — **no realistic violence**
- **No** gambling, contests, or loot boxes
- **No** user-generated content, social, or chat
- Ads: yes (AdMob). Unrestricted web access: no
- In-app purchases: one non-consumable, **Remove Ads**
- Made for Kids: **no** (ads + ATT). Do not check Made for Kids while using AdMob

## Shipping checklist

1. Enroll in the [Apple Developer Program](https://developer.apple.com).
2. App Store Connect → New App → iOS, name **Frost Slide**, bundle id **`com.frostslide.FrostSlide`**, SKU of your choice.
3. Replace AdMob test IDs (see above) and the privacy-policy URL.
4. Archive a **Release** build (Product → Archive) and upload with Organizer / Transporter.
5. Screenshots: use `Marketing/screenshots/` as a starting set, then capture live Simulator stills of Village Dash, Ice Cave, and Aurora Night on a 6.7" iPhone.
6. Create the **Remove Ads** in-app purchase (see above) and paste the TelemetryDeck App ID if you want stats.
7. Fill Privacy Nutrition Labels (UserDefaults for saves; usage data and a device ID for analytics if enabled; tracking only if the player allows ATT for ads).
8. Export compliance: **ITSAppUsesNonExemptEncryption** is already `false` (HTTPS only).
9. Submit for TestFlight, then App Store review.

## Marketing visuals

Original stills live in [`Marketing/screenshots/`](Marketing/screenshots/) (menu hero, brand badge, Village Dash, Ice Cave, Aurora Night). They are Frost Slide–branded (navy + electric cyan, ice-crystal gates), not live Simulator captures. Capture those on a Mac before submission.

## Headless balance harness

`tools/headless/` compiles the real `Core/` and `Engine/` sources on Linux (with small stand-ins for SwiftUI, CoreMotion and the renderer) and races them with scripted bots of five skill levels. It runs the engine self-tests, sweeps win rates, par and crystal-goal rates across all 24 courses, and re-calibrates rival strength. See its README. `tools/validate_tracks.py` remains as a quick, dependency-free geometry check.

## Architecture

```
FrostSlide/FrostSlide/
  FrostSlideApp.swift     App + ATT/AdMob/store start
  Ads/                    AdConfig, AdManager, BannerAdView
  Store/                  StoreManager (Remove Ads, StoreKit 2), Products.storekit test config
  Analytics/              Anonymous usage stats (TelemetryDeck) and its config
  App/                    Navigation + persistence
  Core/                   Levels, save data, audio/haptics
  Engine/                 Arcade spline sim (progress + lateral + air); Tuning holds every balance constant
  Core/Progression.swift  Worlds, sled skins, daily challenge, ghost takes
  Reality/                RealityKit world (WorldController, factories, meshes)
  UI/                     Menu, map, HUD, results, settings
  PrivacyInfo.xcprivacy   UserDefaults reason CA92.1, analytics data types
  Info.plist              Display name, ATT, AdMob app id, SKAdNetwork
FrostSlide/FrostSlideTests/  Logic checks and snapshot pictures of the main screens
FrostSlide/.swiftlint.yml    Lint rules (next to the .xcodeproj, where the build plugin looks)
```

The race viewport is `ARView(cameraMode: .nonAR, automaticallyConfigureSession: false)` — a RealityKit game view, not AR. The racers (a red panda cub per sled, built from primitives in `Reality/RacerFactory.swift`), disc sleds, track ribbon, props, ice-trail stamps, and snowfall are RealityKit entities. Simulation stays on the arcade spline; RealityKit is the renderer only. iOS 17 cannot use `RealityView` (iOS 18+), so `ARView` is the supported embed.

Sound uses an **ambient** audio session (hardware mute + other audio respected). Haptics and snowfall skip when **Reduce Motion** is on.

## License / assets

All 3D props, racers, tracks, UI, and marketing stills are original Frost Slide work. Do not ship third-party sled-game assets or names.
