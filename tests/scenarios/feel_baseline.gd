class_name FeelBaseline
extends RefCounted
## Acceptable ranges for the scenario tests. Deliberately wide until the first
## tune is approved on the phone; then they are narrowed around measured values
## so later changes can't silently break an approved feel.

const RIDE_HEIGHT_TOLERANCE := 0.02      # m, per wheel, vs. static sag
const MAX_PARKED_CREEP := 0.02           # m, over 3 s on flat asphalt
const ZERO_TO_HUNDRED_MIN := 3.5         # s
const ZERO_TO_HUNDRED_MAX := 10.0        # s
const BRAKING_FROM_HUNDRED_MIN := 25.0   # m
const BRAKING_FROM_HUNDRED_MAX := 60.0   # m
