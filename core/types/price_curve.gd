class_name PriceCurve
extends Resource
## SYS-04 PriceCurve — breakpoint table [{weeks, mult}] (03_Systems r402 / TechSpec 3.5 D).
## Parallel arrays: index i is {weeks[i], mults[i]}. First weeks must be 0; after last point mult holds (floor).
## Values come from price_curve.tres (TechSpec §4 PRM-SYS04-CURVE_*), not from .gd literals (C-03).

@export var weeks: PackedFloat64Array = PackedFloat64Array()
@export var mults: PackedFloat64Array = PackedFloat64Array()


func point_count() -> int:
	return mini(weeks.size(), mults.size())
