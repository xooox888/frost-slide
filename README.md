# Frost Slide

A native iOS downhill sled racer. You are a penguin on a glowing cyan disc, carving an ice trail through six original courses.

Built with **Swift + SwiftUI** for menus, HUD, results, and settings, and **RealityKit** for all 3D gameplay (Entity / Component, `ARView` in non-AR game mode embedded in SwiftUI). No SceneKit. Portrait, iPhone first, iOS 17+. Bundle id: **`com.frostslide.FrostSlide`**. Version **1.0.0** (build 1).

Original Frost Slide art and UI only — not Sled Surfers (or any other game) assets or branding.

## Open and run

1. Install Xcode 15 or newer (iOS 17 SDK). Xcode 16+ recommended so Swift Package Manager can resolve Google Mobile Ads.
2. Open `FrostSlide/FrostSlide.xcodeproj`.
3. Let Xcode resolve **GoogleMobileAds** from  
   `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`.
4. Select the **FrostSlide** scheme and an iPhone simulator.
5. Set your Personal Team under Signing & Capabilities if asked.
6. Run. Portrait. First launch may prompt App Tracking Transparency (decline is fine; ads still try to fill).

If SPM cannot resolve, File → Add Package Dependencies and paste the same GitHub URL. Product name: `GoogleMobileAds`. CocoaPods is not required.

## How to play

- **Steer:** drag left/right. Optional tilt in Settings. Steering is snappy; landings kill slide.
- **Turbo:** hold **BOOST**. Crystals refill the meter. Near-misses and combo chains add a turbo crumb.
- **Near miss / combo:** skim a hazard or chain crystals. HUD shows **xN**. The chain dies if you wait too long.
- **Ghost:** a translucent copy of your best run on that course (Settings toggle).
- **Flares:** night / blizzard pickups that punch a hole in the dark.
- **Shortcuts:** cyan gates skip a bite of track. **Avalanche** walls chase you on later courses — stay ahead.
- **Rewarded refill (optional):** if turbo is low, tap **REFILL** once per race to watch a video. Never forced.
- **Peel:** pick up a banana, tap **PEEL** to slow rivals.
- Finish a course to unlock the next. Stars unlock sled skins in Settings.
- **Daily Challenge** picks one unlocked course from the UTC date.

Unlock-all exists only in **DEBUG** builds. Release / TestFlight / App Store binaries ignore it.

### Stars

1 star for finishing. Extra stars from place, crystal target, and par time.

### Courses (24, 8 worlds)

Early worlds are wide and forgiving. Later worlds tighten the lane, add moving bridges, shortcut gates, and avalanche chases. 3–5 AI rivals each. Rubber-band keeps packs readable without stealing the win.

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
- In-app purchases: none in 1.0.0
- Made for Kids: **no** (ads + ATT). Do not check Made for Kids while using AdMob

## Shipping checklist

1. Enroll in the [Apple Developer Program](https://developer.apple.com).
2. App Store Connect → New App → iOS, name **Frost Slide**, bundle id **`com.frostslide.FrostSlide`**, SKU of your choice.
3. Replace AdMob test IDs (see above) and the privacy-policy URL.
4. Archive a **Release** build (Product → Archive) and upload with Organizer / Transporter.
5. Screenshots: use `Marketing/screenshots/` as a starting set, then capture live Simulator stills of Village Dash, Ice Cave, and Aurora Night on a 6.7" iPhone.
6. Fill Privacy Nutrition Labels (UserDefaults for saves; tracking only if the player allows ATT for ads).
7. Export compliance: **ITSAppUsesNonExemptEncryption** is already `false` (HTTPS only).
8. Submit for TestFlight, then App Store review.

## Marketing visuals

Original stills live in [`Marketing/screenshots/`](Marketing/screenshots/) (menu hero, brand badge, Village Dash, Ice Cave, Aurora Night). They are Frost Slide–branded (navy + electric cyan, ice-crystal gates), not live Simulator captures. Capture those on a Mac before submission.

## Architecture

```
FrostSlide/FrostSlide/
  FrostSlideApp.swift     App + ATT/AdMob start
  Ads/                    AdConfig, AdManager, BannerAdView
  App/                    Navigation + persistence
  Core/                   Levels, save data, audio/haptics
  Engine/                 Arcade spline sim (progress + lateral + air)
  Core/Progression.swift  Worlds, sled skins, daily challenge, ghost takes
  Reality/                RealityKit world (WorldController, factories, meshes)
  UI/                     Menu, map, HUD, results, settings
  PrivacyInfo.xcprivacy   UserDefaults reason CA92.1
  Info.plist              Display name, ATT, AdMob app id, SKAdNetwork
```

The race viewport is `ARView(cameraMode: .nonAR, automaticallyConfigureSession: false)` — a RealityKit game view, not AR. Penguin, disc sled, track ribbon, props, ice-trail stamps, and snowfall are RealityKit entities. Simulation stays on the arcade spline; RealityKit is the renderer only. iOS 17 cannot use `RealityView` (iOS 18+), so `ARView` is the supported embed.

Sound uses an **ambient** audio session (hardware mute + other audio respected). Haptics and snowfall skip when **Reduce Motion** is on.

## License / assets

All 3D props, penguins, tracks, UI, and marketing stills are original Frost Slide work. Do not ship third-party sled-game assets or names.
