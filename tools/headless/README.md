# Headless race harness

Compiles the game's real `Core/` and `Engine/` Swift sources on Linux, with tiny stand-ins for
SwiftUI, CoreMotion, `simd`, the renderer and the audio/haptics layer, and races them with
scripted players. There is no Xcode, simulator or device involved, so the game logic can be
tested and tuned in CI or a container.

It exists because the interesting questions about a racer ("can a beginner win the first course?",
"is the last course a fight?", "does driving well actually matter?") need thousands of races to
answer, and the balance numbers live in the simulation, not in the UI.

```
tools/headless/run.sh selftest          engine, progression and persistence checks
tools/headless/run.sh sweep [runs]      win / podium / par / crystal-goal rates, every course and bot
tools/headless/run.sh solo [runs]       each bot alone on each course: pace, crystals, crashes
tools/headless/run.sh rivals            raw rival pace per course (rubber band switched off)
tools/headless/run.sh avalanche [runs]  how often each bot is buried on the avalanche courses
tools/headless/run.sh standings 24 good one race, with finish times and crash counts
tools/headless/run.sh calibrate [n]     re-tune rival strength in LevelCatalog.swift, in place
tools/headless/run.sh goals             re-derive par times and crystal goals from real races
```

Needs `swiftc` 5.9 or newer on `PATH` (developed with Swift 6.0.3 for Ubuntu 24.04) and
`python3`. Output goes to `.build/headless` (git-ignored); set `HEADLESS_OUT` to change it and
`APP_DIR` to point at a different copy of the sources. The sweep splits the 24 courses over four
processes.

## The bots

| Bot | Look-ahead | Reaction | Aim noise | Turbo use | Notes |
| --- | --- | --- | --- | --- | --- |
| `idle` | none | none | none | always | never steers: shows what the course does to you |
| `novice` | 18 m | 0.50 s | 0.9 m | 35% | rarely chases crystals |
| `casual` | 26 m | 0.30 s | 0.45 m | 60% | a typical player |
| `good` | 34 m | 0.18 s | 0.2 m | 85% | a competent player |
| `expert` | 44 m | 0.08 s | 0.08 m | always | close to the ceiling |

A bot plans with a small dynamic program over (metres ahead) x (lateral position): crystals,
power-ups and pads pay out, hazards cost, and the inside of a bend pays a little for the time it
saves. It is an approximation of a human, good enough to compare *versions of the game* and to
see how difficulty moves along the course list; do not read its win rates as promises about
real players.

## What the numbers are for

* **Rival strength.** `LevelCatalog` stores each rival's `skill`. `calibrate` races the `good`
  bot on every course, compares its mean winning margin (seconds between the bot and the fastest
  rival) with the ramp in `calibrate.py: target()`, and nudges that course's skills. Near the end
  of the game one hundredth of skill can be worth half a second of margin (a rival's finishing
  burst decides the race), so the catalog stores three decimals, and the script finishes by
  measuring exactly what will ship.
* **Par time and crystal goal.** `goals` sets them from the `casual` bot's real races: par a
  quarter second faster than its mean time, the goal half a crystal below its mean. Re-run it
  (then `calibrate`) if you change speeds, the boost economy, crash costs or crystal placement.
* **Avalanche pace.** `avalanche` prints how often each bot is buried and how close the wall
  gets. Novices should occasionally be caught from mid-game on; good players almost never.
* **Balance constants** all live in `Tuning` (`Engine/GameEngine.swift`).

## Self-tests

`selftest` checks, on the real code: track banking leans into turns and eases in and out;
steering response and ice; pickups belong to the player; the ghost covers the whole run,
replays in step and stays small; the avalanche launches behind the player and buries once;
results, standings and stars are consistent and the race clock starts at zero; daily goals and
streaks; persistence, records and reset; old save files still decode; the HUD refreshes about
30 times a second and a timed boost launches the sled; and a fuzz run with wild inputs and
varying frame times never produces a non-finite or out-of-bounds racer.
