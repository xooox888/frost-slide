#!/bin/bash
# Headless race harness. Compiles the real Core/ and Engine/ sources against small stand-ins for
# the Apple-only frameworks, so the game logic can be tested and balanced on Linux, in CI or
# in a container, with no Xcode, simulator or device.
#
#   tools/headless/run.sh build             compile everything into .build/headless
#   tools/headless/run.sh selftest          engine, progression and persistence checks
#   tools/headless/run.sh sweep [runs]      win / par / crystal rates for every course and bot
#   tools/headless/run.sh solo [runs]       each bot alone on each course (pace, crystals, crashes)
#   tools/headless/run.sh rivals            raw rival pace per course (rubber band switched off)
#   tools/headless/run.sh avalanche [runs]  how often each bot is buried on the avalanche courses
#   tools/headless/run.sh standings <course 1-24> <bot>   one race with times and crash counts
#   tools/headless/run.sh calibrate [n]     re-tune rival strength in LevelCatalog.swift
#   tools/headless/run.sh goals             re-derive par times and crystal goals from real races
#
# Needs swiftc 5.9+ on PATH (tested with Swift 6.0.3 for Linux) and python3 for sweep/calibrate.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
APP="${APP_DIR:-$ROOT/FrostSlide/FrostSlide}"
OUT="${HEADLESS_OUT:-$ROOT/.build/headless}"
BIN="$OUT/headless"

build() {
  mkdir -p "$OUT"
  for m in simd SwiftUI CoreMotion; do
    swiftc -emit-module -emit-library -module-name "$m" -parse-as-library -O "$HERE/stubs/$m"/*.swift \
      -emit-module-path "$OUT/$m.swiftmodule" -o "$OUT/lib$m.so"
  done
  local sources=()
  for f in Core/GameModels.swift Core/LevelCatalog.swift Core/Progression.swift Core/GamePersistence.swift \
           Engine/GameEngine.swift Engine/RacerSimulation.swift Engine/TrackPath.swift; do
    sources+=("$APP/$f")
  done
  swiftc -swift-version 5 -O -I "$OUT" -L "$OUT" -lsimd -lSwiftUI -lCoreMotion \
    -Xlinker -rpath -Xlinker "$OUT" -module-name FrostHeadless \
    "${sources[@]}" "$HERE"/Sources/*.swift -o "$BIN"
}

# The rubber band throttles rivals that lead the player, which hides their real pace. This builds
# a copy of the sources with the band switched off (by editing Tuning in the copy only).
build_without_band() {
  local copy="$OUT/no-band-src"
  rm -rf "$copy"
  cp -R "$APP" "$copy"
  sed -i.bak -e 's/static let bandSlow: Float = [0-9.]*/static let bandSlow: Float = 0/' \
             -e 's/static let bandCatchUp: Float = [0-9.]*/static let bandCatchUp: Float = 0/' "$copy/Engine/GameEngine.swift"
  APP_DIR="$copy" HEADLESS_OUT="$OUT/no-band" "$0" build
}

# Runs `headless <args> <first> <last>` for four slices of the 24 courses in parallel.
parallel_courses() {
  local tmp; tmp="$(mktemp -d)"
  local i=0
  for range in "0 5" "6 11" "12 17" "18 23"; do
    "$BIN" "$@" $range > "$tmp/$i.txt" &
    i=$((i + 1))
  done
  wait
  cat "$tmp"/*.txt
  rm -rf "$tmp"
}

cmd="${1:-help}"
shift || true
case "$cmd" in
  build) build ;;
  selftest) build; "$BIN" selftest ;;
  sweep)
    build
    parallel_courses balance all "${1:-12}" | sort -k1,1 -s > "$OUT/sweep.txt"
    python3 "$HERE/summary.py" "$OUT/sweep.txt" ;;
  solo) build; parallel_courses solo "${1:-6}" | sort ;;
  rivals) build_without_band; "$OUT/no-band/headless" rivals ;;
  avalanche) build; "$BIN" avalanche "${1:-12}" ;;
  standings) build; "$BIN" standings "$(( $1 - 1 ))" "$2" ;;
  calibrate) python3 "$HERE/calibrate.py" "${1:-5}" ;;
  goals) python3 "$HERE/goals.py" ;;
  help|*) sed -n '2,18p' "$0" ;;
esac
