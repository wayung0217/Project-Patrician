class_name SimQualificationFixture
extends QualificationProvider
## D-63b／WP-33: deny-all QualificationProvider for sim CLI／WP26／formal L1 probe boots.
## Not a formal always-allow product provider — can_enter／can_trade／can_build always false.
## Formal TierRegistry (WP-35) replaces this injection site.


func can_enter(_actor_id: StringName, port_id: StringName) -> bool:
	_fail(
		ERR_SYS09_08,
		"port_id",
		port_id,
		"SimQualificationFixture.can_enter denied (D-63b)"
	)
	return false


func can_trade(
	_actor_id: StringName, _port_id: StringName, good_id: StringName, _side: int
) -> bool:
	_fail(
		ERR_SYS09_09,
		"good_id",
		good_id,
		"SimQualificationFixture.can_trade denied (D-63b)"
	)
	return false


func can_build(_actor_id: StringName, port_id: StringName) -> bool:
	_fail(
		ERR_SYS09_08,
		"port_id",
		port_id,
		"SimQualificationFixture.can_build denied (D-63b)"
	)
	return false
