class_name Building
extends RefCounted
## ST-BUILDING (03_Systems 8.6 D / TechSpec §12 WP-19).

enum State { WAITING_MATERIAL, BUILDING, ACTIVE, PAUSED }

var building_id: StringName = &""
var type: StringName = &""
var build_class: StringName = &""
var owner: StringName = &""
var port_id: String = ""
var slot_id: StringName = &""
var level: int = 1
var state: int = State.WAITING_MATERIAL
var days_left: int = 0
## good_id:String → int already acquired for this order.
var locked_materials: Dictionary = {}
## good_id:String → int still missing (WAITING_MATERIAL).
var missing_materials: Dictionary = {}
var acc_out: int = 0
var acc_wage_li: int = 0
var acc_rent_li: int = 0
## Public building cb_id (CB-xx); empty for non-public.
var cb_id: StringName = &""
