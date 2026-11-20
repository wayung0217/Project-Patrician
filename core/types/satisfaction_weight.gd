class_name SatisfactionWeight
extends Resource
## WP-34 satisfaction_weights row (D-25a／D-36b／c); CSV → tres via csv_import.


@export var good_id: String = ""
## Integer percentage points; class column sums must equal PRM-SYS06-WEIGHT_SUM.
@export var poor_weight_pct: int = 0
@export var citizen_weight_pct: int = 0
@export var rich_weight_pct: int = 0
