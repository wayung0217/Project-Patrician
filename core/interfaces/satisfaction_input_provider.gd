class_name SatisfactionInputProvider
extends RefCounted
## SYS-07 SatisfactionInputProvider (TechSpec D-17c). DemandModel (WP-22) is the formal impl.

const INPUT_FAILURE := -1.0


func satisfaction_input(_port_id: StringName, _clazz: StringName) -> float:
	push_error(
		"SatisfactionInputProvider.satisfaction_input: base interface called; override required (D-17c)"
	)
	return INPUT_FAILURE
