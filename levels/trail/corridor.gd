class_name Corridor
extends RefCounted
## How the terrain meets the road. Under the road and shoulders the terrain sits
## just below them. Outside the shoulder edge it blends from the road's height
## back to the natural mountainside over `blend_width`: a cut uphill, an
## embankment downhill.

## At the shoulder edge the terrain sits this far below the road, so they never z-fight (m).
const EDGE_GAP := 0.05
## Inside the edge, the terrain drops to its full depth over this distance (m).
const INSIDE_FALLOFF := 1.5


## How much of the natural terrain shows at `edge_distance` metres outside the
## shoulder edge: 0 at the edge (and inside it), 1 at blend_width and beyond.
static func natural_weight(edge_distance: float, blend_width: float) -> float:
	return smoothstep(0.0, blend_width, edge_distance)


## Terrain height at a point. edge_distance: metres outside the shoulder edge
## (negative = under the road or a shoulder).
static func carved_height(road_height: float, natural_height: float, edge_distance: float,
		blend_width: float, under_road_drop: float) -> float:
	if edge_distance < 0.0:
		var depth := lerpf(EDGE_GAP, under_road_drop, smoothstep(0.0, INSIDE_FALLOFF, -edge_distance))
		return road_height - depth
	return lerpf(road_height - EDGE_GAP, natural_height, natural_weight(edge_distance, blend_width))
