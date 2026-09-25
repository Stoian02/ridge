# M6W on the phone: waves measured on the Xiaomi 13 (2026-09-25)

Measured by Claude after the owner approved the wake and splash work on the
desktop. Branch `m6-water-waves` at `135c33f` plus the phone launcher below,
built and installed fresh. Not merged, not pushed.

## How to repeat it

The wave playcheck needed a phone trigger: Android drops scene arguments, so
`ui/main_menu.gd` now has the same one-shot flag the other probes use.

```sh
tools/android.sh build && tools/android.sh install
adb shell run-as com.ridge.game touch files/wave_playcheck
adb shell monkey -p com.ridge.game -c android.intent.category.LAUNCHER 1
adb logcat -v time -s godot:V
```

It drives the real pause-menu callbacks through Off → Car waves → Full on the
Test Ground with the 4x4, 600 physics ticks and ~300 rendered frames per mode.

## Results, two runs

Total water CPU per rendered frame, p95, against the owner's approved ceiling of
**4 ms p95 and 5 ms p99**:

| Mode | Run 1 | Run 2 | Frame p95 | Worst frame | FPS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Off | 0.683 ms | 0.677 ms | 17.4 ms | 22.0 ms | 60.1 |
| Car waves | 1.941 ms | 1.889 ms | 17.7 ms | 18.6 ms | 60.2 |
| **Full** | **4.633 ms** | **4.560 ms** | 18.1–18.3 ms | 23.0 ms | 60.1 |

Wave preparation: **31.2 ms**, far inside the 0.25 s allowance — the baked
assets from the earlier review follow-up hold up on the device. Draw peaks
73–75 and primitive peaks 21,935 (Off) / 45,764 (waves), all well inside the
150 / 300k budgets. 60 fps held in every mode.

**Car waves passes the ceiling. Full fails it**, by about 15% on p95, with its
worst frame at 23 ms.

## The finding: ambient waves are free on desktop and expensive on the phone

The desktop playcheck recorded in `m6w-bow-refinement-2026-09-24.md` measured
Car waves at 1.767 ms and Full at **1.791 ms** per frame — ambient costing
essentially nothing. On the phone the same two modes are 1.9 ms and **4.6 ms**.
Ambient adds about **+2.7 ms per frame there and +0.02 ms on the desktop**.

This is not caused by the wake/splash work: those changes alter packet placement
and the bow's amplitude, and they are present in both the Car waves and Full
numbers above. The gap is specific to the ambient component and to the device.

**Hypothesis, not a conclusion.** With only car waves, most of the water is
undisturbed, so per-vertex evaluation early-outs in the packet loop almost
everywhere. Ambient makes *every* evaluated vertex do real work — two sine and
cosine pairs plus gradients — and the drawn-triangle sampler evaluates up to
three vertices per query, 13 queries per tick, two ticks per frame. Cheap
transcendental maths on a desktop CPU is not cheap in GDScript on a phone. The
next step is to measure `evaluated_vertices` per frame on the device and confirm
that before optimising anything.

If it holds, the levers are caching vertex evaluations across the two physics
ticks that share a rendered frame, or evaluating the smooth ambient term more
cheaply than per-vertex — neither of which requires cutting the ambient waves
the owner likes.

## What this does not establish

Test Ground only, one device, two runs, a placed 4x4 rather than a full drive.
It measures total water CPU and frame pacing, not GPU time, memory or thermal
behaviour, and it is not the complete Task 4 gate. The M6A flooded-and-stalled
hitch remains open and was not exercised here. No merge or push.
