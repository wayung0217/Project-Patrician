class_name SailorPoolProvider
extends RefCounted
## SYS-13 SailorPoolProvider interface (TechSpec D-14b / 03_Systems 10.5 B).
## Formal implementation is PopulationModel adapter (WP-30); tests may inject fixtures.

## Failure sentinel — not a real beggar count (2.1-03).
const BEGGARS_FAILURE := -1 ## EX-02 failure sentinel


func beggars(_port_id: StringName) -> int:
	push_error(
		"SailorPoolProvider.beggars: base interface called; override required (D-14b)"
	)
	return BEGGARS_FAILURE


func hire_sailors(_port_id: StringName, _n: int) -> int:
	## Success returns n; failure returns 0 (D-14b).
	push_error(
		"SailorPoolProvider.hire_sailors: base interface called; override required (D-14b)"
	)
	return 0


func release_sailors(_port_id: StringName, _n: int) -> int:
	## Success returns n; failure returns 0 (D-14b).
	push_error(
		"SailorPoolProvider.release_sailors: base interface called; override required (D-14b)"
	)
	return 0
