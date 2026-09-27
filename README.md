# Frost Slide

A native iOS downhill sled racer. You are a penguin on a glowing blue disc, carving an ice trail through six hand-authored courses — snowy town streets, a packed market, a glass-blue cave spiral, an aurora night, a frozen harbor, and a windy summit.

Built with **Swift + SwiftUI** for menus/HUD and **SceneKit** for the 3D race world. Portrait, iPhone first, iOS 17+.

## Open and run

This repository was authored on Linux, so it has not been compiled with Xcode here. The project is a complete `.xcodeproj` and will open on a Mac.

1. Install Xcode 15 or newer (iOS 17 SDK).
2. Clone this repo and open `FrostSlide/FrostSlide.xcodeproj`.
3. Select the **FrostSlide** scheme and an iPhone simulator (iPhone 15 / 16 recommended).
4. If Xcode asks for a Development Team, set your Personal Team under the FrostSlide target → Signing & Capabilities. The bundle id is `com.frostslide.FrostSlide`.
5. Press Run. The simulator should launch in portrait on the main menu.

No third-party packages. No Unity / Flutter / React Native.

## How to play

- **Steer:** drag left/right anywhere on the slope (default). Optional tilt steering lives in Settings.
- **Turbo:** hold the red **BOOST** button. Frost crystals fill the meter.
- **Peel:** if you pick up a banana, tap **PEEL** to drop it for rivals.
- **Pause:** top-right. Restart, map, and menu are all there.

Finish a course to unlock the next. Settings has **Unlock all courses** for debug.

### Stars

Every finish is at least 1 star. Extra stars come from place, crystal count, and beating the course par time:

- 1st place is worth the most
- Collect at least the course crystal target
- Beat the par clock (shown as your time on the results card)

### Power-ups

| Pickup | Effect |
| --- | --- |
| Crystal | Fills turbo |
| Rocket | Huge speed burst |
| Magnet | Pulls nearby crystals |
| Ghost | Phase through the next smash (or a few seconds) |
| Banana | Arm a peel that stuns whoever hits it |

### Hazards

Snowmen, crates, ice patches (slidey), moving carts, darting market NPCs, low bridges, stalactites, wind gusts, and harbor water (splash = last checkpoint + 3s).

## Courses

1. **Village Dash** — ochre walls, stone archways, yellow chevron ramps (closest to the reference vibe).
2. **Market Mayhem** — tighter alleys, stalls, darting NPCs.
3. **Ice Cave Spiral** — blue ice tunnel, continuous helix, stalactites.
4. **Aurora Night** — night lighting, glow pads, heavier fog.
5. **Harbor Freeze** — docks, icy planks, water on both sides.
6. **Summit Rush** — steep face, big jumps, left/right wind.

Rivals Pico (green, aggressive), Ruby (red, boost-hoarder), Violet (purple, cautious), plus Navy and Amber on later courses.

## Architecture

```
FrostSlide/
  FrostSlide.xcodeproj
  FrostSlide/
    FrostSlideApp.swift          SwiftUI app + root router
    App/AppModel.swift           Navigation, persistence, race session
    Core/                        Models, 6-level catalog, save data, audio/haptics
    Engine/                      Spline track, arcade physics, AI, collisions
    Scene/                       SceneKit world, penguin rig, props, particles
    UI/                          Menu, map, HUD, pause, results, settings
    Assets.xcassets              App icon, key art, mascot, launch color
    Resources/Sounds/            Generated WAV stingers
```

The simulation is arcade, not a full rigid-body solver: racers live in progress + lateral + air height on a generated downhill spline. SceneKit is the renderer. SwiftUI owns every 2D surface.

Progress (unlocked courses, best place / stars / time / crystals) is stored in `UserDefaults`.

## Controls and settings

| Setting | Default | Notes |
| --- | --- | --- |
| Swipe steering | On | Always available |
| Tilt steering | Off | Uses Core Motion; needs the motion usage string |
| Haptics | On | Boost, collect, crash, finish |
| Sound | On | Short WAV tones |
| Unlock all | Off | Debug |

## License / assets

All 3D props, penguins, tracks, and UI are original procedural SceneKit / SwiftUI work. Menu key art and the app icon are original generated illustrations inspired by the brief, not copied from any proprietary game. Reference screenshots were used only as visual direction.
