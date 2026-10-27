# usage: python3 -I report.py <results-dir> <name>   -> wall-time stats + per-project task time, source vs prebuilt
import csv, statistics, sys, collections, glob, os
d, name = sys.argv[1], sys.argv[2]
walls = collections.defaultdict(list)
for r in csv.reader(open(os.path.join(d, 'summary.csv'))):
    lab, mode, wall, rc = r
    if lab.startswith(name + '-') and rc == '0':
        walls[mode].append(float(wall))
print(f"== {name}: cold build wall time (s)")
for m in ('source', 'prebuilt'):
    v = walls[m]
    if v: print(f"  {m:9s} n={len(v)}  runs={v}  median={statistics.median(v):.1f}  mean={statistics.mean(v):.1f}")
if walls['source'] and walls['prebuilt']:
    s, p = statistics.median(walls['source']), statistics.median(walls['prebuilt'])
    print(f"  saved: {s-p:.1f}s  ({(s-p)/s*100:.1f}% faster, {s/p:.2f}x)")

pf = os.path.join(d, f"{name}.prebuild-seconds.txt")
if os.path.exists(pf):
    print(f"  one-time prebuild (compile + publish the libs as AARs, warm Gradle): {open(pf).read().strip()}s")

def load(label):
    tasks = []
    for l in open(os.path.join(d, label + '.times.csv')):
        p = l.strip().split(',')
        if p[0].startswith('#') or len(p) < 3: continue
        tasks.append((p[0], int(p[1]), p[2]))
    return tasks
def by_proj(tasks):
    b = collections.defaultdict(float)
    for t, ms, o in tasks: b[t.rsplit(':', 1)[0] or ':'] += ms / 1000
    return b
for m in ('source', 'prebuilt'):
    f = os.path.join(d, f"{name}-{m}-r1.times.csv")
    if not os.path.exists(f): continue
    b = by_proj(load(f"{name}-{m}-r1"))
    print(f"\n  {m} r1 summed task time per project (s):")
    for k, v in sorted(b.items(), key=lambda x: -x[1])[:9]: print(f"    {k:48s}{v:7.1f}")
