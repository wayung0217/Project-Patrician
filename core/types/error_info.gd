class_name ErrorInfoUtil
extends RefCounted
## D-04 / C-06 shared error carrier.
## Shape: {code: StringName, sys: StringName, detail: Dictionary}.
## Named ErrorInfoUtil so Dictionary values are not confused with a class instance.
## Call sites build/return Dictionary via make(); never ERR→int (D-04).

const KEY_CODE := "code"
const KEY_SYS := "sys"
const KEY_DETAIL := "detail"

const DETAIL_FILE := "file"
const DETAIL_FIELD := "field"
const DETAIL_VALUE := "value"
const DETAIL_MESSAGE := "message"


static func make(code: StringName, sys: StringName, detail: Dictionary = {}) -> Dictionary:
	return {
		KEY_CODE: code,
		KEY_SYS: sys,
		KEY_DETAIL: detail.duplicate(),
	}


static func make_validation(
	code: StringName,
	sys: StringName,
	file_path: String,
	field: String,
	value: Variant,
	message: String
) -> Dictionary:
	# C-06 detail: 檔案、欄位、值 (+ message for H observability).
	return make(code, sys, {
		DETAIL_FILE: file_path,
		DETAIL_FIELD: field,
		DETAIL_VALUE: value,
		DETAIL_MESSAGE: message,
	})
