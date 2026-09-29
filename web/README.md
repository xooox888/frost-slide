# Frost Slide on three.js

The whole game rebuilt as a web app (TypeScript, three.js, Preact) that ships to the App Store
inside a native iOS shell (Capacitor 8). Same 24 courses, rivals, star rules, daily challenge,
ghosts, skins, save file, sounds and ads as the Swift app in `../FrostSlide`, which it replaces
as version 2.0.0 under the same bundle id. The plan and its status are in [PLAN.md](PLAN.md).

## Run it

Node 22.12 or newer.

```sh
cd web
npm install
npm run dev          # http://localhost:5173
```

- Play in a desktop browser with the keyboard (arrows or A/D steer, Space or Up boosts, B drops
  a peel, Esc pauses) or open the dev server on a phone (`npm run dev -- --host`) and swipe.
- `?autopilot=expert&speed=4` in the URL lets a scripted bot drive (bots: idle, novice, casual,
  good, expert; speed runs up to 8 engine ticks per frame).
- `http://localhost:5173/viewer.html?course=12&at=20` is the course viewer: a bot races a course
  and the page shows draw calls and triangles. `pause` stops after fast-forwarding `at` seconds,
  `reduce` simulates Reduce Motion. It is a development page, not part of the app build.

## Check it

| Command | What it does |
| --- | --- |
| `npm run check` | Lint, type-check and unit tests |
| `npm test` | Vitest: engine self-tests, catalog golden test, race parity with Swift |
| `npm run e2e` | Playwright: builds the app, boots it in Chromium on a small and a large iPhone viewport, plays a race, screenshots every screen into `test-results/` |
| `npm run sweep` | Bot sweeps over all 24 courses, in the same format as the Swift harness's `balance` |
| `npm run format` | Prettier |

CI runs all of it on every push that touches `web/` (`.github/workflows/web.yml`).

### How the port is proven

The Swift engine uses 32-bit floats; this port rounds with `Math.fround` wherever Swift's
rounding decides a discrete outcome, so the two agree closely:

- **Catalog:** every course built in TypeScript equals a JSON dump of the Swift catalog
  (`tests/fixtures/swift-catalog.json`) at float32 precision.
- **Races:** scripted races on all 24 courses match a Swift trace frame by frame for at least
  8 seconds, 15 of 24 to the finish (`tests/fixtures/swift-trace-61fps.txt`).
- **Balance:** bot sweeps match the Swift harness's win rates within about a point, mean times
  within 0.1 s.

The Swift side of these comparisons is `../tools/headless` (`run.sh catalog`, `run.sh trace`),
which compiles the real Swift engine on Linux.

## Ship it to the App Store

You need a Mac with Xcode 16 or newer and an Apple Developer account.

1. `npm install`, then `npm run ios`. This builds the web app, copies it into `ios/` and opens the
   Xcode project. Xcode resolves the Swift packages (Capacitor, Google Mobile Ads, the plugins)
   the first time.
2. In Xcode, select the **App** target → Signing & Capabilities → your team. Run on an iPhone.
3. Before release:
   - **AdMob:** create the iOS app and its three ad units, then set `useTestAds: false` and paste
     the unit ids in `src/platform/config.ts`, and put the app id in `ios/App/App/Info.plist`
     (`GADApplicationIdentifier`). Configure the EEA consent message in AdMob (Privacy & messaging).
   - **Remove Ads:** create the non-consumable `com.frostslide.FrostSlide.removeads` in App Store
     Connect.
   - **Stats (optional):** paste a TelemetryDeck App ID in `src/platform/config.ts`.
   - **Privacy policy:** replace `https://example.com/frost-slide-privacy` in
     `src/platform/config.ts` and App Store Connect.
4. After any web change: `npm run cap:sync` (build + copy), then build in Xcode.
5. Product → Archive → Distribute App → App Store Connect. Test on TestFlight, then submit.

It runs on iPhones with iOS 16 or newer (the Swift app needed iOS 17).

The version is 2.0.0 (build 1), so it installs as an update over the Swift app's 1.0.0. On first
launch the native shell copies the Swift app's save and Remove Ads flag into the storage the web
app reads (`ios/App/App/AppDelegate.swift`), so players keep their progress.

`npm run ios` works only on a Mac. On Linux, `npx cap sync ios` still updates the project. The
manual **iOS build** workflow (`.github/workflows/ios.yml`) compiles it unsigned on a macOS
runner.

`npm run ios:assets` regenerates the app icon and launch image from the painted art.

### App Store review notes

- **Minimum functionality (4.2):** it runs fully offline, full screen in portrait, with native
  haptics, native storage, StoreKit purchases, and pauses with the app lifecycle.
- **Purchases (3.1.1):** Remove Ads goes through StoreKit 2; there are no web payments.
- **Privacy:** `ios/App/App/PrivacyInfo.xcprivacy` declares UserDefaults (saves) and the analytics
  data types. Answer App Privacy the same way as for the Swift app.

## Layout

```
src/core/       Game data and rules: maths, models, course catalog, progression, saves
src/engine/     Race simulation: track path, racers, GameEngine and Tuning (no DOM, no three.js)
src/render/     three.js: textures, props, red panda, world builder, effects, RaceRenderer
src/ui/         Preact screens: menu, course map, race HUD, pause, results, settings
src/app/        AppModel (navigation and state as signals), game loop, sound/haptic bridge
src/platform/   Audio, haptics, storage, tilt, ads, purchases, stats: browser versions and
                Capacitor plugins on iOS
src/dev/        Bots, autopilot, course viewer
tests/          Vitest suites and the Swift fixtures
e2e/            Playwright tests
ios/            The Capacitor iOS project (Xcode, Swift Package Manager)
scripts/        Sweep, traces, catalog snapshot, iOS asset generation
```

`core/` and `engine/` never touch the DOM or three.js, so the engine runs in Node for tests. The
engine reports sounds and haptics through `EngineFx`, and the renderer reads engine state after
every tick; nothing in the engine knows how it is drawn. Every balance number lives in `Tuning`.

## Not verified here

This rebuild was written in a Linux container without a Mac or an iPhone. The game, renderer
and UI are type-checked, unit-tested and played end to end in Chromium (with software WebGL).
The native side (the Xcode project, AdMob, StoreKit, haptics, Preferences, the save migration)
follows the plugins' published APIs but has not been compiled or run: the first `npm run ios`
on a Mac is its first real test. Frame rate on phones has not been measured, and the painted art
(icon, menu hero, thumbnails, launch badge) still shows the old penguin mascot.
