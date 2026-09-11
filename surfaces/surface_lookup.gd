class_name SurfaceLookup
extends RefCounted
## Finds out which SurfaceDef a collider is made of.
## Ground bodies carry a "surface" meta entry holding a SurfaceDef. Anything
## untagged counts as dirt, so no ground is ever surface-less.

const META_KEY := &"surface"
const FALLBACK_PATH := "res://surfaces/dirt.tres"

static var _fallback: SurfaceDef


static func surface_of(collider: Object) -> SurfaceDef:
	if collider != null and collider.has_meta(META_KEY):
		var value: Variant = collider.get_meta(META_KEY)
		if value is SurfaceDef:
			return value
	return fallback()


static func fallback() -> SurfaceDef:
	if _fallback == null:
		_fallback = load(FALLBACK_PATH)
	return _fallback
