# Follow-up: waves and vehicle-displaced water

Owner request, 2026-09-23: waves and water reacting when a jeep enters are
wanted, but belong to a **separate part/milestone**, not M6A or incidental
Coastal Highway level work. Brainstorm and approve a new spec later; this note
does not authorize implementation, physics tuning or a particular algorithm.

Recommendation: accept and merge M6A first, then prototype this separate water
part on the Test Ground **before building Coastal Highway**. Dynamic water
height and forces could affect crossing depths, causeway heights, recovery
routes and performance, so the track should be designed around the measured
result. This ordering is a recommendation awaiting the owner's decision, not a
change to the current milestone approval gates.

The later discussion should distinguish cosmetic ripples/wakes from a moving
physical surface, and decide which the owner wants for wind/swell and for
vehicle entry/displacement. It must define how rendered height agrees with
intake submersion, buoyancy, banks and bottoms, and measure phone cost before
committing to a full level. No fluid simulation is promised by this note.

Aquaplaning and deep-water skimming remain separate optional experiments; waves
do not implicitly approve either one. Visible snorkel art is also still deferred.

## Starting point for the next discussion (2026-09-24)

The owner requested the ford/creek fixes and frame-budget review first, followed
by waves brainstorming. The fixes are documented in
`m6a-query-fixes-2026-09-24.md`; the owner reconnected the phone for fresh
measurements, but acceptance remains open. Brainstorming does not approve implementation or
waive Part A's review/merge gates.

Suggested first prototype: gentle, visible waves that can rock a floating car,
plus bounded entry ripples and a trailing wake on the Test Ground. The moving
physical surface must agree with the visible surface for buoyancy and intake
submersion, with calm/shallow-bank attenuation. No general fluid solver,
aquaplaning or speed-lift experiment is implied. Any choice of physical versus
cosmetic vehicle-generated ripples must be explicit in the later spec.

First owner decision: should waves mainly bring the water to life and gently
affect the car (recommended starting scope), or should swell already be a
timing/route-selection hazard for Coastal Highway? Choose that before settling
wave size, wake detail, implementation or track layout. Proposed sequence
remains a separate measured prototype before Coastal Highway, not unreviewed
wave work hidden in the level milestone.
