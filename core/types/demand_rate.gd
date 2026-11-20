class_name DemandRate
extends Resource
## WP-34 demand_rates row (D-25a／D-36b／c); CSV → tres via csv_import.


@export var good_id: String = ""
## Per-class rate in centi-jin／person／week (jin_per_week × PRM-SYS06-RATE_SCALE).
@export var poor_rate_cj: int = 0
@export var citizen_rate_cj: int = 0
@export var rich_rate_cj: int = 0
