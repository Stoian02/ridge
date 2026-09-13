class_name TrailDef
extends Resource
## Road settings for one trail. Distances are metres along the road; lateral
## positions are metres from the centre line (+ = right when driving forward).

@export_group("Cross-section")
@export var road_width: float = 7.0
@export var shoulder_width: float = 2.5
@export var line_width: float = 0.15
## Painted edge lines sit this far inside each road edge.
@export var line_inset: float = 0.3
## Spacing of vertices across the asphalt.
@export var lateral_step: float = 0.5
## Distance between cross-sections outside rough ranges.
@export var sample_step: float = 1.0
## Distance between cross-sections inside rough ranges and pothole clusters.
@export var detail_step: float = 0.25
## Length of road built as one mesh and collision chunk.
@export var chunk_length: float = 100.0

@export_group("Undulation")
## Peak height of the gentle waves along the whole road.
@export var undulation_amplitude: float = 0.05
## The two summed wave lengths.
@export var undulation_wavelengths: Vector2 = Vector2(23.0, 37.0)

@export_group("Rough ground")
## Rough stretches as Vector3(start distance, length, potholes per 100 m).
@export var rough_sections: Array[Vector3] = []
## Short pothole clusters as Vector2(centre distance, pothole count).
@export var pothole_clusters: Array[Vector2] = []
@export var pothole_radius_range: Vector2 = Vector2(0.35, 0.65)
@export var pothole_depth_range: Vector2 = Vector2(0.06, 0.12)
## Potholes and patches keep this far from the ends of a rough stretch.
@export var rough_margin: float = 3.0

@export_group("Jumps")
## Jump crests shaped into the road, as Vector3(distance, height, length).
@export var jumps: Array[Vector3] = []

@export_group("Checkpoints")
## The start gate sits this far along the road, leaving road behind the car.
@export var start_distance: float = 10.0
## The finish gate sits this far before the end of the road.
@export var end_margin: float = 10.0
## Checkpoint gate distances between the start and the finish. The start (0)
## and finish (road length) gates are added automatically.
@export var checkpoint_distances: PackedFloat32Array = PackedFloat32Array()

@export_group("Colours")
@export var asphalt_color: Color = Color(0.24, 0.23, 0.24)
@export var patch_color: Color = Color(0.3, 0.29, 0.28)
@export var line_color: Color = Color(0.92, 0.9, 0.84)
@export var shoulder_color: Color = Color(0.62, 0.47, 0.3)

## Seed for pothole and patch placement and undulation phases.
@export var seed: int = 1


## Half the width of road plus both shoulders.
func half_total_width() -> float:
	return road_width * 0.5 + shoulder_width
