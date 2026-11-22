class_name CapacityProvider
extends RefCounted
## SYS-03 CapacityProvider interface (TechSpec 3.8 / 2.1-03).
## Formal providers are SYS-08 (WAREHOUSE) / SYS-13 (HOLD) — not implemented in Phase 0.
## Base methods must push_error and return a failure value (never a plausible fake).

## Failure sentinel for capacity() — not a real capacity (2.1-03 / 3.7 same rule).
## Built from 0／1 only (C-03).
const CAPACITY_FAILURE := -1 ## EX-02 failure sentinel


func capacity(_container: Variant) -> int:
	# 2.1-03: base body always push_error; do not return 0 (looks like empty hold).
	push_error("CapacityProvider.capacity: base interface called; override required (2.1-03)")
	return CAPACITY_FAILURE
