class_name SimTradeObserverFixture
extends TradeObserver
## D-63b／WP-33: no-op／deny TradeObserver for sim CLI／WP26／formal L1 probe boots.
## Does not record, does not return RECORD_OK, and never mutates cash／goods.
## Formal ReputationLedger／TaxLedger (D-33b／D-42) replace this injection site.


func record_trade(
	_actor_id: StringName,
	_port_id: StringName,
	_good_id: StringName,
	_side: int,
	_qty: int,
	_mid_before: float,
	_mid_after: float,
	_seq: int
) -> int:
	## D-63b: refuse to acknowledge；no side effects.
	return RECORD_FAIL
