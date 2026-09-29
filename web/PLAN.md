# Frost Slide on three.js: rebuild plan

This plan rebuilds Frost Slide as a web game (TypeScript + three.js) and ships it to the App
Store inside a native iOS shell (Capacitor). The Swift app in `FrostSlide/` stays untouched until
the web build has been played on real iPhones; then it can be retired.

Status marks: `[x]` done and verified in this repo, `[~]` done but only verifiable on a Mac or an
iPhone, `[ ]` not done.

## 1. Why this shape

| Question | Decision | Why |
| --- | --- | --- |
| Engine | Port the Swift engine to TypeScript line by line | The race logic is pure maths. A faithful port keeps the 24 calibrated courses, rival skills, par times and star rules exactly as tuned. |
| 3D | three.js (WebGL 2) | Everything in the game is built from primitives (spheres, boxes, cylinders, a track ribbon), which three.js has directly. WebGL 2 runs in WKWebView on iOS 15+. |
| UI | Preact + signals, plain CSS | React-style components at 4 KB. Menus, HUD and results are DOM, so text, layout and accessibility work like any web page. |
| iOS shell | Capacitor 8 with Swift Package Manager | Wraps the web build in a real Xcode project. Official and community plugins cover haptics, storage, AdMob and StoreKit. SPM means no CocoaPods or Ruby on the Mac. |
| Build | Vite, TypeScript (strict), ESLint, Vitest, Playwright | Fast builds, and the engine is testable in Node without a browser. |

What carries over unchanged: the game design, all 24 courses, rival calibration, star rules,
daily challenge, ghosts, sled skins, save format, sounds and the painted menu art.
What is rebuilt: every SwiftUI screen (as Preact) and every RealityKit scene (as three.js).

## 2. Architecture

```
web/
  src/core/       Pure game data and rules: maths, models, course catalog, progression, saves
  src/engine/     Race simulation: track path, racers, GameEngine + Tuning (no DOM, no three.js)
  src/render/     three.js: textures, meshes, world builder, racer model, effects, camera
  src/ui/         Preact screens: menu, course map, HUD, pause, results, settings
  src/app/        AppModel: navigation and state (signals), game loop, input
  src/platform/   Audio, haptics, storage, lifecycle, tilt, ads, purchases, analytics
                  (browser fallbacks + Capacitor plugins on iOS)
  tests/          Vitest: engine self-tests, catalog golden test, bots and parity sweeps
  e2e/            Playwright: boots the real app in Chromium, plays a race, screenshots
  ios/            Capacitor iOS project (Xcode, SPM)
```

Rules that keep it maintainable:

* `core/` and `engine/` never import three.js or touch the DOM. They run in Node for tests.
* The engine reports sounds and haptics through a small `EngineFx` interface, and the renderer
  reads engine state after each tick. Nothing in the engine knows how it is drawn.
* Every balance constant stays in `Tuning` (engine) so tuning never touches other code.

## 3. Phases

### Phase 0: plan and scaffold
- [x] This plan
- [x] Vite + TypeScript + three.js + Preact project in `web/`, strict type-checking, ESLint, Vitest, Playwright

### Phase 1: core logic (port of `Core/`)
- [x] Maths helpers and Float32-faithful course builder (`Math.fround` where Swift's `Float`
  arithmetic decides which props exist)
- [x] Models, star rules, progression (worlds, skins, daily challenge with the same UTC hash)
- [x] Course catalog: all 24 courses, palettes and rivals, with the same stable ids
- [x] Save data with the same JSON shape as the Swift app, including old-save decoding

### Phase 2: engine (port of `Engine/`)
- [x] Track path (sampling, banking, curvature), racers, collisions, pickups, pads, AI,
  rubber band, avalanche, ghosts, combo and near misses, shortcuts, results

### Phase 3: prove the port
- [x] Golden test: the TypeScript catalog equals a JSON dump of the Swift catalog
- [x] The Swift headless self-tests ported to Vitest
- [x] The scripted bots ported; bot sweeps on every course compared with the Swift harness

### Phase 4: renderer (port of `Reality/`)
- [x] Sky and track textures drawn on canvases, track ribbon, snow banks, fog, lights
- [x] Every prop kind, the red panda racer, the ghost, peels, the avalanche cloud
- [x] Snowfall, snow spray, ice trail, landing puffs, camera shake (off with Reduce Motion)
- [x] Performance: shared geometries and materials, static scenery merged into few draw calls,
  capped pixel ratio, adaptive resolution

### Phase 5: UI and input (port of `UI/` and `App/`)
- [x] Main menu, course map with track sketches, HUD, pause, results with star reveal and
  confetti, settings
- [x] Swipe steering with the sensitivity setting, BOOST (hold), PEEL, pause; keyboard on desktop;
  tilt steering through device orientation
- [x] Pauses on interruption (tab hidden, app backgrounded)

### Phase 6: platform services
- [x] Web Audio sound effects (iOS unlock on first touch, ambient audio session)
- [~] Haptics (Capacitor Haptics on iOS, vibration where browsers allow)
- [~] Saves in Capacitor Preferences on iOS (not WebView storage, which iOS may clear), with a
  localStorage fallback
- [~] AdMob banners, interstitials and the rewarded refill (`@capacitor-community/admob`),
  with the tracking prompt; test IDs until production IDs are pasted in
- [~] Remove Ads in-app purchase (`@capgo/native-purchases`, StoreKit 2), restore purchases
- [x] Anonymous stats (`@telemetrydeck/sdk`), off until an App ID is set, opt-out in Settings

### Phase 7: iOS app
- [~] Capacitor iOS project (SPM), bundle id `com.frostslide.FrostSlide`, portrait, full screen
  (compiles in CI with Xcode 26.3; not yet run on a device)
- [~] Info.plist (AdMob app id, tracking text, SKAdNetwork ids, motion text), privacy manifest
- [~] App icon and launch screen

### Phase 8: verification, CI, docs
- [x] Playwright plays a real race in Chromium and takes screenshots of every screen on a small
  and a large iPhone viewport
- [x] GitHub Actions: lint, type-check, unit tests, build and end-to-end tests on every push
- [x] GitHub Actions: iOS build job on a macOS runner (unsigned compile check), on native
  changes and by hand
- [x] README for the web app

### Phase 9: ship (needs a Mac and an Apple Developer account)
- [ ] `npm run ios` on a Mac, set the signing team, run on a real iPhone
- [ ] Play every world; check steering feel, frame rate on the oldest supported phone, audio
- [ ] Create the Remove Ads product in App Store Connect; paste AdMob and TelemetryDeck IDs
- [ ] Regenerate the painted art with the red panda (icon, menu hero, thumbnails, screenshots)
- [ ] Archive, upload to TestFlight, then submit

## 4. How the port is proven

1. **Catalog golden test.** A Swift tool dumps the real `LevelCatalog` to JSON; a Vitest test
   builds every course in TypeScript and compares kinds, positions, sizes, ids, curves, widths,
   rivals and palettes. Decorations that Swift placed with an unseeded random generator
   (building offsets, pine sizes) are seeded in TypeScript so every launch looks the same;
   they have no collision radius, so gameplay is unaffected, and the test checks their count
   and order but not those random values.
2. **Behaviour tests.** The Swift harness's self-tests (banking, steering, ice, pickups, ghosts,
   avalanche, stars, daily goals, saves, HUD rate, a fuzz run) are ported to Vitest.
3. **Race parity.** Swift uses 32-bit floats and JavaScript 64-bit, so the port rounds with
   `Math.fround` wherever Swift's rounding decides a discrete outcome (the frame clock, the
   countdown, the bots' timers). Result: scripted races on all 24 courses match a Swift trace
   frame by frame for at least 8 seconds, 15 of 24 to the finish, and bot sweeps on every
   course match the Swift harness's win rates within about a point and its mean times within
   0.1 s.
4. **The renderer.** A course viewer (`viewer.html`) and the end-to-end tests draw every world;
   draw calls and triangles are measured per frame (25 to 55 calls, about 100k to 140k
   triangles including the shadow pass).

## 5. Getting it onto the App Store

1. The web build (`npm run build`) goes into the iOS project with `npx cap sync ios`.
2. On a Mac with Xcode: `npm run ios` opens the project; set the signing team; run.
3. App Store review points for web-based games:
   * **Guideline 4.2 (minimum functionality):** the app must feel like an app, not a website.
     It works fully offline, runs full screen in portrait with no browser UI, uses native
     haptics, saves natively, and pauses with the app lifecycle.
   * **In-app purchase (3.1.1):** Remove Ads uses Apple's StoreKit through the plugin. No web
     payments.
   * **Privacy:** the privacy manifest and App Privacy answers cover saves (UserDefaults),
     analytics (if enabled) and AdMob.
4. Upload with Product > Archive > Distribute App, test on TestFlight, then submit.

## 6. Risks and how they are handled

| Risk | Handling |
| --- | --- |
| Frame rate in WKWebView on older iPhones | Merged static scenery, shared materials, pixel ratio capped at 2, adaptive resolution that drops toward 1x when frames run long, cheap shadows. Needs measuring on a real device. |
| iOS clears WebView storage under pressure | Saves go through Capacitor Preferences (UserDefaults) on iOS. |
| Web Audio is silent until a touch | Audio unlocks on the first tap; the menu always needs a tap before a race anyway. |
| Silent switch and other apps' audio | `navigator.audioSession.type = "ambient"` where supported (iOS 17+), matching the Swift app. |
| Tilt steering permission | Asked only when the player turns tilt on (a tap), as iOS requires. |
| Plugins can't be tested here | They are thin and isolated in `src/platform/`, every call fails soft, and the browser build runs without them. |
| Float32 vs Float64 drift | `Math.fround` where it decides outcomes; traces and sweeps prove the rest. |
| Swift renderer bugs carried over | Found and fixed while porting: crystals were placed under the course, moving bridges didn't move, props lost their height above the snow, aurora and wind planes faced away from the camera, harbour water covered half the course. |
| Players lose their Swift-app progress | The iOS shell copies the old save and the Remove Ads flag into the web app's storage on first launch. |

## 7. What cannot be verified in this environment

This repository was rebuilt in a Linux container without Xcode or an iPhone. Everything in
`core/`, `engine/`, `render/` and `ui/` is built, type-checked, unit-tested and exercised in a
real browser (Chromium with software WebGL) by the end-to-end tests. The native side (the
Capacitor iOS project, AdMob, StoreKit, haptics, preferences, the save migration, the App Store
build) is written against the plugins' published APIs. It compiles (the iOS workflow builds it
unsigned for the simulator with Xcode 26.3), but it has not run: the first `npm run ios` on a Mac
with an iPhone is its first real test. Frame rate on phones has not been measured, and the
painted art still shows the old penguin mascot.

Status marks above: `[x]` done and verified here, `[~]` written but only verifiable on a Mac or
an iPhone, `[ ]` not done.
