class_name FixtureQualificationProvider
extends QualificationProvider
## Test-only QualificationProvider (N-05: not a product always-allow Autoload).
## Default: allow all. Tests flip deny_enter／deny_trade for TST-SYS05-16／17.


var deny_enter: bool = false
var deny_trade: bool = false
var enter_calls: Array = []
var trade_calls: Array = []


func can_enter(actor_id: StringName, port_id: StringName) -> bool:
	enter_calls.append({"actor": actor_id, "port": port_id})
	if deny_enter:
		_fail(
			ERR_SYS09_08,
			"port_id",
			port_id,
			"fixture can_enter denied"
		)
		return false
	_last_error = {}
	return true


func can_trade(
	actor_id: StringName, port_id: StringName, good_id: StringName, side: int
) -> bool:
	trade_calls.append({
		"actor": actor_id, "port": port_id, "good": good_id, "side": side
	})
	if deny_trade:
		_fail(
			ERR_SYS09_09,
			"good_id",
			good_id,
			"fixture can_trade denied"
		)
		return false
	_last_error = {}
	return true


func can_build(_actor_id: StringName, _port_id: StringName) -> bool:
	_last_error = {}
	return true
