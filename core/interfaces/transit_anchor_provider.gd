class_name TransitAnchorProvider
extends RefCounted
## SYS-15 TransitAnchorProvider interface (TechSpec 3.5 D／H／D-08h).
## Formal formula is SYS-15; Phase 0 has no provider — MarketPricer returns ERR-SYS04-07 for TRANSIT.
## Success: anchor_price_li > 0; failure: 0 + last_error() (never invent freight／ratios).

## Failure sentinel — not a valid anchor (D-08h: success must be > 0).
const ANCHOR_FAILURE := 0

const SYS_ID := &"SYS-15"
const CODE_BASE_UNIMPLEMENTED := &"TRANSIT_ANCHOR_UNIMPLEMENTED"
const FIELD_METHOD := "anchor_price_li"

var _last_error: Dictionary = {}


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func anchor_price_li(_port_id: StringName, _good_id: StringName) -> int:
	# D-08h: base body always fails; SYS-15 overrides. Do not return a fake positive price.
	push_error("TransitAnchorProvider.anchor_price_li: base interface called; override required (2.1-03／D-08h)")
	_last_error = ErrorInfoUtil.make(CODE_BASE_UNIMPLEMENTED, SYS_ID, {
		ErrorInfoUtil.DETAIL_FIELD: FIELD_METHOD,
		ErrorInfoUtil.DETAIL_MESSAGE: "base TransitAnchorProvider has no formula; SYS-15 must override",
	})
	return ANCHOR_FAILURE
