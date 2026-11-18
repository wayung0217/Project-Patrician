class_name Slot
extends RefCounted
## ST-SLOT row (03_Systems SYS-08 D / TechSpec 11-03).

enum Kind { CIVIL, PUBLIC, KONTOR }

var slot_id: StringName = &""
var kind: Kind = Kind.CIVIL
var port_id: String = ""
var zone: int = 0
var ring: int = 0
var land_owner: StringName = &""
var building_id: StringName = &""
var zone_open: bool = false
## FRM-04／FRM-23: day demolish cleared the slot (−1 = occupied／never vacant).
var vacancy_start_day: int = -1