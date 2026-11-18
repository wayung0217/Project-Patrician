class_name BuildStep
extends Resource
## WP-17 build-queue step row (TechSpec 10-05 / 04_Content §7 build_queue headers).

@export var port_id: String = ""
@export var step: int = 0
## Format ^CB-[0-9]{2}$ (TechSpec 10-06 ③).
@export var cb_id: String = ""
@export var target_level: int = 0
