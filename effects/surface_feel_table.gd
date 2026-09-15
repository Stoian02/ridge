class_name SurfaceFeelTable
extends Resource
## Surface id -> SurfaceFeel (spec §3.1), like GripTable does for grip. Surfaces
## without an entry use the fallback.

## StringName surface id -> SurfaceFeel.
@export var feels: Dictionary = {}
@export var fallback: SurfaceFeel


## The feel for `surface`: its entry, the fallback for an unknown id, or null with
## no surface (a wheel in the air).
func feel_for(surface: SurfaceDef) -> SurfaceFeel:
	if surface == null:
		return null
	var feel: SurfaceFeel = feels.get(surface.id)
	return feel if feel != null else fallback
