class_name SimBrokerFixture
extends BrokerProvider
## D-60f／WP-40: deny-all BrokerProvider for sim CLI／WP26／formal L1 probe boots.
## Not a formal always-allow product provider — kontor／qualification always false.
## Formal BrokerDesk (WP-41) replaces this injection site.


func has_kontor(_actor_id: StringName, _port_id: StringName) -> bool:
	return false


func is_broker_qualified(_actor_id: StringName, _port_id: StringName) -> bool:
	return false
