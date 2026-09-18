class_name FordDef
extends Resource
## A shallow visual river crossing: a dipped road, channel and waterfall.
## No buoyancy or water collision. Depth is measured from the actual road,
## including permanent rock steps, so later water physics can reuse this data.

## Where the river crosses the road (m along the trail).
@export var distance: float = 0.0
@export var channel_width: float = 16.0
## The road's drop at the centre of the crossing (m).
@export var depth: float = 0.35
@export var water_depth: float = 0.3
## Length of each eased road approach (m).
@export var bank_run: float = 10.0
@export var waterfall_height: float = 14.0
@export var waterfall_width: float = 3.5
## Lateral position of the foot; negative is the left canyon wall.
@export var waterfall_offset: float = -22.0
## Lateral endpoint of the river on the other side of the road (m).
@export var river_reach: float = 45.0
@export var water_color: Color = Color(0.36, 0.5, 0.55)
@export var foam_color: Color = Color(0.9, 0.95, 0.97)
@export var seed: int = 83

## Horizontal return from the waterfall's rock face into its terrain ledge.
const LEDGE_RUN := 4.0
## Extra rock on each side of the waterfall sheet.
const ROCK_MARGIN := 1.0
## The ribbon continues under the banks; solid ground hides its outer edges.
const BANK_COVER := 0.85


func half_width() -> float:
	return channel_width * 0.5


func water_half_width() -> float:
	return half_width() + bank_run * BANK_COVER


func contains(at: float) -> bool:
	return absf(at - distance) <= half_width()


## Negative throughout the bed, easing to zero over the two banks.
func height_offset(at: float) -> float:
	var away := absf(at - distance) - half_width()
	if away <= 0.0:
		return -depth
	if away >= bank_run:
		return 0.0
	return -depth * (1.0 - smoothstep(0.0, bank_run, away))


## Shared elevation for terrain, water and falls. The profile already includes
## this ford's dip: do not subtract depth again or omit earlier rock steps.
func floor_height(sampler: RoadSampler, profile: RoadProfile) -> float:
	return sampler.surface_point(distance, 0.0, profile).y


## A horizontal river frame, perpendicular even on a graded/banked road.
func across(sampler: RoadSampler) -> Vector3:
	return sampler.forward(distance).cross(Vector3.UP).normalized()
