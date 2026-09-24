class_name WaterWaveSnapshot
extends RefCounted
## Reusable float32 contract shared with the actual surface and diagnostic shader.
## Write only between ticks. Positions are local XZ metres for this one body.

var serial: int = -1
var body_id: StringName
var ambient := PackedVector4Array()
## centre.xz, age, amplitude; direction.xz, life, wake flag.
var packets := PackedVector4Array()
var directions := PackedVector4Array()
## width, propagation speed, soft core, radial attenuation.
var shape: Vector4
var envelope: Vector2
## centre.xz, amplitude, longitudinal half-width; direction.xz, lateral half-width.
var bow: Vector4
var bow_direction: Vector4


func _init() -> void:
	ambient.resize(2)
	packets.resize(WaterWaveProfile.PACKET_SLOTS)
	directions.resize(WaterWaveProfile.PACKET_SLOTS)


func upload(material: ShaderMaterial) -> void:
	material.set_shader_parameter("wave_ambient", ambient)
	material.set_shader_parameter("wave_packets", packets)
	material.set_shader_parameter("wave_directions", directions)
	material.set_shader_parameter("wave_shape", shape)
	material.set_shader_parameter("wave_envelope", envelope)
	material.set_shader_parameter("wave_bow", bow)
	material.set_shader_parameter("wave_bow_direction", bow_direction)
