class_name ConsumptionProvider
extends RefCounted
## SYS-06 ConsumptionProvider interface (TechSpec 3.7 / B2).
## Formal implementation is SYS-06; Phase 0 uses test doubles only (1-A9／WP-08 wires SimLoop).
## Base methods must push_error and return a failure value (never 0 — 0 is valid weekly_consumption).

## Failure sentinel for weekly_consumption／consume_qty — not a real quantity (2.1-03).
## Built from 0／1 only (C-03).
const CONSUMPTION_FAILURE := 0 - 1


func weekly_consumption(_port_id: StringName, _good_id: StringName) -> int:
	# TechSpec 3.7: returns int ≥ 0; cast to float only when computing w (B2 / FRM-SYS04-01).
	# 2.1-03: base body always push_error; do not return 0 (valid zero-consumption).
	push_error("ConsumptionProvider.weekly_consumption: base interface called; override required (2.1-03)")
	return CONSUMPTION_FAILURE


func consume_qty(_port_id: StringName, _good_id: StringName, _day: int) -> int:
	# Formal consume is SYS-06; WP-08 SimLoop calls this. Base must fail loudly.
	push_error("ConsumptionProvider.consume_qty: base interface called; override required (2.1-03)")
	return CONSUMPTION_FAILURE
