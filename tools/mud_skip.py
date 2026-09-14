"""Where a Muddy Valley run left the road, and how much of each mud stretch it drove on mud.
Usage: python3 tools/mud_skip.py levels/muddy_valley/muddy_valley_curve.tres <run.csv>...
The last run given also gets a breakdown of lateral positions and wheel surfaces in each stretch."""
import csv, math, re, sys

def curve_points(path):
    text = open(path).read()
    nums = [float(v) for v in re.search(r'"points": PackedVector3Array\(([^)]*)\)', text).group(1).split(",")]
    vecs = [tuple(nums[i:i + 3]) for i in range(0, len(nums), 3)]
    pts = [(vecs[i], vecs[i + 1], vecs[i + 2]) for i in range(0, len(vecs), 3)]  # (in, out, pos)
    samples = []
    for (a_in, a_out, a), (b_in, b_out, b) in zip(pts, pts[1:]):
        c1 = tuple(a[k] + a_out[k] for k in range(3)); c2 = tuple(b[k] + b_in[k] for k in range(3))
        for s in range(40):
            t = s / 40.0; u = 1 - t
            samples.append(tuple(u*u*u*a[k] + 3*u*u*t*c1[k] + 3*u*t*t*c2[k] + t*t*t*b[k] for k in range(3)))
    samples.append(pts[-1][2])
    dist = [0.0]
    for p, q in zip(samples, samples[1:]):
        dist.append(dist[-1] + math.dist(p, q))
    return samples, dist

def locate(samples, dist, x, z, hint):
    lo, hi = max(0, hint - 60), min(len(samples) - 1, hint + 400)
    best = min(range(lo, hi), key=lambda i: (samples[i][0] - x) ** 2 + (samples[i][2] - z) ** 2)
    p, q = samples[best], samples[min(best + 1, len(samples) - 1)]
    fx, fz = q[0] - p[0], q[2] - p[2]; n = math.hypot(fx, fz) or 1.0
    # Godot right = forward x up; with forward (fx, fz) flat, right = (-fz, fx)
    lateral = ((x - p[0]) * (-fz / n) + (z - p[2]) * (fx / n))
    return best, dist[best], lateral

MUD = [(760, 850), (980, 1050), (1300, 1500)]
HALF_ROAD, HALF_TOTAL = 4.5, 7.0
samples, dist = curve_points(sys.argv[1])
for run in sys.argv[2:]:
    rows = list(csv.DictReader(open(run)))
    hint = 0; off = []; mud_ticks = {m: [0, 0] for m in MUD}; finish_t = None; max_d = 0
    for r in rows[::6]:
        hint, d, lat = locate(samples, dist, float(r["pos_x"]), float(r["pos_z"]), hint)
        max_d = max(max_d, d)
        if finish_t is None and d >= 1498: finish_t = float(r["time"])
        for m in MUD:
            if m[0] <= d < m[1]:
                mud_ticks[m][1] += 1
                if r["fl_surface"] == "mud" or r["rl_surface"] == "mud": mud_ticks[m][0] += 1
        off.append((float(r["time"]), d, lat, r["fl_surface"], float(r["speed_kmh"])))
    print(f"\n{run.split('/')[-1]}: {float(rows[-1]['time']):.1f} s recorded, furthest {max_d:.0f} m, reached finish at {finish_t}")
    for m, (on, total) in mud_ticks.items():
        print(f"  mud {m[0]}-{m[1]} m: {on}/{total} samples with a wheel on mud ({(100*on/total if total else 0):.0f}%)")
    # Stretches off the road (beyond the shoulder edge) of at least 1 s
    spans = []; cur = None
    for t, d, lat, surf, v in off:
        if abs(lat) > HALF_TOTAL:
            if cur is None: cur = [t, t, d, d, lat, lat, v]
            cur[1] = t; cur[3] = d; cur[4] = min(cur[4], lat); cur[5] = max(cur[5], lat); cur[6] = max(cur[6], v)
        elif cur is not None:
            spans.append(cur); cur = None
    if cur: spans.append(cur)
    for s in spans:
        if s[1] - s[0] >= 1.0:
            side = "left" if s[4] < -HALF_TOTAL else "right"
            print(f"  off road {s[0]:6.1f}-{s[1]:6.1f} s, {s[2]:5.0f}-{s[3]:5.0f} m, lateral {s[4]:+.1f}..{s[5]:+.1f} m ({side}), top {s[6]:.0f} km/h")

# Lateral positions and wheel surfaces inside each mud stretch, for the last run.
rows = list(csv.DictReader(open(sys.argv[-1])))
hint = 0
for m in MUD:
    lats = []; surfaces = {}
    hint = 0
    for r in rows[::6]:
        if float(r["time"]) > 80: break
        hint, d, lat = locate(samples, dist, float(r["pos_x"]), float(r["pos_z"]), hint)
        if m[0] <= d < m[1]:
            lats.append(lat)
            for w in ("fl", "fr", "rl", "rr"):
                surfaces[r[w + "_surface"]] = surfaces.get(r[w + "_surface"], 0) + 1
    if lats:
        buckets = {}
        for lat in lats:
            b = int(math.floor(lat))
            buckets[b] = buckets.get(b, 0) + 1
        print(f"  last run in mud {m}: lateral min {min(lats):+.1f} max {max(lats):+.1f}; by metre {dict(sorted(buckets.items()))}; wheel surfaces {surfaces}")
