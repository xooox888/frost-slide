#!/usr/bin/env python3
"""Re-derive each course's par time and crystal goal from how a typical player actually races it.

Races the `casual` bot on every course (with the rivals, so traffic is included), then sets

    par          = the bot's mean finish time minus a quarter second, to the nearest half second
    crystal goal = the bot's mean crystal count minus half a crystal

so a typical player makes each goal about half the time, a good player almost always, and a
beginner rarely. Edits `b.parTime` and `b.crystalStar` in LevelCatalog.swift in place.

    tools/headless/run.sh goals
"""
import concurrent.futures as cf
import math
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CATALOG = os.path.join(ROOT, 'FrostSlide', 'FrostSlide', 'Core', 'LevelCatalog.swift')
OUT = os.environ.get('HEADLESS_OUT', os.path.join(ROOT, '.build', 'headless'))
BIN = os.path.join(OUT, 'headless')
RUNS = 24

LINE = re.compile(r'\w+\s+(\d+)\s+.+?\s+win\s+\d+% top3\s+\d+% place [\d.]+ time\s+([\d.]+) '
                  r'\(par\s+[\d.]+, made\s+\d+%\) crys\s+([\d.]+)/')
FUNCS = [
    'villageDash', 'marketMayhem', 'alleySprint', 'iceCaveSpiral', 'crystalGrotto', 'frozenHollow',
    'auroraNight', 'polarVeil', 'midnightRibbon', 'harborFreeze', 'driftwoodDocks', 'tideGate',
    'summitRush', 'glacierDrop', 'icefallRun', 'pineWhisper', 'timberSwitchback', 'owlHollow',
    'canyonGlow', 'prismCut', 'steamVeil', 'whiteoutPeak', 'neonSlalom', 'carnivalParade',
]


def measure():
    slices = [(0, 5), (6, 11), (12, 17), (18, 23)]

    def run(part):
        out = subprocess.run(
            [BIN, 'balance', 'casual', str(RUNS), str(part[0]), str(part[1])],
            capture_output=True, text=True, check=True,
        ).stdout
        return [LINE.match(line).groups() for line in out.splitlines() if LINE.match(line)]

    rows = {}
    with cf.ThreadPoolExecutor(len(slices)) as pool:
        for part in pool.map(run, slices):
            for course, time, crystals in part:
                rows[int(course)] = (float(time), float(crystals))
    return rows


def main():
    subprocess.run([os.path.join(HERE, 'run.sh'), 'build'], check=True)
    rows = measure()
    src = open(CATALOG).read()
    starts = {name: re.search(r'static func %s\(\) -> LevelDefinition \{' % name, src).start() for name in FUNCS}
    for course, name in sorted(enumerate(FUNCS, start=1), key=lambda item: -starts[item[1]]):
        time, crystals = rows[course]
        par = round((time - 0.25) * 2) / 2
        goal = max(18, int(math.floor(crystals - 0.5)))
        start = starts[name]
        end = src.index('return b.build()', start)
        block = src[start:end]
        par_text = ('%d' % par) if par == int(par) else ('%.1f' % par)
        block, a = re.subn(r'parTime = [\d.]+', 'parTime = ' + par_text, block)
        block, b = re.subn(r'crystalStar = \d+', 'crystalStar = %d' % goal, block)
        assert a == 1 and b == 1, name
        src = src[:start] + block + src[end:]
        print(f'{course:>2} {name:<17} casual race {time:5.2f}s, {crystals:4.1f} crystals -> par {par_text:>4}, goal {goal}')
    with open(CATALOG, 'w') as f:
        f.write(src)


if __name__ == '__main__':
    main()
