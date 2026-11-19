class_name Ship
extends RefCounted
## SYS-13 ST-SHIP row (03_Systems 10.5 D). Not a Resource — runtime only.

const STATE_DOCKED := &"DOCKED"
const STATE_SAILING := &"SAILING"

const TYPE_SH01 := &"SH-01"
const TYPE_SH02 := &"SH-02"
const TYPE_SH03 := &"SH-03"
const TYPE_SH04 := &"SH-04"

var ship_id: StringName = &""
var type: StringName = TYPE_SH01
var owner: StringName = &""
var crew: int = 0
var state: StringName = STATE_DOCKED
## DOCKED port; empty while SAILING.
var port_id: StringName = &""
## Season hold-start day for repair proration (FRM-SYS13-08).
var held_from_day: int = 0
## Accrued wage in 1/7-li units (FRM-SYS13-07).
var acc_wage: int = 0

## Voyage (only meaningful while SAILING).
var origin_port: StringName = &""
var dest_port: StringName = &""
var path: Array = [] ## Array[{lane_id, from_node}]
var leg_start_tick: int = 0
var arrival_tick: int = 0
var last_port_departure_tick: int = 0
## Waypoints already completed along `path` at `leg_start_tick` (FRM-SYS14-05).
var wp_offset: int = 0


func hold_container_id() -> StringName:
	return StringName(GoodsLedger.CONTAINER_ID_FMT_HOLD % String(ship_id))


func to_info() -> Dictionary:
	return {
		"ship_id": ship_id,
		"type": type,
		"owner": owner,
		"crew": crew,
		"state": state,
		"port_id": port_id,
		"held_from_day": held_from_day,
		"acc_wage": acc_wage,
		"origin_port": origin_port,
		"dest_port": dest_port,
		"leg_start_tick": leg_start_tick,
		"arrival_tick": arrival_tick,
		"last_port_departure_tick": last_port_departure_tick,
	}
