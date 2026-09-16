extends SceneTree
## Reproducible snow valley, climbing switchbacks, summit S-tunnel and descent.

const OUTPUT := "res://levels/frozen_pass/frozen_pass_curve.tres"
const SEGMENTS := [
	["straight", 150.0, 0.035],
	["arc", 180.0, 35.0, 0.04],
	["straight", 90.0, 0.045],         # ~350 m: leave the pine valley
	["straight", 60.0, 0.09],
	["arc", 28.0, 180.0, 0.08],       # first climbing hairpin
	["straight", 120.0, 0.10],
	["arc", 28.0, -180.0, 0.08],      # second climbing hairpin
	["straight", 94.0, 0.09],         # ~800 m
	["straight", 100.0, 0.015],       # bridge, a gentle grade over the gorge
	["arc", 180.0, 45.0, 0.08],
	["straight", 108.5, 0.08],        # ~1150 m: tunnel entrance
	["arc", 100.0, 60.0, 0.01],
	["arc", 100.0, -60.0, 0.01],
	["straight", 40.5, 0.0],          # ~1400 m: tunnel exit
	["arc", 85.0, -55.0, -0.065],
	["straight", 50.0, -0.08],
	["arc", 80.0, 65.0, -0.07],
	["arc", 65.0, -60.0, -0.08],
	["straight", 55.0, -0.075],
	["arc", 32.0, 170.0, -0.06],      # descent hairpin
	["straight", 75.0, -0.085],
	["arc", 75.0, -45.0, -0.07],
	["straight", 75.5, -0.07],
	["straight", 50.0, -0.025],       # finish meadow
	["straight", 70.0, 0.0],          # braking run-off
]


func _init() -> void:
	quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "Frozen Pass"))
