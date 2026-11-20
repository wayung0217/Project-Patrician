class_name SubstitutionRule
extends Resource
## WP-34 substitutions row (D-25a／D-36b／c); CSV → tres via csv_import.


@export var good_id: String = "" ## primary good A (internal: from)
@export var substitute_id: String = "" ## substitute B (internal: to)
## Cap／utility as ppm (cell × PRM-SYS06-PPM_SCALE).
@export var cap_ppm: int = 0
@export var util_ppm: int = 0
