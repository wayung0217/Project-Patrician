class_name SimJsonInt
extends RefCounted
## C-06 — restore JSON／Variant integers; reject non-integral floats (no silent floori).


static func is_json_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	if typeof(v) == TYPE_FLOAT:
		var f: float = float(v)
		return f == floorf(f)
	return false


static func as_int(v: Variant, field: String = "value") -> int:
	## int → as-is; integral float → floori; non-integral → push_error + 0 (C-06).
	if typeof(v) == TYPE_INT:
		return v
	if is_json_int(v):
		return floori(float(v))
	push_error("SimJsonInt: non-integral rejected for %s: %s" % [field, str(v)])
	return 0
