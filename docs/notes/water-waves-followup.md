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
