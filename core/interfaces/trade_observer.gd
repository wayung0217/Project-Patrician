class_name TradeObserver
extends RefCounted
## SYS-11／SYS-12 TradeObserver interface (03_Systems 22.1 H / 2.1-03).
## Formal observers: ReputationLedger then TaxLedger (D-33b／D-42).
## WP-33 builds the ordered-list mechanism; tests use fixture observers only (N-05).

const SYS_ID := &"SYS-05"
const SCRIPT_PATH := "res://core/interfaces/trade_observer.gd"

## Success／failure literals use only 0／1 (C-03).
const RECORD_OK := 0
const RECORD_FAIL := 1

const ERR_BASE_CALLED := &"ERR-TRADE-OBSERVER-BASE"


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
	# 2.1-03: base body always push_error; return failure sentinel.
	push_error(
		"TradeObserver.record_trade: base interface called; override required (2.1-03)"
	)
	return RECORD_FAIL
