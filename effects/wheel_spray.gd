class_name WheelSpray
extends CPUParticles3D
## One wheel's spray (spec §4.2): mud clods, dust, tyre smoke or a water sheet. Its particles stay
## in the world where they were thrown. It hides once it has been idle for longer
## than its particles live, so an idle spray costs no draw call.
## Forward is -Z, so "behind the tyre" is +Z of the transform the car gives it.

const AMOUNT := 24
const QUAD_SIZE := 0.22
const MIN_ALPHA := 0.35
const MAX_ALPHA := 0.9
## A barely-there spray is thrown at this share of its kind's full speed.
const MIN_SPEED_SHARE := 0.5

static var _quad: QuadMesh
static var _growth_curves: Dictionary = {}
static var _fade: Gradient

var kind: SurfaceFeel.SprayKind = SurfaceFeel.SprayKind.NONE
var _idle_seconds := 0.0
## The current kind's full throw speed, as Vector2(min, max) (m/s).
var _base_velocity := Vector2.ZERO
var _water_feel: SurfaceFeel
var _mixed := false


func _init() -> void:
	amount = AMOUNT
	emitting = false
	visible = false
	local_coords = false
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _shared_quad()
	randomness = 0.4
	_water_feel = SurfaceFeel.new()
	_water_feel.spray = SurfaceFeel.SprayKind.SPLASH


## Sprays `feel`'s kind at `strength` (0-1), or stops below the threshold.
func update(feel: SurfaceFeel, strength: float, delta: float) -> void:
	if _mixed:
		_configure(kind)
		_mixed = false
	var wanted := SurfaceFeel.SprayKind.NONE
	if feel != null and strength > SprayLogic.THRESHOLD:
		wanted = feel.spray
	if wanted == SurfaceFeel.SprayKind.NONE:
		emitting = false
		if visible:
			_idle_seconds += delta
			if _idle_seconds > lifetime:
				visible = false
		return
	if wanted != kind:
		_configure(wanted)
	color = Color(feel.spray_color, lerpf(MIN_ALPHA, MAX_ALPHA, strength))
	# Stronger spray is thrown faster; the particle count stays put, since changing it restarts the emitter.
	var speed := lerpf(MIN_SPEED_SHARE, 1.0, clampf(strength, 0.0, 1.0))
	initial_velocity_min = _base_velocity.x * speed
	initial_velocity_max = _base_velocity.y * speed
	_idle_seconds = 0.0
	visible = true
	emitting = true


## Stops at once and hides, leaving no trail (a car reset).
func stop_now() -> void:
	restart()
	emitting = false
	visible = false
	_idle_seconds = 0.0


## One emitter, never two stacked full-strength effects. Interpolate throw,
## lifetime, colour and size while suppressing the dry component by immersion.
func update_water(dry: SurfaceFeel, dry_strength: float, tint: Color,
		splash_strength: float, wetness: float, delta: float) -> void:
	_mixed = false
	var dry_part := dry_strength * (1.0 - wetness)
	var strength := clampf(dry_part + splash_strength, 0.0, 1.0)
	var blend := splash_strength / maxf(dry_part + splash_strength, 0.0001)
	_water_feel.spray_color = dry.spray_color.lerp(tint, blend) if dry != null else tint
	# Deep water has no splash, and must not keep sending dry dust from below it.
	if strength <= SprayLogic.THRESHOLD:
		update(null, 0.0, delta)
		return
	var dry_kind := dry.spray if dry != null else SurfaceFeel.SprayKind.SPLASH
	if dry_kind == SurfaceFeel.SprayKind.NONE:
		dry_kind = SurfaceFeel.SprayKind.SPLASH
	_configure(dry_kind)
	var dry_velocity := _base_velocity
	var dry_gravity := gravity
	var dry_lifetime := lifetime
	var dry_direction := direction
	var dry_spread := spread
	var dry_scale := Vector2(scale_amount_min, scale_amount_max)
	_configure(SurfaceFeel.SprayKind.SPLASH)
	_base_velocity = dry_velocity.lerp(_base_velocity, blend)
	gravity = dry_gravity.lerp(gravity, blend)
	lifetime = lerpf(dry_lifetime, lifetime, blend)
	direction = dry_direction.lerp(direction, blend)
	spread = lerpf(dry_spread, spread, blend)
	scale_amount_min = lerpf(dry_scale.x, scale_amount_min, blend)
	scale_amount_max = lerpf(dry_scale.y, scale_amount_max, blend)
	update(_water_feel, strength, delta)
	_mixed = true


func _configure(new_kind: SurfaceFeel.SprayKind) -> void:
	kind = new_kind
	match new_kind:
		SurfaceFeel.SprayKind.CLODS:
			lifetime = 0.7
			direction = Vector3(0.0, 0.7, 1.0)
			spread = 25.0
			initial_velocity_min = 3.0
			initial_velocity_max = 6.0
			gravity = Vector3(0.0, -12.0, 0.0)
			damping_min = 0.0
			damping_max = 0.5
			scale_amount_min = 0.35
			scale_amount_max = 0.7
			scale_amount_curve = null
			color_ramp = null
		SurfaceFeel.SprayKind.DUST:
			lifetime = 1.2
			direction = Vector3(0.0, 0.5, 1.0)
			spread = 40.0
			initial_velocity_min = 0.5
			initial_velocity_max = 2.0
			gravity = Vector3(0.0, 0.3, 0.0)
			damping_min = 1.0
			damping_max = 2.0
			scale_amount_min = 1.2
			scale_amount_max = 2.2
			scale_amount_curve = _growing_curve(3.0)
			color_ramp = _fading_ramp()
		SurfaceFeel.SprayKind.SMOKE:
			lifetime = 1.4
			direction = Vector3(0.0, 1.0, 0.3)
			spread = 30.0
			initial_velocity_min = 0.5
			initial_velocity_max = 1.5
			gravity = Vector3(0.0, 0.6, 0.0)
			damping_min = 0.5
			damping_max = 1.0
			scale_amount_min = 1.5
			scale_amount_max = 2.5
			scale_amount_curve = _growing_curve(3.5)
			color_ramp = _fading_ramp()
		SurfaceFeel.SprayKind.SPLASH:
			lifetime = 0.9
			direction = Vector3(0.0, 0.6, 1.0)
			spread = 45.0
			initial_velocity_min = 4.0
			initial_velocity_max = 8.0
			gravity = Vector3(0.0, -9.0, 0.0)
			damping_min = 0.5
			damping_max = 1.5
			scale_amount_min = 1.0
			scale_amount_max = 2.0
			scale_amount_curve = _growing_curve(2.0)
			color_ramp = _fading_ramp()
	_base_velocity = Vector2(initial_velocity_min, initial_velocity_max)


static func _shared_quad() -> QuadMesh:
	if _quad == null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		_quad = QuadMesh.new()
		_quad.size = Vector2(QUAD_SIZE, QUAD_SIZE)
		_quad.material = material
	return _quad


static func _growing_curve(to: float) -> Curve:
	if _growth_curves.has(to):
		return _growth_curves[to]
	var curve := Curve.new()
	curve.max_value = to
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, to))
	_growth_curves[to] = curve
	return curve


static func _fading_ramp() -> Gradient:
	if _fade != null:
		return _fade
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_fade = ramp
	return ramp
