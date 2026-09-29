import re, sys, collections
BOTS=['idle','novice','casual','good','expert']
def load(path):
    rows=collections.defaultdict(dict)
    for line in open(path):
        m=re.match(r'(\w+)\s+(\d+)\s+(.+?)\s+win\s+(\d+)% top3\s+(\d+)% place ([\d.]+) time\s+([\d.]+) \(par\s+(\d+), made\s+(\d+)%\) crys\s+([\d.]+)/(\d+) \(star\s+(\d+):\s+(\d+)%\) crashes ([\d.]+) stars ([\d.]+) combo ([\d.]+) dnf (\d+)',line)
        if not m: continue
        g=m.groups()
        rows[int(g[1])][g[0]]=dict(name=g[2],win=int(g[3]),top3=int(g[4]),place=float(g[5]),time=float(g[6]),par=int(g[7]),made=int(g[8]),crys=float(g[9]),tot=int(g[10]),cstar=int(g[11]),cmade=int(g[12]),crash=float(g[13]),stars=float(g[14]),dnf=int(g[16]))
    return rows
def show(path, bots=BOTS):
    rows=load(path)
    bots=[b for b in bots if any(b in r for r in rows.values())]
    print(f"{'#':>2} {'course':<17} " + " ".join(f"{b:>12}" for b in bots) + "   | par/crystal-star made (casual,good,expert)")
    for i in sorted(rows):
        r=rows[i]
        left=" ".join((f"{r[b]['win']:>4}% ({r[b]['top3']:>3}%)" if b in r else ' '*12) for b in bots)
        right=" ".join((f"{r[b]['made']:>3}/{r[b]['cmade']:>3}" if b in r else '   -   ') for b in ['casual','good','expert'])
        n=list(r.values())[0]['name']
        print(f"{i:>2} {n:<17} {left}   | {right}")
    print()
    print("mean over courses -> " + "  ".join(f"{b}: win {sum(r[b]['win'] for r in rows.values() if b in r)/len(rows):.0f}% top3 {sum(r[b]['top3'] for r in rows.values() if b in r)/len(rows):.0f}% crashes {sum(r[b]['crash'] for r in rows.values() if b in r)/len(rows):.1f} crystals {sum(r[b]['crys'] for r in rows.values() if b in r)/len(rows):.1f}" for b in bots))
if __name__=='__main__':
    show(sys.argv[1], sys.argv[2].split(',') if len(sys.argv)>2 else BOTS)
