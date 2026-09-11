# Ridge — Product Requirements Document

**Working title:** Ridge
**Genre:** 3D physics-based off-road hill-climb driving game
**Platform:** Mobile (Android primary; iOS export considered later), offline single-player
**Engine:** Godot 4.x (Jolt physics)
**Language:** GDScript
**Timeline:** ~1 month solo build
**Target audience:** Casual/skill players who enjoy Hill Climb Racing-style physics driving

---

## 1. Vision

Ridge is a hand-built-level, physics-driven hill-climb game where the core tension is
managing momentum, fuel, and traction across varied terrain surfaces (asphalt, mud, snow,
water) using one of several distinct car archetypes. No procedural generation and no
upgrade system in v1 — replay value comes from car/level pairing, star ratings, and
genuinely satisfying vehicle physics.

**Design pillars:**
- Physics feel is the product — suspension, traction, and weight must feel tactile and
  readable, not floaty or arcadey-flat.
- Surface variety is both a mechanic and a teaching tool — the right car for the right
  terrain should be discoverable through play, not explained in text.
- Every level has a designed identity (a "this is the snow level" clarity), not generic
  procedural filler.
- Short session length — a level should be completable (or failable) in 30–90 seconds,
  making this a pick-up-and-play offline game.

---

## 2. Core Gameplay Loop

1. Player selects a level from the level-select screen.
2. Player selects a car (unlocked cars only) suited — or deliberately not suited — to
   that level's surfaces.
3. Player drives left-to-right (or along a fixed path) up/through the terrain using
   gas/brake and body-tilt controls, trying to reach the finish flag.
4. Player manages: fuel (depletes over time/distance), momentum (avoid flipping/crashing),
   and traction (varies by surface under wheels).
5. On finish: player earns 1–3 stars based on time and/or fuel remaining and/or crash count.
6. On crash/flip/fuel-out: level restarts immediately (fast retry loop, no punishing load
   screens).
7. Stars unlock the next level(s).

---

## 3. Controls

- **Gas** — right-side screen hold (or right pedal button)
- **Brake/reverse** — left-side screen hold (or left pedal button)
- **Body tilt** — accelerometer tilt OR two small on-screen tilt buttons (forward/backward
  lean), used to correct balance mid-air or on steep inclines
- Controls must be usable one-handed or two-thumb, since this is a mobile-first offline game

---

## 4. Cars (v1: 4 fixed archetypes, no upgrades)

No stat-editing/upgrade system in v1. Instead, ship 4 cars with distinct baked-in stats.
Stats are relative (tune numerically during Week 1 physics work).

| Car | Mass | Engine torque | Top speed | Suspension travel | Ground clearance | Traction bias | Best on | Weak on |
|---|---|---|---|---|---|---|---|---|
| Rally Car (starter) | Medium | Medium | Medium | Medium | Medium | Balanced | Everything (all-rounder) | Nothing excels |
| 4x4 Truck | Heavy | High | Low | High | High | Strong mud/snow grip | Mud, Snow, rocky terrain | Slow on asphalt, sluggish handling |
| Sports Car | Light | High | High | Low | Very low | Strong asphalt grip only | Asphalt/tarmac | Mud, snow, rough terrain (bottoms out) |
| Buggy (light off-roader) | Very light | Medium | Medium-high | High, bouncy | High | Good over rough terrain | Rocky/uneven terrain | Ice/snow (low mass = poor grip), water |

**Unlock order (v1):** Rally Car available from start; Truck, Sports Car, Buggy unlock via
stars earned (exact thresholds decided during level design pass, Week 2).

---

## 5. Surfaces

| Surface | Friction | Special behavior | Visual/particle feedback | Audio cue |
|---|---|---|---|---|
| Asphalt | High | Predictable, rewards speed | Tire smoke on hard braking/turns | Sharp tire screech |
| Mud | Low–medium | Wheels visually sink slightly; slows acceleration | Mud spray from wheels, mud splatter on car body | Squelchy, dampened engine note |
| Snow/Ice | Very low | Sliding, longer brake distance, easy to lose control | Snow spray, visible tire tracks left behind | Muffled, crunchy |
| Water (shallow) | Medium, with drag | Engine risk: prolonged submersion should stall/slow engine | Splash particles, ripple trail, water droplets on windshield/camera | Splash + engine sputter if stalled |

Surface type is authored per-level via a splat map or per-mesh material tag (technical
approach decided in Week 2 — see Section 8).

---

## 6. Levels (v1: 6–8 hand-built levels)

No procedural generation in v1 (explicitly deferred to a future version). Each level has a
name, a dominant surface theme, and a difficulty tier.

Proposed level list (finalize exact terrain layouts during Week 2):

1. **Rally Road** (tutorial) — asphalt only, gentle slopes, teaches gas/brake/tilt basics
2. **Muddy Valley** — mud-dominant, teaches momentum management on low traction
3. **Frozen Pass** — snow/ice-dominant, teaches braking distance and sliding control
4. **Coastal Highway** — asphalt + shallow water crossings, teaches engine-stall risk
5. **Rock Canyon** — uneven/rocky asphalt-adjacent terrain, teaches suspension articulation
6. **Sunset Ridge** — mixed asphalt + mud, moderate difficulty, first "car choice matters"
   level
7. **Avalanche Climb** — steep snow/ice, hard difficulty, tests all skills
8. **The Gauntlet** (final) — combines all 4 surfaces in one run, hardest level, real test
   of car choice + skill

**Star rating criteria (per level, tune during playtesting):**
- 1 star: finish the level
- 2 stars: finish under a time threshold OR without flipping
- 3 stars: finish under a tighter time threshold AND with fuel remaining above a threshold

---

## 7. Systems

- **Fuel system:** depletes over time and/or distance; running out = soft-fail (car
  coasts to a stop), triggers retry prompt
- **Checkpoints:** optional mid-level checkpoints on longer levels to avoid full restart
  frustration (decide per-level during design pass)
- **Crash/flip detection:** if car body rotation exceeds a threshold and stays there
  (not mid-air, not corrected), trigger a "flipped" state → auto-restart or restart prompt
- **Camera:** third-person follow camera with dynamic FOV/shake on impact, tilts slightly
  with terrain incline to enhance the "climbing" feeling
- **Progression:** simple level-unlock chain (linear), no branching in v1
- **Save data:** local-only save (stars per level, unlocked cars) — no cloud/account
  system needed since this is fully offline

---

## 8. Technical Architecture

### Engine/physics
- Godot 4.x, using `VehicleBody3D` + `VehicleWheel3D` nodes for car physics (Jolt physics
  backend)
- Per-wheel friction dynamically read from the surface the wheel is currently contacting
  (raycast or contact-monitoring against a surface-tagged collision layer, or reading a
  splat-map value under the wheel's world position)

### Terrain
- Hand-sculpted terrain meshes (built in Blender or Godot's built-in tools) per level
- Surface type authored either as:
  - (a) separate collision shapes per surface patch, each tagged with a surface-type
    metadata value, or
  - (b) a splat/weight map sampled at the wheel's terrain UV position
- Decision between (a) and (b) should be made early in Week 2 based on how much
  surface-blending fidelity is actually needed — (a) is simpler to implement and likely
  sufficient for hand-built levels with clearly zoned surfaces

### Scene structure (proposed)
```
res://
  scenes/
    cars/
      car_base.tscn        # shared VehicleBody3D rig + script
      car_rally.tscn
      car_truck.tscn
      car_sports.tscn
      car_buggy.tscn
    levels/
      level_01_rally_road.tscn
      level_02_muddy_valley.tscn
      ...
    ui/
      main_menu.tscn
      level_select.tscn
      car_select.tscn
      hud.tscn
      results_screen.tscn
  scripts/
    car_controller.gd
    surface_detector.gd
    fuel_system.gd
    checkpoint_system.gd
    crash_detector.gd
    camera_rig.gd
    save_system.gd
    level_manager.gd
  resources/
    car_stats/            # Resource files per car (mass, torque, traction, etc.)
    surface_defs/          # Resource files per surface type (friction, particle scene, sound)
  autoload/
    game_state.gd          # Singleton: current level, car, save data
```

### Data-driven design
- Car stats and surface definitions should be Godot `Resource` files (`.tres`), not
  hardcoded values, so tuning is fast and doesn't require touching scripts
- This matters a lot given the physics-tuning-heavy nature of the project — expect many
  iterations on these numbers

---

## 9. Visual & Audio Direction

- **Art style:** low-poly/stylized rather than photorealistic — faster to produce solo,
  ages well, fits mobile performance budget
- **Lighting:** distinct per-biome lighting mood (e.g. warm sunset for Sunset Ridge, flat
  overcast for Frozen Pass, golden hour for Coastal Highway) to reinforce level identity
- **Particles:** surface-specific (mud spray, snow spray, water splash, dust, tire smoke)
  — required, not optional, since surface feedback is core to readability
- **Suspension visual feedback:** wheels should visibly compress/extend with terrain,
  camera should shake proportionally to impact force
- **Audio:** engine pitch tied to RPM/throttle; surface-specific tire/road sound layered
  under engine sound; simple ambient per-biome sound bed; crash/splash/impact SFX

---

## 10. Scope: In vs. Out (v1)

**In scope (v1):**
- 4 fixed car archetypes (no upgrades)
- 6–8 hand-built levels across 4 surface types
- Fuel, crash/flip, checkpoint, star-rating systems
- Local save (stars, unlocks)
- Full 3D physics via `VehicleBody3D`
- Surface-specific visual/audio feedback
- Basic UI: main menu, level select, car select, HUD, results screen

**Explicitly out of scope for v1 (deferred to future versions):**
- Procedural/endless terrain generation
- Car upgrade/progression system (better tires, suspension, engine)
- Cloud save / accounts / leaderboards
- Multiplayer or async ghost-racing
- iOS-specific polish (Android is primary target for v1)
- Monetization (ads/IAP) — not addressed in this PRD, decide separately if desired

---

## 11. Development Roadmap (4 weeks)

### Week 1 — Core vehicle feel
- Set up `VehicleBody3D` rig on one test car on a gray-box test hill
- Tune suspension (stiffness, damping, travel), wheel friction, engine torque/gearing
  until base handling feels good
- Clone/tune base rig into the 4 car archetypes using data-driven `Resource` stat files
- **Milestone:** one car feels good on a flat test track; all 4 cars are distinguishable
  from each other by feel alone

### Week 2 — Terrain + surface system
- Decide and implement surface-tagging approach (separate collision zones vs. splat map)
- Build 3–4 of the 8 levels (gray-box terrain first, then basic materials)
- Implement per-wheel surface detection feeding into friction values
- Build car-select and level-select screens (functional, not polished)
- **Milestone:** can drive a car through at least 3 levels with correctly varying traction
  per surface

### Week 3 — Systems + game feel
- Implement fuel system, checkpoints, crash/flip detection and restart flow
- Build remaining levels (targeting all 6–8 complete in gray-box/basic form)
- Add surface-specific particle effects and suspension visual response
- Camera work: follow cam, impact shake, incline tilt
- **Milestone:** all levels playable start-to-finish with full system logic (fuel, crash,
  stars) working

### Week 4 — Polish + content pass
- Lighting/environment art pass per biome
- Sound design: engine RPM-linked pitch, surface-specific tire sounds, ambient beds, SFX
- UI polish: main menu, results screen, star display, unlock feedback
- Playtesting pass — tune difficulty curve, star thresholds, fuel balance
- Buffer time for physics re-tuning based on playtesting feedback (expect this to be
  necessary — vehicle feel rarely survives first contact with real playtesting unchanged)
- **Milestone:** feature-complete, polished prototype ready to build/export as an APK

---

## 12. Open Questions / Risks

- **Vehicle physics tuning risk:** `VehicleBody3D` handling can be fiddly to get feeling
  right (this is the biggest known risk in the whole project — budget real time for it in
  Week 1, don't rush past it).
- **Surface-tagging approach:** needs a firm decision early in Week 2 to avoid rework —
  recommend starting with the simpler zoned-collision approach and only moving to a splat
  map if blending fidelity is clearly needed.
- **Content volume:** 6–8 fully hand-built, polished levels in the time available is
  achievable but leaves little slack — if Week 1 physics tuning runs long, consider
  cutting to 6 levels rather than compromising on physics feel.
- **Performance on target devices:** particle-heavy surfaces (mud/snow/water) + real-time
  lighting need profiling on actual low/mid-range Android hardware, not just desktop
  testing, before Week 4 polish locks in.

---

## 13. Handoff Notes for Claude Code

- Preference: readable code over concise/clever code
- Prefer data-driven design (Resource files for car stats and surface definitions) over
  hardcoded values, to support rapid iteration during physics tuning
- Build and validate incrementally — get one car feeling right on one test hill before
  cloning into other archetypes or building additional levels
- Bench/test each system in isolation where possible (e.g. test fuel depletion logic
  separately from full level integration) before wiring everything together
