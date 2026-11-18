class_name BuildingDef
extends Resource
## WP-17 building row (TechSpec 10-05 / 04_Content §7 buildings headers).

@export var type: String = ""
@export var tier: int = 0
@export var max_workers: int = 0
## 定點數 — stored as float (TechSpec 10-06).
@export var base_output_per_worker: float = 0.0
@export var output_good_id: String = ""
@export var input1_good_id: String = ""
## 定點數 — stored as float (D-18a; was int in 10-06).
@export var input1_qty: float = 0.0
@export var input2_good_id: String = ""
## 定點數 — stored as float (D-18a; was int in 10-06).
@export var input2_qty: float = 0.0
## Enum: RESIDENCE／WAREHOUSE／IND1／IND2／IND3／PUBLIC／KONTOR (TechSpec 10-06 ②).
@export var build_class: String = ""
