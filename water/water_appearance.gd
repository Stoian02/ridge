class_name WaterAppearance
extends RefCounted
## Lightweight shared water appearance. Geometry and physical depth stay with
## the owning builder; animating these UVs never moves the physical surface.

const SHALLOW := Color(0.28, 0.55, 0.58, 0.30)
const DEEP := Color(0.08, 0.20, 0.25, 0.85)
const TEXTURE_SCALE := 0.25

static var _pattern: ImageTexture


static func make_material(color: Color, vertex_colors: bool = false,
		triplanar: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = vertex_colors
	material.vertex_color_is_srgb = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.18
	material.metallic = 0.0
	material.metallic_specular = 0.65
	material.albedo_texture = _surface_pattern()
	material.uv1_triplanar = triplanar
	material.uv1_world_triplanar = triplanar
	if triplanar:
		material.uv1_scale = Vector3.ONE * TEXTURE_SCALE
	return material


static func pool_color(depth: float) -> Color:
	if depth >= 2.0:
		return DEEP
	var color := SHALLOW.lerp(DEEP, smoothstep(0.20, 2.00, depth))
	color.a *= clampf(depth / 0.05, 0.0, 1.0)
	return color


static func advance(material: StandardMaterial3D, current: Vector3, delta: float) -> void:
	var motion := Vector2(current.x, current.z) * TEXTURE_SCALE
	if motion.length_squared() < 0.000001:
		motion = Vector2(0.008, 0.005)
	var offset := material.uv1_offset
	offset.x = fposmod(offset.x - motion.x * delta, 1.0)
	if material.uv1_triplanar:
		offset.z = fposmod(offset.z - motion.y * delta, 1.0)
	else:
		offset.y = fposmod(offset.y - motion.y * delta, 1.0)
	material.uv1_offset = offset


## Small synchronous periodic pattern: no shader, asynchronous noise texture or
## image asset. Alpha is untouched so the material/vertex depth fade owns it.
static func _surface_pattern() -> ImageTexture:
	if _pattern != null:
		return _pattern
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var u := TAU * x / 32.0
			var v := TAU * y / 32.0
			var shade := 0.97 + 0.02 * sin(u + 2.0 * v) + 0.01 * cos(3.0 * u - v)
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	image.generate_mipmaps()
	_pattern = ImageTexture.create_from_image(image)
	return _pattern
