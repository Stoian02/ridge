# Follow-up: waves and vehicle-displaced water

Owner request, 2026-09-23: waves and water reacting when a jeep enters are
wanted, but belong to a **separate part/milestone**, not M6A or incidental
Coastal Highway level work. A separate written spec must be reviewed before
implementation; this note does not authorize physics tuning or an algorithm.

**Planning finished for owner/Claude review (2026-09-24):**
`../superpowers/specs/2026-09-24-m6w-water-waves-design.md` and
`../superpowers/plans/2026-09-24-m6w-water-waves.md`. These are complete review
drafts, **not implementation approval**. The proposed shader, numerical starting
values, Test Ground controls, budgets and sequencing are explicitly presented
for review. No wave runtime work or game/phone tests were started for the plans.

Recommendation: accept and merge M6A first, then prototype this separate water
part on the Test Ground **before building Coastal Highway**. Dynamic water
height and forces could affect crossing depths, causeway heights, recovery
routes and performance, so the track should be designed around the measured
result. This ordering is a recommendation awaiting the owner's decision, not a
change to the current milestone approval gates.

The design must distinguish cosmetic ripples/wakes from a moving physical
surface. The owner has now approved a gentle physical response from the larger
waves, including vehicle-generated waves (see decisions below). Define how
rendered height agrees with intake submersion, buoyancy, banks and bottoms, and
measure phone cost before committing to a full level. No fluid simulation is
promised by this note.

Aquaplaning and deep-water skimming remain separate optional experiments; waves
do not implicitly approve either one. Visible snorkel art is also still deferred.

## Planning context (2026-09-24)

The owner requested the ford/creek fixes and frame-budget review first, followed
by waves brainstorming. The fixes are documented in
`m6a-query-fixes-2026-09-24.md`; the owner reconnected the phone for fresh
measurements, but acceptance remains open. Brainstorming does not approve
implementation or waive Part A's review/merge gates.

## Agreed first-prototype behaviour (2026-09-24)

The owner agreed to the following behaviours during brainstorming:

- Gentle background waves, not large swell designed as a driving hazard.
- An outward-spreading entry wave responding to the car entering the water.
- A bow wave and trailing wake while driving through it, responding to
  water-relative movement and submersion.
- Existing disturbances spread and settle after stopping or leaving; the car
  must not keep generating an ever-growing wake while stationary.
- Larger waves, including vehicle-generated waves, slightly affect flotation.
  The owner explicitly delegated the starting strength to Codex. Fine ripples,
  foam and splash particles remain visual detail, not separate physical water.
- Test this first on the Test Ground. Keep transparency and agreement between
  visible surface movement and the surface used for flotation.

The owner then chose to **defer wall/rock wave reflections**: test the basic
behaviours first and revisit reflections afterwards. Do not build the suggested
reflecting-wall test or treat reflection support as approved for the first
prototype. Moving-obstacle interaction, detailed breaking waves and overflowing
water also stay out of this initial scope. No general fluid solver, aquaplaning
or speed-lift experiment is implied.

Recommended initial boundary treatment (not a reflective solver): fade wave
disturbances near banks and water-footprint edges, keeping them inside the
water. Geometry-specific obstacle response remains deferred; do not claim the
first prototype models waves bouncing or bending around arbitrary rocks.

The owner also approved using the moving physical surface for intake submersion
as well as flotation. Cosmetic splash particles do not count as intake
submersion. In the same response, they requested **3.00 s of continuous intake
submersion before stalling**, replacing 0.60 s for all three cars. A dry intake
sample still resets this timer; restart and body-flooding rules are unchanged.
This small current-water tuning change is separate from implementing waves and
is recorded as an amendment in the Part A spec.

These are agreed behaviour decisions, not permission to implement. The written
spec/plan now propose the algorithm, numerical starting values, controls and
performance checks for review. Proposed sequence remains a separately measured
prototype before Coastal Highway, subject to Part A acceptance/review and
owner-authorized merge. The separately requested stall-delay amendment is
implemented and desktop-tested (see `codex-report-m6a-water.md`); no wave runtime
work has started.
