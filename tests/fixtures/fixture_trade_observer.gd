class_name FixtureTradeObserver
extends TradeObserver
## Test-only TradeObserver (N-05: not a product always-allow Autoload).
## Records calls for TST evidence; fail_next forces a non-rollback observer failure.


var records: Array = [] ## {actor,port,good,side,qty,mid_before,mid_after,seq}
var fail_next: bool = false
var fail_always: bool = false


func record_trade(
	actor_id: StringName,
	port_id: StringName,
	good_id: StringName,
	side: int,
	qty: int,
	mid_before: float,
	mid_after: float,
	seq: int
) -> int:
	records.append({
		"actor": actor_id,
		"port": port_id,
		"good": good_id,
		"side": side,
		"qty": qty,
		"mid_before": mid_before,
		"mid_after": mid_after,
		"seq": seq,
	})
	if fail_always or fail_next:
		fail_next = false
		push_error("FixtureTradeObserver: forced failure (trade must not roll back)")
		return RECORD_FAIL
	return RECORD_OK
