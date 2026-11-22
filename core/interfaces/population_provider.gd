class_name PopulationProvider
extends RefCounted
## SYS-08 PopulationProvider interface (TechSpec D-11d / 2.1-03).
## Formal implementation is PopulationModel (WP-21); WP-18 uses test doubles only.

## Failure sentinel — not a real population (2.1-03).
const POPULATION_FAILURE := -1 ## EX-02 failure sentinel


func population(_port_id: StringName) -> int:
	push_error(
		"PopulationProvider.population: base interface called; override required (2.1-03)"
	)
	return POPULATION_FAILURE