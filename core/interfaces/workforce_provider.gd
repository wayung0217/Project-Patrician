class_name WorkforceProvider
extends RefCounted
## SYS-08 WorkforceProvider interface (TechSpec D-12c / 12-09).
## Formal implementation is PopulationModel (WP-21); WP-20 uses test doubles only.

## Failure sentinel — not a real worker count (D-12c).
const WORKERS_FAILURE := 0 - 1


func workers(_ws_id: StringName) -> int:
	push_error(
		"WorkforceProvider.workers: base interface called; override required (D-12c)"
	)
	return WORKERS_FAILURE
