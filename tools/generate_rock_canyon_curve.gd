extends SceneTree
## Rock Canyon (M5 spec §3.2): asphalt canyon mouth, a drop into the shaded mud
## climb with weaving wheel tracks and a clearing, the boulder wash, talus and ford, a switchback up to
## the narrow shelf, and the final scree push to the rim. Segment ends are noted
## as cumulative distances.

const OUTPUT := "res://levels/rock_canyon/rock_canyon_curve.tres"
const SEGMENTS := [
	["straight", 120.0, 0.02],
	["arc", 150.0, 30.0, 0.02],        # ~198 m: easy bends on tarmac
	["straight", 22.0, 0.02],          # 220 m: the last tarmac
	["straight", 80.0, -0.05],         # 300 m: drop into the side-gully
	["arc", 48.0, -65.0, 0.025],      # ~355 m: start climbing as the mud begins
	["straight", 18.0, 0.04],          # ~373 m
	["arc", 36.0, 90.0, 0.055],        # ~429 m: tighter opposing turn
	["straight", 12.0, 0.075],         # ~441 m
	["arc", 32.0, -80.0, 0.085],       # ~486 m: the climb steepens
	["arc", 42.0, 50.0, 0.10],         # ~523 m: last climbing bend, old 25-degree exit heading
	["straight", 37.4, 0.055],         # ~560 m: ease over the brow
	["straight", 90.0, 0.005],         # ~650 m: wide, almost level clearing
	["straight", 50.0, 0.04],          # 700 m: rejoin the untouched wash sequence
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
