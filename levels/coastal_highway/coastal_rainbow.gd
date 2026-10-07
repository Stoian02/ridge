class_name CoastalRainbow
extends MeshInstance3D
## One soft, depth-tested far arc, opposite the mood's sun. No physics/light.
## Fixed in world space, not a camera-following overlay or checkpoint toggle.

const SEGMENTS := 96
const BANDS := 8
const COLORS: Array[Color] = [Color(0.65, 0.48, 0.85), Color(0.42, 0.53, 0.87),
	Color(0.42, 0.72, 0.78), Color(0.50, 0.78, 0.52), Color(0.87, 0.83, 0.46),
	Color(0.93, 0.65, 0.40), Color(0.92, 0.48, 0.46)]

@export var radius: float = 680.0
@export var width: float = 18.0
@export var opacity: float = 0.20
@export var sun_azimuth_deg: float = -25.0


func _ready() -> void:
	mesh = make_mesh()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;\nvoid fragment() { ALBEDO = COLOR.rgb; ALPHA = COLOR.a; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Ring plane is perpendicular to the antisolar bearing.
	rotation.y = deg_to_rad(sun_azimuth_deg)


func make_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for band in BANDS + 1:
		var t := float(band) / BANDS
		var color_at := t * (COLORS.size() - 1)
		var color := COLORS[mini(int(color_at), COLORS.size()-1)].lerp(
			COLORS[mini(int(color_at)+1, COLORS.size()-1)], fmod(color_at, 1.0))
		var feather := minf(smoothstep(0.0, 0.25, t), 1.0 - smoothstep(0.75, 1.0, t))
		for segment in SEGMENTS + 1:
			var angle := PI * float(segment) / SEGMENTS
			var r := radius + width * (t - 0.5)
			vertices.append(Vector3(cos(angle) * r, sin(angle) * r, 0.0))
			color.a = opacity * feather * smoothstep(0.0, 0.25, sin(angle))
			colors.append(color)
	for band in BANDS:
		for segment in SEGMENTS:
			var a := band * (SEGMENTS + 1) + segment
			indices.append_array([a, a+1, a+SEGMENTS+1, a+1, a+SEGMENTS+2, a+SEGMENTS+1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var arc := ArrayMesh.new()
	arc.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arc
