class_name SeaLane
extends Resource
## SYS-14 sea lane (D-14e / 04_Content 8.4).
## length is stored for reference only; pathfinding uses waypoints (13-04).

const TYPE_SPUR := "SPUR"
const TYPE_TRUNK := "TRUNK"
const TYPE_NEIGHBOR := "NEIGHBOR"

@export var lane_id: String = ""
@export var node_a: String = ""
@export var node_b: String = ""
@export var region_id: String = ""
@export var length: float = 0.0
@export var waypoints: int = 0
@export var lane_type: String = ""
