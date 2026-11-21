class_name BrokerProvider
extends RefCounted
## SYS-15／SYS-16 BrokerProvider interface (D-60f／2.1-03).
## Formal provider is BrokerDesk (WP-41); WP-40 tests use fixtures only (N-05).
## Base methods push_error and return false + ErrorInfo via last_error().

const SYS_ID := &"SYS-16"
const SCRIPT_PATH := "res://core/interfaces/broker_provider.gd"

const ERR_BASE_CALLED := &"ERR-BROKER-PROVIDER-BASE"

var _last_error: Dictionary = {}


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func has_kontor(_actor_id: StringName, _port_id: StringName) -> bool:
	# 2.1-03: base body always push_error; never return a plausible allow.
	_fail(
		ERR_BASE_CALLED,
		"has_kontor",
		null,
		"BrokerProvider.has_kontor: base interface called; override required (2.1-03)"
	)
	return false


func is_broker_qualified(_actor_id: StringName, _port_id: StringName) -> bool:
	_fail(
		ERR_BASE_CALLED,
		"is_broker_qualified",
		null,
		"BrokerProvider.is_broker_qualified: base interface called; override required (2.1-03)"
	)
	return false


func _fail(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = ErrorInfoUtil.make_validation(
		code, SYS_ID, SCRIPT_PATH, field, value, message
	)
	push_error("BrokerProvider: %s" % str(_last_error))
