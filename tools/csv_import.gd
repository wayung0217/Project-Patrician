@tool
extends EditorScript
## CSV → Resource converter framework (05_TechSpec 2.1-04 + D-08i).
## Validates CSV against 03_Systems data-structure field names/types.
## Public API is static so headless GUT can call without instantiating EditorScript.
## D-08i: fixed in/out paths; validate all four CSVs then write all-or-nothing; clear old outputs first.

const FIXTURES_PREFIX := "res://tests/fixtures/"
const DATA_PREFIX := "res://data/"

## D-08i fixed import directory (allowed by TechSpec 2.1-04 / D-08i).
const IMPORT_DIR := "res://data/import/"
const IMPORT_GOODS_CSV := IMPORT_DIR + "goods.csv"
const IMPORT_PORTS_CSV := IMPORT_DIR + "ports.csv"
const IMPORT_ROLE_CELLS_CSV := IMPORT_DIR + "role_cells.csv"
const IMPORT_PRICE_CURVE_CSV := IMPORT_DIR + "price_curve.csv"

## D-08i fixed output roots.
const GOODS_OUT_DIR := "res://data/goods/"
const PORTS_OUT_DIR := "res://data/ports/"
const MARKET_OUT_DIR := "res://data/market/"
const PRICE_CURVE_OUT_PATH := MARKET_OUT_DIR + "price_curve.tres"

## Resource kinds — one kind per CSV (2.1-04 ①).
const KIND_GOOD_DEF := "GoodDef"
const KIND_PORT_DEF := "PortDef"
const KIND_ROLE_CELL := "RoleCell"
const KIND_PRICE_CURVE := "PriceCurve"

## Column type tags — wording mirrors 03_Systems type column.
const COL_TYPE_STRING := "String"
const COL_TYPE_INT := "int"
const COL_TYPE_BOOL := "bool"
const COL_TYPE_FLOAT := "float"
## Array[port_id] cell encoding for RoleCell.downstream_terminals (03_Systems r262).
## Delimiter is a named constant; encoding not further specified in D-08i (C-05 note in PR).
const COL_TYPE_ARRAY_STRING := "Array[String]"

const BOOL_TRUE := "true"
const BOOL_FALSE := "false"

## RoleCell.role CSV labels — 03_Systems r261 enum order PRODUCER／TRANSIT／TERMINAL.
const ROLE_NAME_PRODUCER := "PRODUCER"
const ROLE_NAME_TRANSIT := "TRANSIT"
const ROLE_NAME_TERMINAL := "TERMINAL"
## Int values match PortRegistry.Role declaration order (0／1／2).
const ROLE_VALUE_PRODUCER := 0
const ROLE_VALUE_TRANSIT := 1
const ROLE_VALUE_TERMINAL := 2

## Array cell delimiter for downstream_terminals (join／split).
const ARRAY_CELL_SEPARATOR := ";"

const TRES_SUFFIX := ".tres"
const CSV_SUFFIX := ".csv"

## Filenames inside IMPORT_DIR (D-08i).
const FILE_GOODS := "goods.csv"
const FILE_PORTS := "ports.csv"
const FILE_ROLE_CELLS := "role_cells.csv"
const FILE_PRICE_CURVE := "price_curve.csv"

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
## role_cells are supplied by role_cells.csv (D-08i), not ports.csv columns.
const PORT_DEF_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "name_zh", "type": COL_TYPE_STRING},
	{"name": "is_free_port", "type": COL_TYPE_BOOL},
	{"name": "draft_limit_class", "type": COL_TYPE_INT},
	{"name": "regime_id", "type": COL_TYPE_STRING},
]

## RoleCell import rows — 03_Systems r261–r263 plus join keys required by D-08i
## (ports/<port_id>.tres keyed by good_id). Join keys reuse PortDef／GoodDef id field names.
const ROLE_CELL_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "good_id", "type": COL_TYPE_STRING},
	{"name": "role", "type": COL_TYPE_STRING},
	{"name": "downstream_terminals", "type": COL_TYPE_ARRAY_STRING},
	{"name": "base_output_per_season", "type": COL_TYPE_INT},
]

## PriceCurve breakpoints — 03_Systems r402 `[{weeks, mult}]`.
const PRICE_CURVE_FIELDS: Array[Dictionary] = [
	{"name": "weeks", "type": COL_TYPE_FLOAT},
	{"name": "mult", "type": COL_TYPE_FLOAT},
]


func _run() -> void:
	## D-08i: EditorScript entry uses fixed in/out paths only.
	var result: Dictionary = run_batch()
	if result["ok"]:
		print("csv_import D-08i: wrote %s resources" % str((result["written"] as Array).size()))
	else:
		push_error("csv_import D-08i: aborted with %s error(s)" % str((result["errors"] as PackedStringArray).size()))


## Returns schema field list for a resource kind, or empty if unknown.
static func schema_for(resource_kind: String) -> Array[Dictionary]:
	if resource_kind == KIND_GOOD_DEF:
		return GOOD_DEF_FIELDS
	if resource_kind == KIND_PORT_DEF:
		return PORT_DEF_FIELDS
	if resource_kind == KIND_ROLE_CELL:
		return ROLE_CELL_FIELDS
	if resource_kind == KIND_PRICE_CURVE:
		return PRICE_CURVE_FIELDS
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
## On 缺欄／多欄／型別不符: abort (ok=false), no row output (2.1-04 ③, C-06).
## When emit_push_errors is true (default), push_error once per issue.
## D-08i batch sets emit_push_errors=false and emits once via run_batch.
## Result keys: ok (bool), errors (PackedStringArray), rows (Array[Dictionary]), resource_kind (String).
static func import_csv(
	csv_path: String,
	resource_kind: String,
	emit_push_errors: bool = true
) -> Dictionary:
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
		return _abort_with_errors(result, errors, emit_push_errors)

	if not FileAccess.file_exists(csv_path):
		errors.append("2.1-04: CSV not found: %s" % csv_path)
		return _abort_with_errors(result, errors, emit_push_errors)

	var file: FileAccess = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		errors.append(
			"2.1-04: cannot open CSV: %s (err=%s)"
			% [csv_path, str(FileAccess.get_open_error())]
		)
		return _abort_with_errors(result, errors, emit_push_errors)

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
		return _abort_with_errors(result, errors, emit_push_errors)

	# Pass 1: collect every type / column-count error (C-06), then abort if any.
	var row_index: int = 0
	for line in raw_rows:
		row_index += 1
		_collect_row_type_errors(line, fields, row_index, errors)

	if not errors.is_empty():
		# 2.1-04 ③ — type mismatch aborts; no partial row output.
		return _abort_with_errors(result, errors, emit_push_errors)

	# Pass 2: parse only after the whole CSV is known-valid.
	var parsed_rows: Array[Dictionary] = []
	for line in raw_rows:
		parsed_rows.append(_parse_row(line, fields))

	result["ok"] = true
	result["errors"] = PackedStringArray()
	result["rows"] = parsed_rows
	return result


## D-08i batch: validate goods／ports／role_cells／price_curve, then clear＋write all-or-nothing.
## Defaults are the fixed formal paths; tests may pass fixture／temp roots (2.1-04 ④).
## Result keys: ok (bool), errors (PackedStringArray), written (PackedStringArray).
static func run_batch(
	import_dir: String = IMPORT_DIR,
	goods_dir: String = GOODS_OUT_DIR,
	ports_dir: String = PORTS_OUT_DIR,
	market_dir: String = MARKET_OUT_DIR
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": PackedStringArray(),
		"written": PackedStringArray(),
	}
	var errors: PackedStringArray = PackedStringArray()

	var goods_path: String = import_dir.path_join(FILE_GOODS)
	var ports_path: String = import_dir.path_join(FILE_PORTS)
	var role_cells_path: String = import_dir.path_join(FILE_ROLE_CELLS)
	var price_curve_path: String = import_dir.path_join(FILE_PRICE_CURVE)
	var curve_out: String = market_dir.path_join("price_curve.tres")

	# Validate all four first — collect every error (D-08i / C-06).
	# emit_push_errors=false so failures are listed once by _abort_batch.
	var goods_result: Dictionary = import_csv(goods_path, KIND_GOOD_DEF, false)
	var ports_result: Dictionary = import_csv(ports_path, KIND_PORT_DEF, false)
	var role_result: Dictionary = import_csv(role_cells_path, KIND_ROLE_CELL, false)
	var curve_result: Dictionary = import_csv(price_curve_path, KIND_PRICE_CURVE, false)

	_merge_prefixed_errors(errors, FILE_GOODS, goods_result)
	_merge_prefixed_errors(errors, FILE_PORTS, ports_result)
	_merge_prefixed_errors(errors, FILE_ROLE_CELLS, role_result)
	_merge_prefixed_errors(errors, FILE_PRICE_CURVE, curve_result)

	# Role label check (enum names from 03_Systems r261) — still part of validate pass.
	if role_result["ok"]:
		_collect_role_label_errors(role_result["rows"] as Array, errors)

	if not errors.is_empty():
		# D-08i: any error → write nothing; list all errors once.
		return _abort_batch(result, errors)

	var clear_errors: PackedStringArray = clear_output_tres(goods_dir, ports_dir, curve_out)
	if not clear_errors.is_empty():
		for message in clear_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	var written: PackedStringArray = PackedStringArray()
	var write_errors: PackedStringArray = PackedStringArray()
	_write_good_tres(goods_result["rows"] as Array, goods_dir, written, write_errors)
	_write_port_tres(
		ports_result["rows"] as Array,
		role_result["rows"] as Array,
		ports_dir,
		written,
		write_errors
	)
	_write_price_curve_tres(curve_result["rows"] as Array, curve_out, written, write_errors)

	if not write_errors.is_empty():
		# Write-phase failure: still all-or-nothing intent — report and do not claim ok.
		for message in write_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	result["ok"] = true
	result["errors"] = PackedStringArray()
	result["written"] = written
	return result


## Remove existing .tres under goods／ports dirs and the price_curve output path (D-08i).
## Leaves non-.tres entries (e.g. .gitkeep) untouched.
static func clear_output_tres(
	goods_dir: String,
	ports_dir: String,
	price_curve_out: String
) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_clear_tres_in_dir(goods_dir, errors)
	_clear_tres_in_dir(ports_dir, errors)
	if FileAccess.file_exists(price_curve_out):
		var abs_curve: String = ProjectSettings.globalize_path(price_curve_out)
		var err: Error = DirAccess.remove_absolute(abs_curve)
		if err != OK:
			errors.append(
				"D-08i: failed to clear old output %s (err=%s)" % [price_curve_out, str(err)]
			)
	return errors


static func _abort_with_errors(
	result: Dictionary,
	errors: PackedStringArray,
	emit_push_errors: bool = true
) -> Dictionary:
	if emit_push_errors:
		for message in errors:
			push_error(message)
	result["ok"] = false
	result["errors"] = errors
	result["rows"] = []
	return result


static func _abort_batch(result: Dictionary, errors: PackedStringArray) -> Dictionary:
	for message in errors:
		push_error(message)
	result["ok"] = false
	result["errors"] = errors
	result["written"] = PackedStringArray()
	return result


static func _merge_prefixed_errors(
	into: PackedStringArray,
	file_label: String,
	part: Dictionary
) -> void:
	if part["ok"]:
		return
	var part_errors: PackedStringArray = part["errors"]
	for message in part_errors:
		into.append("%s: %s" % [file_label, String(message)])


static func _collect_role_label_errors(rows: Array, errors: PackedStringArray) -> void:
	var row_index: int = 0
	for row_variant in rows:
		row_index += 1
		var row: Dictionary = row_variant
		var role_name: String = String(row["role"])
		if _role_name_to_value(role_name) < 0:
			errors.append(
				"%s: D-08i role label invalid row %s value '%s' (expect PRODUCER／TRANSIT／TERMINAL)"
				% [FILE_ROLE_CELLS, str(row_index), role_name]
			)


static func _role_name_to_value(role_name: String) -> int:
	if role_name == ROLE_NAME_PRODUCER:
		return ROLE_VALUE_PRODUCER
	if role_name == ROLE_NAME_TRANSIT:
		return ROLE_VALUE_TRANSIT
	if role_name == ROLE_NAME_TERMINAL:
		return ROLE_VALUE_TERMINAL
	return -1


static func _clear_tres_in_dir(dir_path: String, errors: PackedStringArray) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var mk: Error = DirAccess.make_dir_recursive_absolute(abs_dir)
		if mk != OK:
			errors.append("D-08i: cannot create output dir %s (err=%s)" % [dir_path, str(mk)])
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		errors.append("D-08i: cannot open output dir %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(TRES_SUFFIX):
			var full: String = dir_path.path_join(file_name)
			var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
			if err != OK:
				errors.append("D-08i: failed to clear old output %s (err=%s)" % [full, str(err)])
		file_name = dir.get_next()
	dir.list_dir_end()


static func _write_good_tres(
	rows: Array,
	goods_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := GoodDef.new()
		def.good_id = String(row["good_id"])
		def.name_zh = String(row["name_zh"])
		def.tier = int(row["tier"])
		def.is_staple = bool(row["is_staple"])
		def.is_build_material = bool(row["is_build_material"])
		def.is_strategic = bool(row["is_strategic"])
		def.base_price_li = int(row["base_price_li"])
		def.season_mask = int(row["season_mask"])
		var path: String = goods_dir.path_join("%s%s" % [def.good_id, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("D-08i: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_port_tres(
	port_rows: Array,
	role_rows: Array,
	ports_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	var cells_by_port: Dictionary = {}
	for row_variant in role_rows:
		var row: Dictionary = row_variant
		var port_id: String = String(row["port_id"])
		var good_id: String = String(row["good_id"])
		var cell := RoleCell.new()
		cell.role = _role_name_to_value(String(row["role"]))
		cell.downstream_terminals = row["downstream_terminals"] as PackedStringArray
		cell.base_output_per_season = int(row["base_output_per_season"])
		if not cells_by_port.has(port_id):
			cells_by_port[port_id] = {}
		var port_map: Dictionary = cells_by_port[port_id]
		port_map[good_id] = cell
		cells_by_port[port_id] = port_map

	for row_variant in port_rows:
		var row: Dictionary = row_variant
		var def := PortDef.new()
		def.port_id = String(row["port_id"])
		def.name_zh = String(row["name_zh"])
		def.is_free_port = bool(row["is_free_port"])
		def.draft_limit_class = int(row["draft_limit_class"])
		def.regime_id = String(row["regime_id"])
		if cells_by_port.has(def.port_id):
			def.role_cells = cells_by_port[def.port_id]
		else:
			def.role_cells = {}
		var path: String = ports_dir.path_join("%s%s" % [def.port_id, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("D-08i: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_price_curve_tres(
	rows: Array,
	curve_out: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	var parent: String = curve_out.get_base_dir()
	var abs_parent: String = ProjectSettings.globalize_path(parent)
	if not DirAccess.dir_exists_absolute(abs_parent):
		var mk: Error = DirAccess.make_dir_recursive_absolute(abs_parent)
		if mk != OK:
			errors.append("D-08i: cannot create market dir %s (err=%s)" % [parent, str(mk)])
			return
	var curve := PriceCurve.new()
	var weeks := PackedFloat64Array()
	var mults := PackedFloat64Array()
	for row_variant in rows:
		var row: Dictionary = row_variant
		weeks.append(float(row["weeks"]))
		mults.append(float(row["mult"]))
	curve.weeks = weeks
	curve.mults = mults
	var err: Error = ResourceSaver.save(curve, curve_out)
	if err != OK:
		errors.append("D-08i: failed to write %s (err=%s)" % [curve_out, str(err)])
	else:
		written.append(curve_out)


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
	if field_type == COL_TYPE_ARRAY_STRING:
		# Serialized array cell — any string (incl. empty) is structurally acceptable.
		return true
	if field_type == COL_TYPE_INT:
		return cell.is_valid_int()
	if field_type == COL_TYPE_FLOAT:
		return cell.is_valid_float()
	if field_type == COL_TYPE_BOOL:
		return cell == BOOL_TRUE or cell == BOOL_FALSE
	return false


static func _parse_cell(cell: String, field_type: String) -> Variant:
	if field_type == COL_TYPE_INT:
		return cell.to_int()
	if field_type == COL_TYPE_FLOAT:
		return cell.to_float()
	if field_type == COL_TYPE_BOOL:
		return cell == BOOL_TRUE
	if field_type == COL_TYPE_ARRAY_STRING:
		return _parse_array_string_cell(cell)
	return cell


static func _parse_array_string_cell(cell: String) -> PackedStringArray:
	var out := PackedStringArray()
	if cell == "":
		return out
	var parts: PackedStringArray = cell.split(ARRAY_CELL_SEPARATOR, false)
	for part in parts:
		out.append(part)
	return out


static func _is_trailing_eof_blank(file: FileAccess, line: PackedStringArray) -> bool:
	return file.eof_reached() and line.size() == 1 and line[0] == ""
