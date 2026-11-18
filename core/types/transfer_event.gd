class_name TransferEvent
extends RefCounted
## EV-SYS03-TRANSFER (03_Systems r284 / TechSpec 3.4 D).
## timestamp == seq (Owner 2026-11-17); never Time.get_ticks_* (C-08).

var seq: int = 0
var day: int = 0
var timestamp: int = 0
var from: Variant = null
var to: Variant = null
var good_id: StringName = &""
var qty: int = 0
var reason: StringName = &""
var requester: StringName = &""
