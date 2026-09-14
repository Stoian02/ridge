extends SceneTree
## Builds Muddy Valley's centre-line curve from a list of segments and saves it as
## levels/muddy_valley/muddy_valley_curve.tres. Re-run after changing SEGMENTS:
##   godot --headless -s tools/generate_muddy_valley_curve.gd
## Segment format: see CurveGenerator.

const OUTPUT := "res://levels/muddy_valley/muddy_valley_curve.tres"

const SEGMENTS := [
	["straight", 80.0, 0.0],      # ridge start, looking over the valley
	["arc", 120.0, 30.0, -0.05],
	["straight", 70.0, -0.08],
	["arc", 90.0, -45.0, -0.08],
	["straight", 90.0, -0.09],    # the jump
	["arc", 50.0, 55.0, -0.09],   # esses
	["arc", 50.0, -60.0, -0.09],
	["straight", 40.0, -0.1],
	["arc", 18.0, 180.0, -0.07],  # hairpin
	["straight", 60.0, -0.06],
	["arc", 150.0, -35.0, -0.02], # into the valley
	["straight", 80.0, 0.0],      # mud stretch 1
	["arc", 200.0, 25.0, 0.01],
	["straight", 250.0, 0.01],    # the creek, with mud stretch 2
	["arc", 120.0, -40.0, 0.03],
	["straight", 130.0, 0.08],    # the final climb
	["arc", 100.0, 30.0, 0.08],
	["straight", 100.0, 0.08],    # mud to the finish
	["straight", 60.0, 0.0],      # run-off past the finish
]


func _init() -> void:
	quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "Muddy Valley"))
