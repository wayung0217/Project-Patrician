class_name QualificationProvider
extends RefCounted
## SYS-09 QualificationProvider interface (03_Systems 19.1 H / 2.1-03).
## Formal provider is TierRegistry (WP-35); WP-33 tests use fixtures only (N-05).
## Base methods push_error and return false + ErrorInfo via last_error().

const SYS_ID := &"SYS-09"
const SCRIPT_PATH := "res://core/interfaces/qualification_provider.gd"

const ERR_SYS09_08 := &"ERR-SYS09-08"
const ERR_SYS09_09 := &"ERR-SYS09-09"
const ERR_BASE_CALLED := &"ERR-QUALIFICATION-BASE"

var _last_error: Dictionary = {}


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func can_enter(_actor_id: StringName, _port_id: StringName) -> bool:
	# 2.1-03: base body always push_error; never return a plausible allow.
	_fail(
		ERR_BASE_CALLED,
		"can_enter",
		null,
		"QualificationProvider.can_enter: base interface called; override required (2.1-03)"
	)
	return false


func can_trade(
	_actor_id: StringName, _port_id: StringName, _good_id: StringName, _side: int
) -> bool:
	_fail(
		ERR_BASE_CALLED,
		"can_trade",
		null,
		"QualificationProvider.can_trade: base interface called; override required (2.1-03)"
	)
	return false


func can_build(_actor_id: StringName, _port_id: StringName) -> bool:
	_fail(
		ERR_BASE_CALLED,
		"can_build",
		null,
		"QualificationProvider.can_build: base interface called; override required (2.1-03)"
	)
	return false


func _fail(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = ErrorInfoUtil.make_validation(
		code, SYS_ID, SCRIPT_PATH, field, value, message
	)
	push_error("QualificationProvider: %s" % str(_last_error))
