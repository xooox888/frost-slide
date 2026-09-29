#!/usr/bin/env python3
"""Re-tune rival strength in LevelCatalog.swift, in place.

Each pass races the 'good' bot against every course, compares its mean winning margin (seconds
between the bot and the fastest rival) with a target ramp, and nudges that course's rival skills
up (too easy) or down (too hard). The ramp runs from a comfortable win on course 1 to roughly a
coin flip on course 24, with a small sawtooth so each world opens a little easier than the last
one ended. Edit `target()` to change the difficulty curve.

    tools/headless/run.sh calibrate [passes]
"""
import concurrent.futures as cf
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CATALOG = os.path.join(ROOT, 'FrostSlide', 'FrostSlide', 'Core', 'LevelCatalog.swift')
OUT = os.environ.get('HEADLESS_OUT', os.path.join(ROOT, '.build', 'headless'))
BIN = os.path.join(OUT, 'headless')
RUNS = 24        # races per course per pass
GAIN = 0.03      # skill change per second of margin error
DIGITS = 3       # decimals kept in the catalog

FUNCS = [
    'villageDash', 'marketMayhem', 'alleySprint', 'iceCaveSpiral', 'crystalGrotto', 'frozenHollow',
    'auroraNight', 'polarVeil', 'midnightRibbon', 'harborFreeze', 'driftwoodDocks', 'tideGate',
    'summitRush', 'glacierDrop', 'icefallRun', 'pineWhisper', 'timberSwitchback', 'owlHollow',
    'canyonGlow', 'prismCut', 'steamVeil', 'whiteoutPeak', 'neonSlalom', 'carnivalParade',
]
SKILL = re.compile(r'(\.\w+\(skill: )([\d.]+)(, lateral: -?[\d.]+\))')


def target(course):
    """Margin (seconds) the good bot should win by on course 1...24."""
    position = (course - 1) % 3
    sawtooth = [-0.06, 0.0, 0.05][position]
    difficulty = (course - 1) / 23 + sawtooth
    return 3.0 - 3.15 * difficulty


def function_spans(src):
    spans = {}
    for name in FUNCS:
        start = re.search(r'static func %s\(\) -> LevelDefinition \{' % name, src).start()
        spans[name] = (start, src.index('return b.build()', start))
    return spans


def scale_skills(src, factors, digits):
    spans = function_spans(src)
    for name in sorted(spans, key=lambda n: -spans[n][0]):
        a, b = spans[name]
        block = SKILL.sub(
            lambda m: m.group(1) + ('%.*f' % (digits, float(m.group(2)) * factors[name])) + m.group(3),
            src[a:b],
        )
        src = src[:a] + block + src[b:]
    return src


def measure(profile='good'):
    slices = [(0, 5), (6, 11), (12, 17), (18, 23)]

    def run(part):
        out = subprocess.run(
            [BIN, 'margin', profile, str(RUNS), str(part[0]), str(part[1])],
            capture_output=True, text=True, check=True,
        ).stdout
        return [line.split() for line in out.splitlines() if line.startswith('MARGIN')]

    margins = {}
    with cf.ThreadPoolExecutor(len(slices)) as pool:
        for rows in pool.map(run, slices):
            for _, course, margin, win, _sd in rows:
                margins[int(course)] = (float(margin), float(win))
    return margins


def report(title, margins):
    print(title)
    for course, name in enumerate(FUNCS, start=1):
        margin, win = margins[course]
        print(f'  {course:>2} {name:<17} margin {margin:+.2f}s (want {target(course):+.2f}) wins {win * 100:3.0f}%')


def main():
    passes = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    for n in range(passes):
        subprocess.run([os.path.join(HERE, 'run.sh'), 'build'], check=True)
        margins = measure()
        factors, worst = {}, 0.0
        for course, name in enumerate(FUNCS, start=1):
            error = margins[course][0] - target(course)
            worst = max(worst, abs(error))
            factors[name] = 1 + GAIN * error
        report(f'pass {n + 1}: worst error {worst:.2f}s', margins)
        src = open(CATALOG).read()
        with open(CATALOG, 'w') as f:
            f.write(scale_skills(src, factors, DIGITS))
    # Measure exactly what ships. One thousandth of skill is worth about 0.05 s of margin (a
    # hundredth can be worth half a second on a course where a rival's finishing burst decides
    # the race, which is why the catalog stores three decimals).
    subprocess.run([os.path.join(HERE, 'run.sh'), 'build'], check=True)
    report('final state', measure())
    print('review the diff, then run: tools/headless/run.sh selftest')


if __name__ == '__main__':
    main()
