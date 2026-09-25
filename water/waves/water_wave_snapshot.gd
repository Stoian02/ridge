class_name WaterWaveSnapshot
extends RefCounted
## Reusable float32 contract shared with the actual surface and diagnostic shader.
## Write only between ticks. Positions are local XZ metres for this one body.

var serial: int = -1
var body_id: StringName
var ambient := PackedVector4Array()
## centre.xz, age, amplitude; direction.xz, life, kind/radius:
## w = 1 for wake; w <= 0 for entry with initial soft radius -w metres.
var packets := PackedVector4Array()
var directions := PackedVector4Array()
## width, propagation speed, soft core, radial attenuation.
var shape: Vector4
var envelope: Vector2
## leading crest centre.xz, amplitude, thickness half-width;
## travel direction.xz, lateral half-span, backward sweep in metres.
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


## Suppress redundant server submissions, not snapshot updates. Packed arrays
## are copy-on-write, so the retained last-uploaded values stay immutable.
## Every actual uniform still equals this complete current-tick snapshot.
func upload_changed(material: ShaderMaterial, previous: WaterWaveSnapshot) -> void:
	if ambient != previous.ambient:
		material.set_shader_parameter("wave_ambient", ambient)
		previous.ambient = ambient
	if packets != previous.packets:
		material.set_shader_parameter("wave_packets", packets)
		previous.packets = packets
	if directions != previous.directions:
		material.set_shader_parameter("wave_directions", directions)
		previous.directions = directions
	if shape != previous.shape:
		material.set_shader_parameter("wave_shape", shape)
		previous.shape = shape
	if envelope != previous.envelope:
		material.set_shader_parameter("wave_envelope", envelope)
		previous.envelope = envelope
	if bow != previous.bow:
		material.set_shader_parameter("wave_bow", bow)
		previous.bow = bow
	if bow_direction != previous.bow_direction:
		material.set_shader_parameter("wave_bow_direction", bow_direction)
		previous.bow_direction = bow_direction
