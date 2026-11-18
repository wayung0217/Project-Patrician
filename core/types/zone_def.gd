class_name ZoneDef
extends Resource
## WP-17 zone row (TechSpec 10-05 / 04_Content §7 zones headers).

@export var port_id: String = ""
@export var zone: int = 0
## 定點數 — stored as float (same as WP-01 FREE_PORT_RATIO / TechSpec 10-06).
@export var slot_share: float = 0.0
@export var rings: int = 0
## CIVIL slot count for zone (D-11a); from zones.csv slots.
@export var slots: int = 0
## 0／1 only (TechSpec 10-06 ④); stored as int, not bool.
@export var open_at_start: int = 0
