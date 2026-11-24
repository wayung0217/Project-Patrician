class_name SimQualificationOpenFixture
extends QualificationProvider
## D-120(f)／17-58 F1: QUAL_OPEN always-allow fixture — sim/ only.
## Limited exception to D-63b 「一律放行的替身一律不准」: inject only when
## scenario layers.QUAL_OPEN＝1 via sim_engine. Formal boot must never load this
## class (grep: only sim_engine QUAL_OPEN branch). WP-35 TierRegistry replaces it.


func can_enter(_actor_id: StringName, _port_id: StringName) -> bool:
	_last_error = {}
	return true


func can_trade(
	_actor_id: StringName, _port_id: StringName, _good_id: StringName, _side: int
) -> bool:
	_last_error = {}
	return true


func can_build(_actor_id: StringName, _port_id: StringName) -> bool:
	_last_error = {}
	return true
