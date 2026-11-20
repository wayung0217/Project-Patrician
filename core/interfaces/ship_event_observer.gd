class_name ShipEventObserver
extends RefCounted
## SYS-15 ShipEventObserver (03_Systems 25.1 H／D-34d／2.1-03).
## Formal implementation: IntelLedger adapter; tests may inject fixtures.


func on_departed(
	_ship_id: StringName, _owner_id: StringName, _from_port_id: StringName, _tick: int
) -> void:
	push_error(
		"ShipEventObserver.on_departed: base interface called; override required (2.1-03)"
	)


func on_arrivals(_tick: int, _arrivals: Array) -> void:
	## arrivals: Array of {ship_id, owner_id, port_id, from_port_id}, ship_id ascending.
	push_error(
		"ShipEventObserver.on_arrivals: base interface called; override required (2.1-03)"
	)
