class_name SeaNode
extends Resource
## SYS-14 sea chart node (D-14e / 04_Content 8.2).

const KIND_PORT := "PORT"
const KIND_JUNCTION := "JUNCTION"

@export var node_id: String = ""
@export var kind: String = ""
@export var name_zh: String = ""
@export var x: int = 0
@export var y: int = 0
