extends SceneTree
## Builds Rally Road's centre-line curve from a list of segments and saves it as
## levels/rally_road/rally_road_curve.tres. Re-run after changing SEGMENTS:
##   godot --headless -s tools/generate_rally_road_curve.gd
## Segment format: see CurveGenerator.

const OUTPUT := "res://levels/rally_road/rally_road_curve.tres"

const SEGMENTS := [
	["straight", 80.0, 0.01],     # start straight in the valley
	["arc", 120.0, 35.0, 0.04],
	["straight", 60.0, 0.04],
	["arc", 150.0, -45.0, 0.04],
	["straight", 130.0, 0.04],    # jump 1 at ~440 m, pothole cluster at ~250 m
	["arc", 100.0, 40.0, 0.04],
	["straight", 70.0, 0.04],     # checkpoint at 600 m
	["straight", 90.0, 0.03],     # rough stretch 680-830 m begins
	["arc", 200.0, -20.0, 0.03],
	["straight", 80.0, 0.03],
	["arc", 45.0, 50.0, 0.08],    # esses
	["arc", 45.0, -60.0, 0.08],
	["straight", 30.0, 0.08],
	["arc", 15.0, 180.0, 0.06],   # hairpin 1
	["straight", 80.0, 0.12],     # pothole cluster at ~1050 m
	["arc", 15.0, -180.0, 0.06],  # hairpin 2
	["straight", 80.0, 0.12],     # checkpoint at 1200 m
	["arc", 15.0, 180.0, 0.06],   # hairpin 3
	["straight", 60.0, 0.08],
	["straight", 120.0, 0.02],    # ridge straight, jump 2 at ~1380 m
	["arc", 200.0, -15.0, 0.02],
	["straight", 20.0, 0.0],      # finish overlooking the valley
	["straight", 60.0, 0.0],      # run-off past the finish
]


func _init() -> void:
	quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "Rally Road"))
