@tool
extends EditorScript
## CSV → Resource converter framework (05_TechSpec 2.1-04).
## Validates CSV against 03_Systems data-structure field names/types.
## Public API is static so headless GUT can call without instantiating EditorScript.
## Does not invent formal .tres output: Resource scripts arrive in later WPs.

const FIXTURES_PREFIX := "res://tests/fixtures/"
const DATA_PREFIX := "res://data/"

## Resource kinds — one kind per CSV (2.1-04 ①).
const KIND_GOOD_DEF := "GoodDef"
const KIND_PORT_DEF := "PortDef"

## Column type tags — wording mirrors 03_Systems type column (String / int / bool).
const COL_TYPE_STRING := "String"
const COL_TYPE_INT := "int"
const COL_TYPE_BOOL := "bool"

const BOOL_TRUE := "true"
const BOOL_FALSE := "false"

## GoodDef fields — 03_Systems r234–r241 / 05_TechSpec §3.2 D 欄位.
const GOOD_DEF_FIELDS: Array[Dictionary] = [
	{"name": "good_id", "type": COL_TYPE_STRING},
	{"name": "name_zh", "type": COL_TYPE_STRING},
	{"name": "tier", "type": COL_TYPE_INT},
	{"name": "is_staple", "type": COL_TYPE_BOOL},
	{"name": "is_build_material", "type": COL_TYPE_BOOL},
	{"name": "is_strategic", "type": COL_TYPE_BOOL},
	{"name": "base_price_li", "type": COL_TYPE_INT},
	{"name": "season_mask", "type": COL_TYPE_INT},
]

## PortDef fields — 03_Systems r256–r260 / 05_TechSpec §3.3 D 欄位 PortDef.
## draft_limit_class: enum UNIT-DRAFT stored as int cell pending SYS-13 (TechSpec D83).
const PORT_DEF_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "name_zh", "type": COL_TYPE_STRING},
	{"name": "is_free_port", "type": COL_TYPE_BOOL},
	{"name": "draft_limit_class", "type": COL_TYPE_INT},
	{"name": "regime_id", "type": COL_TYPE_STRING},
]


func _run() -> void:
	## Editor entry; batch paths are not specified in 05_TechSpec 2.1-04.
	## Owner pipeline / callers must invoke CsvImport.import_csv(path, resource_kind).
	pass


## Returns schema field list for a resource kind, or empty if unknown.
static func schema_for(resource_kind: String) -> Array[Dictionary]:
	if resource_kind == KIND_GOOD_DEF:
		return GOOD_DEF_FIELDS
	if resource_kind == KIND_PORT_DEF:
		return PORT_DEF_FIELDS
	return []


## Expected header names in schema order (2.1-04 ②).
static func expected_headers(resource_kind: String) -> PackedStringArray:
	var fields: Array[Dictionary] = schema_for(resource_kind)
	var headers: PackedStringArray = PackedStringArray()
	for field in fields:
		headers.append(String(field["name"]))
	return headers


## True when path is under res://tests/fixtures/ (2.1-04 ④).
static func is_fixture_path(path: String) -> bool:
	return path.begins_with(FIXTURES_PREFIX)


## True when path is under res://data/ (formal data; 2.1-04 ⑤ / N-09).
static func is_formal_data_path(path: String) -> bool:
	return path.begins_with(DATA_PREFIX)


## Import one CSV as one resource kind (2.1-04 ①).
## On 缺欄／多欄／型別不符: push_error each issue, abort (ok=false), no row output (2.1-04 ③, C-06).
## Result keys: ok (bool), errors (PackedStringArray), rows (Array[Dictionary]), resource_kind (String).
static func import_csv(csv_path: String, resource_kind: String) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": PackedStringArray(),
		"rows": [],
		"resource_kind": resource_kind,
	}
	var errors: PackedStringArray = PackedStringArray()

	var fields: Array[Dictionary] = schema_for(resource_kind)
	if fields.is_empty():
		# 2.1-04 ① — unknown / unsupported kind for this CSV.
		errors.append(
			"2.1-04: unknown resource_kind '%s' (one resource kind per CSV)" % resource_kind
		)
		return _abort_with_errors(result, errors)

	if not FileAccess.file_exists(csv_path):
		errors.append("2.1-04: CSV not found: %s" % csv_path)
		return _abort_with_errors(result, errors)

	var file: FileAccess = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		errors.append(
			"2.1-04: cannot open CSV: %s (err=%s)"
			% [csv_path, str(FileAccess.get_open_error())]
		)
		return _abort_with_errors(result, errors)

	var header_line: PackedStringArray = file.get_csv_line()
	_collect_header_errors(header_line, fields, errors)

	var raw_rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if _is_trailing_eof_blank(file, line):
			break
		raw_rows.append(line)
	file.close()

	if not errors.is_empty():
		return _abort_with_errors(result, errors)

	# Pass 1: collect every type / column-count error (C-06), then abort if any.
	var row_index: int = 0
	for line in raw_rows:
		row_index += 1
		_collect_row_type_errors(line, fields, row_index, errors)

	if not errors.is_empty():
		# 2.1-04 ③ — type mismatch aborts; no partial row output.
		return _abort_with_errors(result, errors)

	# Pass 2: parse only after the whole CSV is known-valid.
	var parsed_rows: Array[Dictionary] = []
	for line in raw_rows:
		parsed_rows.append(_parse_row(line, fields))

	result["ok"] = true
	result["errors"] = PackedStringArray()
	result["rows"] = parsed_rows
	return result


static func _abort_with_errors(result: Dictionary, errors: PackedStringArray) -> Dictionary:
	for message in errors:
		push_error(message)
	result["ok"] = false
	result["errors"] = errors
	result["rows"] = []
	return result


static func _collect_header_errors(
	header_line: PackedStringArray,
	fields: Array[Dictionary],
	errors: PackedStringArray
) -> void:
	var expected: PackedStringArray = PackedStringArray()
	for field in fields:
		expected.append(String(field["name"]))

	# 2.1-04 ② — headers must equal field names exactly (order + spelling).
	var expected_set: Dictionary = {}
	for name in expected:
		expected_set[name] = true

	var actual_set: Dictionary = {}
	for name in header_line:
		actual_set[name] = true

	# 2.1-04 ③ 缺欄 — collect all missing (C-06).
	for name in expected:
		if not actual_set.has(name):
			errors.append("2.1-04 ③ missing column: %s" % name)

	# 2.1-04 ③ 多欄 — collect all extras (C-06).
	for name in header_line:
		if not expected_set.has(name):
			errors.append("2.1-04 ③ extra column: %s" % name)

	# Exact sequence check when sizes already match set-wise (wrong order / duplicate).
	if errors.is_empty():
		if header_line.size() != expected.size():
			errors.append(
				"2.1-04 ② header count mismatch: got %s expected %s"
				% [str(header_line.size()), str(expected.size())]
			)
		else:
			var index: int = 0
			while index < expected.size():
				if header_line[index] != expected[index]:
					errors.append(
						"2.1-04 ② header mismatch at index %s: got '%s' expected '%s'"
						% [str(index), header_line[index], expected[index]]
					)
				index += 1


static func _collect_row_type_errors(
	line: PackedStringArray,
	fields: Array[Dictionary],
	row_index: int,
	errors: PackedStringArray
) -> void:
	if line.size() != fields.size():
		# Column count drift after a valid header — treat as 缺欄／多欄 abort.
		errors.append(
			"2.1-04 ③ row %s column count mismatch: got %s expected %s"
			% [str(row_index), str(line.size()), str(fields.size())]
		)
		return

	var index: int = 0
	while index < fields.size():
		var field: Dictionary = fields[index]
		var field_name: String = String(field["name"])
		var field_type: String = String(field["type"])
		var cell: String = line[index]
		if not _cell_matches_type(cell, field_type):
			# 2.1-04 ③ 型別不符 — no ERR ID assigned for csv_import in TechSpec.
			errors.append(
				"2.1-04 ③ type mismatch row %s field %s type %s value '%s'"
				% [str(row_index), field_name, field_type, cell]
			)
		index += 1


static func _parse_row(line: PackedStringArray, fields: Array[Dictionary]) -> Dictionary:
	var row: Dictionary = {}
	var index: int = 0
	while index < fields.size():
		var field: Dictionary = fields[index]
		var field_name: String = String(field["name"])
		var field_type: String = String(field["type"])
		row[field_name] = _parse_cell(line[index], field_type)
		index += 1
	return row


static func _cell_matches_type(cell: String, field_type: String) -> bool:
	if field_type == COL_TYPE_STRING:
		return true
	if field_type == COL_TYPE_INT:
		return cell.is_valid_int()
	if field_type == COL_TYPE_BOOL:
		return cell == BOOL_TRUE or cell == BOOL_FALSE
	return false


static func _parse_cell(cell: String, field_type: String) -> Variant:
	if field_type == COL_TYPE_INT:
		return cell.to_int()
	if field_type == COL_TYPE_BOOL:
		return cell == BOOL_TRUE
	return cell


static func _is_trailing_eof_blank(file: FileAccess, line: PackedStringArray) -> bool:
	return file.eof_reached() and line.size() == 1 and line[0] == ""
