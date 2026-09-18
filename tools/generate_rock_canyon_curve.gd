extends SceneTree
## Rock Canyon (M5 spec §3.2): asphalt canyon mouth, a drop into the shaded mud
## gully, the climbing boulder wash, the talus scar and ford, a switchback up to
## the narrow shelf, and the final scree push to the rim. Segment ends are noted
## as cumulative distances.

const OUTPUT := "res://levels/rock_canyon/rock_canyon_curve.tres"
const SEGMENTS := [
	["straight", 120.0, 0.02],
	["arc", 150.0, 30.0, 0.02],        # ~198 m: easy bends on tarmac
	["straight", 22.0, 0.02],          # 220 m: the last tarmac
	["straight", 80.0, -0.05],         # 300 m: drop into the side-gully
	["arc", 120.0, -40.0, 0.0],        # ~384 m: the deep mud gully, flat
	["straight", 96.0, 0.0],           # ~480 m
	["arc", 90.0, 35.0, 0.0],          # ~535 m
	["straight", 25.0, 0.0],           # 560 m: the gully ends
	["straight", 140.0, 0.04],         # 700 m: climb out; the wash begins
	["arc", 110.0, -45.0, 0.035],      # ~787 m
	["straight", 100.0, 0.04],         # ~887 m
	["arc", 100.0, 50.0, 0.045],       # ~974 m
	["straight", 100.0, 0.05],         # ~1074 m
	["arc", 130.0, -34.0, 0.04],       # ~1151 m: the talus field
	["straight", 100.0, 0.02],         # ~1251 m
	["straight", 80.0, 0.0],           # ~1331 m: the ford, level
	["straight", 60.0, 0.08],          # ~1391 m: the wash steepens
	["arc", 30.0, 180.0, 0.09],        # ~1485 m: switchback
	["straight", 16.0, 0.10],          # ~1501 m: the shelf starts
	["arc", 200.0, -30.0, 0.06],        # ~1606 m
	["straight", 120.0, 0.06],         # ~1726 m
	["arc", 160.0, -40.0, 0.06],       # ~1838 m: the squeeze
	["straight", 63.0, 0.06],          # ~1901 m: the shelf ends
	["straight", 150.0, 0.12],         # ~2051 m: final push on scree
	["straight", 50.0, 0.0],           # ~2101 m: the rim and finish
	["straight", 70.0, 0.0],           # run-off
]


func _init() -> void:
	quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "Rock Canyon"))
