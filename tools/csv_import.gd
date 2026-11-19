@tool
extends EditorScript
## CSV → Resource converter framework (05_TechSpec 2.1-04 + D-08i + WP-17 / 10-05／10-06 + WP-29 D-14e).
## Validates CSV against 03_Systems／04_Content data-structure field names/types.
## Public API is static so headless GUT can call without instantiating EditorScript.
## D-08i: fixed in/out paths; validate all four CSVs then write all-or-nothing; clear old outputs first.
## WP-17: second all-or-nothing batch for zones／buildings／opening_workshops／build_queue.
## WP-29: third all-or-nothing batch for nodes／regions／lanes → res://data/sea/ (D-14e).

const FIXTURES_PREFIX := "res://tests/fixtures/"
const DATA_PREFIX := "res://data/"

## D-08i fixed import directory (allowed by TechSpec 2.1-04 / D-08i).
const IMPORT_DIR := "res://data/import/"
const IMPORT_GOODS_CSV := IMPORT_DIR + "goods.csv"
const IMPORT_PORTS_CSV := IMPORT_DIR + "ports.csv"
const IMPORT_ROLE_CELLS_CSV := IMPORT_DIR + "role_cells.csv"
const IMPORT_PRICE_CURVE_CSV := IMPORT_DIR + "price_curve.csv"
## WP-17 / 10-05 fixed import filenames (same IMPORT_DIR).
const IMPORT_ZONES_CSV := IMPORT_DIR + "zones.csv"
const IMPORT_BUILDINGS_CSV := IMPORT_DIR + "buildings.csv"
const IMPORT_OPENING_WORKSHOPS_CSV := IMPORT_DIR + "opening_workshops.csv"
const IMPORT_BUILD_QUEUE_CSV := IMPORT_DIR + "build_queue.csv"
const IMPORT_CITY_CENTER_CSV := IMPORT_DIR + "city_center.csv"
const IMPORT_OPENING_PUBLIC_CSV := IMPORT_DIR + "opening_public.csv"
const IMPORT_OPENING_POPULATION_CSV := IMPORT_DIR + "opening_population.csv"
## WP-29 / D-14e fixed import filenames (same IMPORT_DIR).
const IMPORT_NODES_CSV := IMPORT_DIR + "nodes.csv"
const IMPORT_REGIONS_CSV := IMPORT_DIR + "regions.csv"
const IMPORT_LANES_CSV := IMPORT_DIR + "lanes.csv"

## D-08i fixed output roots.
const GOODS_OUT_DIR := "res://data/goods/"
const PORTS_OUT_DIR := "res://data/ports/"
const MARKET_OUT_DIR := "res://data/market/"
const PRICE_CURVE_OUT_PATH := MARKET_OUT_DIR + "price_curve.tres"
## WP-17 / 10-05 fixed output roots (allowed directories).
const ZONES_OUT_DIR := "res://data/zones/"
const BUILDINGS_OUT_DIR := "res://data/buildings/"
const OPENING_OUT_DIR := "res://data/opening/"
const BUILD_QUEUE_OUT_DIR := "res://data/build_queue/"
const CITY_CENTER_OUT_DIR := "res://data/city_center/"
const OPENING_PUBLIC_OUT_DIR := "res://data/opening_public/"
const OPENING_POPULATION_OUT_DIR := "res://data/opening_population/"
## WP-29 / D-14e fixed output roots under res://data/sea/.
const SEA_OUT_DIR := "res://data/sea/"
const SEA_NODES_OUT_DIR := SEA_OUT_DIR + "nodes/"
const SEA_REGIONS_OUT_DIR := SEA_OUT_DIR + "regions/"
const SEA_LANES_OUT_DIR := SEA_OUT_DIR + "lanes/"

## Resource kinds — one kind per CSV (2.1-04 ①).
const KIND_GOOD_DEF := "GoodDef"
const KIND_PORT_DEF := "PortDef"
const KIND_ROLE_CELL := "RoleCell"
const KIND_PRICE_CURVE := "PriceCurve"
const KIND_ZONE_DEF := "ZoneDef"
const KIND_BUILDING_DEF := "BuildingDef"
const KIND_OPENING_WORKSHOP := "OpeningWorkshop"
const KIND_BUILD_STEP := "BuildStep"
const KIND_CITY_CENTER_DEF := "CityCenterDef"
const KIND_OPENING_PUBLIC := "OpeningPublic"
const KIND_OPENING_POPULATION := "OpeningPopulation"
const KIND_SEA_NODE := "SeaNode"
const KIND_SEA_REGION := "SeaRegion"
const KIND_SEA_LANE := "SeaLane"

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

## Filenames inside IMPORT_DIR (D-08i + WP-17).
const FILE_GOODS := "goods.csv"
const FILE_PORTS := "ports.csv"
const FILE_ROLE_CELLS := "role_cells.csv"
const FILE_PRICE_CURVE := "price_curve.csv"
const FILE_ZONES := "zones.csv"
const FILE_BUILDINGS := "buildings.csv"
const FILE_OPENING_WORKSHOPS := "opening_workshops.csv"
const FILE_BUILD_QUEUE := "build_queue.csv"
const FILE_CITY_CENTER := "city_center.csv"
const FILE_OPENING_PUBLIC := "opening_public.csv"
const FILE_OPENING_POPULATION := "opening_population.csv"
const FILE_NODES := "nodes.csv"
const FILE_REGIONS := "regions.csv"
const FILE_LANES := "lanes.csv"

## WP-29 / D-14e kind／lane_type allowlists.
const SEA_KIND_PORT := "PORT"
const SEA_KIND_JUNCTION := "JUNCTION"
const SEA_KIND_ALLOWED: PackedStringArray = [SEA_KIND_PORT, SEA_KIND_JUNCTION]
const SEA_LANE_TYPE_SPUR := "SPUR"
const SEA_LANE_TYPE_TRUNK := "TRUNK"
const SEA_LANE_TYPE_NEIGHBOR := "NEIGHBOR"
const SEA_LANE_TYPE_ALLOWED: PackedStringArray = [
	SEA_LANE_TYPE_SPUR,
	SEA_LANE_TYPE_TRUNK,
	SEA_LANE_TYPE_NEIGHBOR,
]

## WP-17 / 10-06 ② build_class allowlist.
const BUILD_CLASS_RESIDENCE := "RESIDENCE"
const BUILD_CLASS_WAREHOUSE := "WAREHOUSE"
const BUILD_CLASS_IND1 := "IND1"
const BUILD_CLASS_IND2 := "IND2"
const BUILD_CLASS_IND3 := "IND3"
const BUILD_CLASS_PUBLIC := "PUBLIC"
const BUILD_CLASS_KONTOR := "KONTOR"
const BUILD_CLASS_ALLOWED: PackedStringArray = [
	BUILD_CLASS_RESIDENCE,
	BUILD_CLASS_WAREHOUSE,
	BUILD_CLASS_IND1,
	BUILD_CLASS_IND2,
	BUILD_CLASS_IND3,
	BUILD_CLASS_PUBLIC,
	BUILD_CLASS_KONTOR,
]

## WP-17 / 10-06 ③ cb_id format (TechSpec literal).
const CB_ID_FORMAT_PATTERN := "^CB-[0-9]{2}$"

## Composite-key .tres filename joiner (C-05 gap: 10-05 lists dirs only, not filenames).
const COMPOSITE_TRES_JOINER := "__"

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

## ZoneDef fields — TechSpec 10-05 zones.csv headers (04_Content §7).
## slot_share is 定點數 → float (10-06); open_at_start is int 0／1 (not bool).
const ZONE_DEF_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "zone", "type": COL_TYPE_INT},
	{"name": "slot_share", "type": COL_TYPE_FLOAT},
	{"name": "rings", "type": COL_TYPE_INT},
	{"name": "slots", "type": COL_TYPE_INT},
	{"name": "open_at_start", "type": COL_TYPE_INT},
]

## BuildingDef fields — TechSpec 10-05 buildings.csv headers.
## base_output_per_worker + input*_qty are 定點數 → float (10-06／D-18a).
const BUILDING_DEF_FIELDS: Array[Dictionary] = [
	{"name": "type", "type": COL_TYPE_STRING},
	{"name": "tier", "type": COL_TYPE_INT},
	{"name": "max_workers", "type": COL_TYPE_INT},
	{"name": "base_output_per_worker", "type": COL_TYPE_FLOAT},
	{"name": "output_good_id", "type": COL_TYPE_STRING},
	{"name": "input1_good_id", "type": COL_TYPE_STRING},
	{"name": "input1_qty", "type": COL_TYPE_FLOAT},
	{"name": "input2_good_id", "type": COL_TYPE_STRING},
	{"name": "input2_qty", "type": COL_TYPE_FLOAT},
	{"name": "build_class", "type": COL_TYPE_STRING},
]

## OpeningWorkshop fields — TechSpec 10-05 opening_workshops.csv headers.
const OPENING_WORKSHOP_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "good_id", "type": COL_TYPE_STRING},
	{"name": "count", "type": COL_TYPE_INT},
]

## BuildStep fields — TechSpec 10-05 build_queue.csv headers.
const BUILD_STEP_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "step", "type": COL_TYPE_INT},
	{"name": "cb_id", "type": COL_TYPE_STRING},
	{"name": "target_level", "type": COL_TYPE_INT},
]

## CityCenterDef — D-11c headers.
const CITY_CENTER_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "public_slots", "type": COL_TYPE_INT},
]

## OpeningPublic — D-11c headers.
const OPENING_PUBLIC_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "cb_id", "type": COL_TYPE_STRING},
	{"name": "level", "type": COL_TYPE_INT},
]

## OpeningPopulation — D-19e headers (exact).
const OPENING_POPULATION_FIELDS: Array[Dictionary] = [
	{"name": "port_id", "type": COL_TYPE_STRING},
	{"name": "poor", "type": COL_TYPE_INT},
	{"name": "citizen", "type": COL_TYPE_INT},
	{"name": "rich", "type": COL_TYPE_INT},
]

## SeaNode — D-14e / 04_Content 8.2 headers.
const SEA_NODE_FIELDS: Array[Dictionary] = [
	{"name": "node_id", "type": COL_TYPE_STRING},
	{"name": "kind", "type": COL_TYPE_STRING},
	{"name": "name_zh", "type": COL_TYPE_STRING},
	{"name": "x", "type": COL_TYPE_INT},
	{"name": "y", "type": COL_TYPE_INT},
]

## SeaRegion — D-14e / 04_Content 8.3 headers (note replaces 說明).
const SEA_REGION_FIELDS: Array[Dictionary] = [
	{"name": "region_id", "type": COL_TYPE_STRING},
	{"name": "name_zh", "type": COL_TYPE_STRING},
	{"name": "note", "type": COL_TYPE_STRING},
]

## SeaLane — D-14e / 04_Content 8.4 headers.
const SEA_LANE_FIELDS: Array[Dictionary] = [
	{"name": "lane_id", "type": COL_TYPE_STRING},
	{"name": "node_a", "type": COL_TYPE_STRING},
	{"name": "node_b", "type": COL_TYPE_STRING},
	{"name": "region_id", "type": COL_TYPE_STRING},
	{"name": "length", "type": COL_TYPE_FLOAT},
	{"name": "waypoints", "type": COL_TYPE_INT},
	{"name": "lane_type", "type": COL_TYPE_STRING},
]


func _run() -> void:
	## D-08i: EditorScript entry uses fixed in/out paths only.
	var result: Dictionary = run_batch()
	if result["ok"]:
		print("csv_import D-08i: wrote %s resources" % str((result["written"] as Array).size()))
	else:
		push_error("csv_import D-08i: aborted with %s error(s)" % str((result["errors"] as PackedStringArray).size()))
	## WP-17: second independent all-or-nothing batch (10-05).
	var wp17: Dictionary = run_batch_wp17()
	if wp17["ok"]:
		print("csv_import WP-17: wrote %s resources" % str((wp17["written"] as Array).size()))
	else:
		push_error("csv_import WP-17: aborted with %s error(s)" % str((wp17["errors"] as PackedStringArray).size()))
	## WP-18: city_center／opening_public batch (D-11c).
	var wp18: Dictionary = run_batch_wp18()
	if wp18["ok"]:
		print("csv_import WP-18: wrote %s resources" % str((wp18["written"] as Array).size()))
	else:
		push_error("csv_import WP-18: aborted with %s error(s)" % str((wp18["errors"] as PackedStringArray).size()))
	## WP-24 / D-19e: opening_population batch.
	var wp24_pop: Dictionary = run_batch_opening_population()
	if wp24_pop["ok"]:
		print(
			"csv_import opening_population: wrote %s resources"
			% str((wp24_pop["written"] as Array).size())
		)
	else:
		push_error(
			"csv_import opening_population: aborted with %s error(s)"
			% str((wp24_pop["errors"] as PackedStringArray).size())
		)
	## WP-29: nodes／regions／lanes batch (D-14e).
	var wp29: Dictionary = run_batch_wp29()
	if wp29["ok"]:
		print("csv_import WP-29: wrote %s resources" % str((wp29["written"] as Array).size()))
	else:
		push_error("csv_import WP-29: aborted with %s error(s)" % str((wp29["errors"] as PackedStringArray).size()))


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
	if resource_kind == KIND_ZONE_DEF:
		return ZONE_DEF_FIELDS
	if resource_kind == KIND_BUILDING_DEF:
		return BUILDING_DEF_FIELDS
	if resource_kind == KIND_OPENING_WORKSHOP:
		return OPENING_WORKSHOP_FIELDS
	if resource_kind == KIND_BUILD_STEP:
		return BUILD_STEP_FIELDS
	if resource_kind == KIND_CITY_CENTER_DEF:
		return CITY_CENTER_FIELDS
	if resource_kind == KIND_OPENING_PUBLIC:
		return OPENING_PUBLIC_FIELDS
	if resource_kind == KIND_OPENING_POPULATION:
		return OPENING_POPULATION_FIELDS
	if resource_kind == KIND_SEA_NODE:
		return SEA_NODE_FIELDS
	if resource_kind == KIND_SEA_REGION:
		return SEA_REGION_FIELDS
	if resource_kind == KIND_SEA_LANE:
		return SEA_LANE_FIELDS
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


## WP-17 / 10-05: validate zones／buildings／opening_workshops／build_queue, then clear＋write all-or-nothing.
## goods.csv／ports.csv in import_dir are reference-only for 10-06 ① (not written by this batch).
## Result keys: ok (bool), errors (PackedStringArray), written (PackedStringArray).
static func run_batch_wp17(
	import_dir: String = IMPORT_DIR,
	zones_dir: String = ZONES_OUT_DIR,
	buildings_dir: String = BUILDINGS_OUT_DIR,
	opening_dir: String = OPENING_OUT_DIR,
	build_queue_dir: String = BUILD_QUEUE_OUT_DIR
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": PackedStringArray(),
		"written": PackedStringArray(),
	}
	var errors: PackedStringArray = PackedStringArray()

	var zones_path: String = import_dir.path_join(FILE_ZONES)
	var buildings_path: String = import_dir.path_join(FILE_BUILDINGS)
	var opening_path: String = import_dir.path_join(FILE_OPENING_WORKSHOPS)
	var queue_path: String = import_dir.path_join(FILE_BUILD_QUEUE)
	var goods_path: String = import_dir.path_join(FILE_GOODS)
	var ports_path: String = import_dir.path_join(FILE_PORTS)

	var zones_result: Dictionary = import_csv(zones_path, KIND_ZONE_DEF, false)
	var buildings_result: Dictionary = import_csv(buildings_path, KIND_BUILDING_DEF, false)
	var opening_result: Dictionary = import_csv(opening_path, KIND_OPENING_WORKSHOP, false)
	var queue_result: Dictionary = import_csv(queue_path, KIND_BUILD_STEP, false)
	## Reference catalogs for 10-06 ① — parse only; not part of WP-17 write set.
	var goods_result: Dictionary = import_csv(goods_path, KIND_GOOD_DEF, false)
	var ports_result: Dictionary = import_csv(ports_path, KIND_PORT_DEF, false)

	_merge_prefixed_errors(errors, FILE_ZONES, zones_result)
	_merge_prefixed_errors(errors, FILE_BUILDINGS, buildings_result)
	_merge_prefixed_errors(errors, FILE_OPENING_WORKSHOPS, opening_result)
	_merge_prefixed_errors(errors, FILE_BUILD_QUEUE, queue_result)
	_merge_prefixed_errors(errors, FILE_GOODS, goods_result)
	_merge_prefixed_errors(errors, FILE_PORTS, ports_result)

	if (
		zones_result["ok"]
		and buildings_result["ok"]
		and opening_result["ok"]
		and queue_result["ok"]
		and goods_result["ok"]
		and ports_result["ok"]
	):
		_collect_wp17_rule_errors(
			zones_result["rows"] as Array,
			buildings_result["rows"] as Array,
			opening_result["rows"] as Array,
			queue_result["rows"] as Array,
			goods_result["rows"] as Array,
			ports_result["rows"] as Array,
			errors
		)

	if not errors.is_empty():
		return _abort_batch(result, errors)

	var clear_errors: PackedStringArray = clear_output_tres_wp17(
		zones_dir, buildings_dir, opening_dir, build_queue_dir
	)
	if not clear_errors.is_empty():
		for message in clear_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	var written: PackedStringArray = PackedStringArray()
	var write_errors: PackedStringArray = PackedStringArray()
	_write_zone_tres(zones_result["rows"] as Array, zones_dir, written, write_errors)
	_write_building_tres(buildings_result["rows"] as Array, buildings_dir, written, write_errors)
	_write_opening_workshop_tres(opening_result["rows"] as Array, opening_dir, written, write_errors)
	_write_build_step_tres(queue_result["rows"] as Array, build_queue_dir, written, write_errors)

	if not write_errors.is_empty():
		for message in write_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	result["ok"] = true
	result["errors"] = PackedStringArray()
	result["written"] = written
	return result


## Remove existing .tres under WP-17 output dirs (10-05／D-08i clear-before-write).
static func clear_output_tres_wp17(
	zones_dir: String,
	buildings_dir: String,
	opening_dir: String,
	build_queue_dir: String
) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_clear_tres_in_dir(zones_dir, errors)
	_clear_tres_in_dir(buildings_dir, errors)
	_clear_tres_in_dir(opening_dir, errors)
	_clear_tres_in_dir(build_queue_dir, errors)
	return errors


## TechSpec 10-06 ①–⑥ — collect every violation (C-06); no extra cross-table rules.
static func _collect_wp17_rule_errors(
	zones: Array,
	buildings: Array,
	openings: Array,
	queue: Array,
	goods: Array,
	ports: Array,
	errors: PackedStringArray
) -> void:
	var port_ids: Dictionary = {}
	for row_variant in ports:
		var port_row: Dictionary = row_variant
		port_ids[String(port_row["port_id"])] = true
	var good_ids: Dictionary = {}
	for row_variant in goods:
		var good_row: Dictionary = row_variant
		good_ids[String(good_row["good_id"])] = true

	_collect_wp17_zone_errors(zones, port_ids, errors)
	_collect_wp17_building_errors(buildings, good_ids, errors)
	_collect_wp17_opening_errors(openings, port_ids, good_ids, errors)
	_collect_wp17_queue_errors(queue, port_ids, errors)


static func _collect_wp17_zone_errors(
	zones: Array,
	port_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var seen: Dictionary = {}
	var row_index: int = 0
	for row_variant in zones:
		row_index += 1
		var row: Dictionary = row_variant
		var port_id: String = String(row["port_id"])
		var zone: int = int(row["zone"])
		var rings: int = int(row["rings"])
		var slots: int = int(row["slots"])
		var open_at_start: int = int(row["open_at_start"])
		## 10-06 ① port_id ∈ ports
		if not port_ids.has(port_id):
			errors.append(
				"%s: 10-06 ① unknown port_id row %s value '%s'"
				% [FILE_ZONES, str(row_index), port_id]
			)
		## 10-06 ⑤ int ≥ 0
		if zone < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field zone value %s"
				% [FILE_ZONES, str(row_index), str(zone)]
			)
		if rings < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field rings value %s"
				% [FILE_ZONES, str(row_index), str(rings)]
			)
		if slots < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field slots value %s"
				% [FILE_ZONES, str(row_index), str(slots)]
			)
		if open_at_start < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field open_at_start value %s"
				% [FILE_ZONES, str(row_index), str(open_at_start)]
			)
		## 10-06 ④ open_at_start ∈ {0, 1}
		if open_at_start != 0 and open_at_start != 1:
			errors.append(
				"%s: 10-06 ④ open_at_start row %s value %s (expect 0／1)"
				% [FILE_ZONES, str(row_index), str(open_at_start)]
			)
		## 10-06 ⑥ unique (port_id, zone)
		var key: String = "%s%s%s" % [port_id, COMPOSITE_TRES_JOINER, str(zone)]
		if seen.has(key):
			errors.append(
				"%s: 10-06 ⑥ duplicate key row %s (port_id, zone)=(%s, %s)"
				% [FILE_ZONES, str(row_index), port_id, str(zone)]
			)
		else:
			seen[key] = true


static func _collect_wp17_building_errors(
	buildings: Array,
	good_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var seen: Dictionary = {}
	var allowed: Dictionary = {}
	for name in BUILD_CLASS_ALLOWED:
		allowed[name] = true
	var row_index: int = 0
	for row_variant in buildings:
		row_index += 1
		var row: Dictionary = row_variant
		var type_id: String = String(row["type"])
		var tier: int = int(row["tier"])
		var max_workers: int = int(row["max_workers"])
		var input1_qty: float = float(row["input1_qty"])
		var input2_qty: float = float(row["input2_qty"])
		var build_class: String = String(row["build_class"])
		## 10-06 ① non-empty *_good_id ∈ goods
		_check_optional_good_id(
			FILE_BUILDINGS, row_index, "output_good_id", String(row["output_good_id"]), good_ids, errors
		)
		_check_optional_good_id(
			FILE_BUILDINGS, row_index, "input1_good_id", String(row["input1_good_id"]), good_ids, errors
		)
		_check_optional_good_id(
			FILE_BUILDINGS, row_index, "input2_good_id", String(row["input2_good_id"]), good_ids, errors
		)
		## 10-06 ② build_class allowlist
		if not allowed.has(build_class):
			errors.append(
				"%s: 10-06 ② build_class row %s value '%s'"
				% [FILE_BUILDINGS, str(row_index), build_class]
			)
		## 10-06 ⑤ int ≥ 0；D-18a input*_qty float ≥ 0
		if tier < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field tier value %s"
				% [FILE_BUILDINGS, str(row_index), str(tier)]
			)
		if max_workers < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field max_workers value %s"
				% [FILE_BUILDINGS, str(row_index), str(max_workers)]
			)
		if input1_qty < 0.0:
			errors.append(
				"%s: D-18a float below zero row %s field input1_qty value %s"
				% [FILE_BUILDINGS, str(row_index), str(input1_qty)]
			)
		if input2_qty < 0.0:
			errors.append(
				"%s: D-18a float below zero row %s field input2_qty value %s"
				% [FILE_BUILDINGS, str(row_index), str(input2_qty)]
			)
		## 10-06 ⑥ unique type
		if seen.has(type_id):
			errors.append(
				"%s: 10-06 ⑥ duplicate key row %s type='%s'"
				% [FILE_BUILDINGS, str(row_index), type_id]
			)
		else:
			seen[type_id] = true


static func _collect_wp17_opening_errors(
	openings: Array,
	port_ids: Dictionary,
	good_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var seen: Dictionary = {}
	var row_index: int = 0
	for row_variant in openings:
		row_index += 1
		var row: Dictionary = row_variant
		var port_id: String = String(row["port_id"])
		var good_id: String = String(row["good_id"])
		var count: int = int(row["count"])
		## 10-06 ①
		if not port_ids.has(port_id):
			errors.append(
				"%s: 10-06 ① unknown port_id row %s value '%s'"
				% [FILE_OPENING_WORKSHOPS, str(row_index), port_id]
			)
		if not good_ids.has(good_id):
			errors.append(
				"%s: 10-06 ① unknown good_id row %s value '%s'"
				% [FILE_OPENING_WORKSHOPS, str(row_index), good_id]
			)
		## 10-06 ⑤
		if count < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field count value %s"
				% [FILE_OPENING_WORKSHOPS, str(row_index), str(count)]
			)
		## 10-06 ⑥ unique (port_id, good_id)
		var key: String = "%s%s%s" % [port_id, COMPOSITE_TRES_JOINER, good_id]
		if seen.has(key):
			errors.append(
				"%s: 10-06 ⑥ duplicate key row %s (port_id, good_id)=(%s, %s)"
				% [FILE_OPENING_WORKSHOPS, str(row_index), port_id, good_id]
			)
		else:
			seen[key] = true


static func _collect_wp17_queue_errors(
	queue: Array,
	port_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var cb_regex := RegEx.new()
	var compile_err: int = cb_regex.compile(CB_ID_FORMAT_PATTERN)
	assert(compile_err == OK, "CB_ID_FORMAT_PATTERN must compile")
	var seen: Dictionary = {}
	var row_index: int = 0
	for row_variant in queue:
		row_index += 1
		var row: Dictionary = row_variant
		var port_id: String = String(row["port_id"])
		var step: int = int(row["step"])
		var cb_id: String = String(row["cb_id"])
		var target_level: int = int(row["target_level"])
		## 10-06 ①
		if not port_ids.has(port_id):
			errors.append(
				"%s: 10-06 ① unknown port_id row %s value '%s'"
				% [FILE_BUILD_QUEUE, str(row_index), port_id]
			)
		## 10-06 ③ cb_id format
		var match: RegExMatch = cb_regex.search(cb_id)
		var full_match := match != null and match.get_string() == cb_id
		if not full_match:
			errors.append(
				"%s: 10-06 ③ cb_id format row %s value '%s' (expect %s)"
				% [FILE_BUILD_QUEUE, str(row_index), cb_id, CB_ID_FORMAT_PATTERN]
			)
		## 10-06 ⑤
		if step < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field step value %s"
				% [FILE_BUILD_QUEUE, str(row_index), str(step)]
			)
		if target_level < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field target_level value %s"
				% [FILE_BUILD_QUEUE, str(row_index), str(target_level)]
			)
		## 10-06 ⑥ unique (port_id, step)
		var key: String = "%s%s%s" % [port_id, COMPOSITE_TRES_JOINER, str(step)]
		if seen.has(key):
			errors.append(
				"%s: 10-06 ⑥ duplicate key row %s (port_id, step)=(%s, %s)"
				% [FILE_BUILD_QUEUE, str(row_index), port_id, str(step)]
			)
		else:
			seen[key] = true


static func _check_optional_good_id(
	file_label: String,
	row_index: int,
	field_name: String,
	good_id: String,
	good_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	if good_id == "":
		return
	if not good_ids.has(good_id):
		errors.append(
			"%s: 10-06 ① unknown %s row %s value '%s'"
			% [file_label, field_name, str(row_index), good_id]
		)


static func _write_zone_tres(
	rows: Array,
	zones_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := ZoneDef.new()
		def.port_id = String(row["port_id"])
		def.zone = int(row["zone"])
		def.slot_share = float(row["slot_share"])
		def.rings = int(row["rings"])
		def.slots = int(row["slots"])
		def.open_at_start = int(row["open_at_start"])
		var file_name: String = "%s%s%s%s" % [
			def.port_id, COMPOSITE_TRES_JOINER, str(def.zone), TRES_SUFFIX
		]
		var path: String = zones_dir.path_join(file_name)
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-17: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


## WP-18 / D-11c: validate city_center／opening_public, clear + write all-or-nothing.
static func run_batch_wp18(
	import_dir: String = IMPORT_DIR,
	city_center_dir: String = CITY_CENTER_OUT_DIR,
	opening_public_dir: String = OPENING_PUBLIC_OUT_DIR
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": PackedStringArray(),
		"written": PackedStringArray(),
	}
	var errors: PackedStringArray = PackedStringArray()

	var city_path: String = import_dir.path_join(FILE_CITY_CENTER)
	var public_path: String = import_dir.path_join(FILE_OPENING_PUBLIC)
	var ports_path: String = import_dir.path_join(FILE_PORTS)

	var city_result: Dictionary = import_csv(city_path, KIND_CITY_CENTER_DEF, false)
	var public_result: Dictionary = import_csv(public_path, KIND_OPENING_PUBLIC, false)
	var ports_result: Dictionary = import_csv(ports_path, KIND_PORT_DEF, false)

	_merge_prefixed_errors(errors, FILE_CITY_CENTER, city_result)
	_merge_prefixed_errors(errors, FILE_OPENING_PUBLIC, public_result)
	_merge_prefixed_errors(errors, FILE_PORTS, ports_result)

	if city_result["ok"] and public_result["ok"] and ports_result["ok"]:
		_collect_wp18_rule_errors(
			city_result["rows"] as Array,
			public_result["rows"] as Array,
			ports_result["rows"] as Array,
			errors
		)

	if not errors.is_empty():
		return _abort_batch(result, errors)

	var clear_errors: PackedStringArray = clear_output_tres_wp18(city_center_dir, opening_public_dir)
	if not clear_errors.is_empty():
		for message in clear_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	var written: PackedStringArray = PackedStringArray()
	var write_errors: PackedStringArray = PackedStringArray()
	_write_city_center_tres(city_result["rows"] as Array, city_center_dir, written, write_errors)
	_write_opening_public_tres(public_result["rows"] as Array, opening_public_dir, written, write_errors)

	if not write_errors.is_empty():
		for message in write_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	result["ok"] = true
	result["errors"] = PackedStringArray()
	result["written"] = written
	return result


static func clear_output_tres_wp18(city_center_dir: String, opening_public_dir: String) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_clear_tres_in_dir(city_center_dir, errors)
	_clear_tres_in_dir(opening_public_dir, errors)
	return errors


## WP-24 / D-19e: validate opening_population.csv, clear + write all-or-nothing.
static func run_batch_opening_population(
	import_dir: String = IMPORT_DIR,
	opening_population_dir: String = OPENING_POPULATION_OUT_DIR,
	ports_csv_path: String = ""
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": PackedStringArray(),
		"written": PackedStringArray(),
	}
	var errors: PackedStringArray = PackedStringArray()
	var pop_path: String = import_dir.path_join(FILE_OPENING_POPULATION)
	var ports_path: String = ports_csv_path
	if ports_path == "":
		ports_path = import_dir.path_join(FILE_PORTS)
	var pop_result: Dictionary = import_csv(pop_path, KIND_OPENING_POPULATION, false)
	_merge_prefixed_errors(errors, FILE_OPENING_POPULATION, pop_result)
	var port_ids: Dictionary = {}
	if FileAccess.file_exists(ports_path):
		var ports_result: Dictionary = import_csv(ports_path, KIND_PORT_DEF, false)
		_merge_prefixed_errors(errors, FILE_PORTS, ports_result)
		if ports_result["ok"]:
			for prow in ports_result["rows"] as Array:
				port_ids[String((prow as Dictionary)["port_id"])] = true
	if pop_result["ok"]:
		_collect_opening_population_errors(pop_result["rows"] as Array, port_ids, errors)
	if not errors.is_empty():
		return _abort_batch(result, errors)
	var clear_errors: PackedStringArray = PackedStringArray()
	_clear_tres_in_dir(opening_population_dir, clear_errors)
	if not clear_errors.is_empty():
		for message in clear_errors:
			errors.append(message)
		return _abort_batch(result, errors)
	var written: PackedStringArray = PackedStringArray()
	var write_errors: PackedStringArray = PackedStringArray()
	_write_opening_population_tres(
		pop_result["rows"] as Array, opening_population_dir, written, write_errors
	)
	if not write_errors.is_empty():
		for message2 in write_errors:
			errors.append(message2)
		return _abort_batch(result, errors)
	result["ok"] = true
	result["errors"] = PackedStringArray()
	result["written"] = written
	return result


static func _collect_opening_population_errors(
	rows: Array, port_ids: Dictionary, errors: PackedStringArray
) -> void:
	var seen: Dictionary = {}
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var pid: String = String(row.get("port_id", ""))
		var poor: int = int(row.get("poor", -1))
		var citizen: int = int(row.get("citizen", -1))
		var rich: int = int(row.get("rich", -1))
		if poor < 0 or citizen < 0 or rich < 0:
			errors.append(
				"%s: row %s population ints must be >= 0" % [FILE_OPENING_POPULATION, str(i + 1)]
			)
		if seen.has(pid):
			errors.append(
				"%s: duplicate port_id %s row %s" % [FILE_OPENING_POPULATION, pid, str(i + 1)]
			)
		seen[pid] = true
		if not port_ids.is_empty() and not port_ids.has(pid):
			errors.append(
				"%s: unknown port_id %s row %s" % [FILE_OPENING_POPULATION, pid, str(i + 1)]
			)


static func _write_opening_population_tres(
	rows: Array,
	opening_population_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(opening_population_dir))
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := OpeningPopulation.new()
		def.port_id = String(row["port_id"])
		def.poor = int(row["poor"])
		def.citizen = int(row["citizen"])
		def.rich = int(row["rich"])
		var path: String = opening_population_dir.path_join("%s%s" % [def.port_id, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("opening_population: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


## WP-29 / D-14e: validate nodes／regions／lanes, clear + write all-or-nothing under sea/.
static func run_batch_wp29(
	import_dir: String = IMPORT_DIR,
	nodes_dir: String = SEA_NODES_OUT_DIR,
	regions_dir: String = SEA_REGIONS_OUT_DIR,
	lanes_dir: String = SEA_LANES_OUT_DIR
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"errors": PackedStringArray(),
		"written": PackedStringArray(),
	}
	var errors: PackedStringArray = PackedStringArray()

	var nodes_path: String = import_dir.path_join(FILE_NODES)
	var regions_path: String = import_dir.path_join(FILE_REGIONS)
	var lanes_path: String = import_dir.path_join(FILE_LANES)

	var nodes_result: Dictionary = import_csv(nodes_path, KIND_SEA_NODE, false)
	var regions_result: Dictionary = import_csv(regions_path, KIND_SEA_REGION, false)
	var lanes_result: Dictionary = import_csv(lanes_path, KIND_SEA_LANE, false)

	_merge_prefixed_errors(errors, FILE_NODES, nodes_result)
	_merge_prefixed_errors(errors, FILE_REGIONS, regions_result)
	_merge_prefixed_errors(errors, FILE_LANES, lanes_result)

	if nodes_result["ok"] and regions_result["ok"] and lanes_result["ok"]:
		_collect_wp29_rule_errors(
			nodes_result["rows"] as Array,
			regions_result["rows"] as Array,
			lanes_result["rows"] as Array,
			errors
		)

	if not errors.is_empty():
		return _abort_batch(result, errors)

	var clear_errors: PackedStringArray = clear_output_tres_wp29(nodes_dir, regions_dir, lanes_dir)
	if not clear_errors.is_empty():
		for message in clear_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	var written: PackedStringArray = PackedStringArray()
	var write_errors: PackedStringArray = PackedStringArray()
	_write_sea_node_tres(nodes_result["rows"] as Array, nodes_dir, written, write_errors)
	_write_sea_region_tres(regions_result["rows"] as Array, regions_dir, written, write_errors)
	_write_sea_lane_tres(lanes_result["rows"] as Array, lanes_dir, written, write_errors)

	if not write_errors.is_empty():
		for message in write_errors:
			errors.append(message)
		return _abort_batch(result, errors)

	result["ok"] = true
	result["errors"] = PackedStringArray()
	result["written"] = written
	return result


static func clear_output_tres_wp29(
	nodes_dir: String,
	regions_dir: String,
	lanes_dir: String
) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_clear_tres_in_dir(nodes_dir, errors)
	_clear_tres_in_dir(regions_dir, errors)
	_clear_tres_in_dir(lanes_dir, errors)
	return errors


static func _collect_wp29_rule_errors(
	node_rows: Array,
	region_rows: Array,
	lane_rows: Array,
	errors: PackedStringArray
) -> void:
	var node_ids: Dictionary = {}
	var region_ids: Dictionary = {}
	var row_index: int = 0
	for row_variant in node_rows:
		row_index += 1
		var row: Dictionary = row_variant
		var node_id: String = String(row["node_id"])
		var kind: String = String(row["kind"])
		if node_ids.has(node_id):
			errors.append(
				"%s: D-14e duplicate node_id row %s value '%s'"
				% [FILE_NODES, str(row_index), node_id]
			)
		else:
			node_ids[node_id] = true
		if not SEA_KIND_ALLOWED.has(kind):
			errors.append(
				"%s: D-14e kind allowlist row %s value '%s' (expect PORT／JUNCTION)"
				% [FILE_NODES, str(row_index), kind]
			)
		var name_zh: String = String(row["name_zh"]).strip_edges()
		if name_zh.is_empty():
			errors.append(
				"%s: D-14e name_zh empty row %s" % [FILE_NODES, str(row_index)]
			)

	row_index = 0
	for row_variant in region_rows:
		row_index += 1
		var row: Dictionary = row_variant
		var region_id: String = String(row["region_id"])
		if region_ids.has(region_id):
			errors.append(
				"%s: D-14e duplicate region_id row %s value '%s'"
				% [FILE_REGIONS, str(row_index), region_id]
			)
		else:
			region_ids[region_id] = true
		if String(row["name_zh"]).strip_edges().is_empty():
			errors.append(
				"%s: D-14e name_zh empty row %s" % [FILE_REGIONS, str(row_index)]
			)

	var lane_ids: Dictionary = {}
	var pairs: Dictionary = {}
	row_index = 0
	for row_variant in lane_rows:
		row_index += 1
		var row: Dictionary = row_variant
		var lane_id: String = String(row["lane_id"])
		var node_a: String = String(row["node_a"])
		var node_b: String = String(row["node_b"])
		var region_id: String = String(row["region_id"])
		var waypoints: int = int(row["waypoints"])
		var lane_type: String = String(row["lane_type"])
		if lane_ids.has(lane_id):
			errors.append(
				"%s: D-14e duplicate lane_id row %s value '%s'"
				% [FILE_LANES, str(row_index), lane_id]
			)
		else:
			lane_ids[lane_id] = true
		if not node_ids.has(node_a) or not node_ids.has(node_b):
			errors.append(
				"%s: D-14e lane endpoint unknown row %s (%s–%s)"
				% [FILE_LANES, str(row_index), node_a, node_b]
			)
		if node_a == node_b:
			errors.append(
				"%s: D-14e lane endpoints equal row %s value '%s'"
				% [FILE_LANES, str(row_index), node_a]
			)
		var pair: String = node_a + "|" + node_b if node_a < node_b else node_b + "|" + node_a
		if pairs.has(pair):
			errors.append(
				"%s: D-14e duplicate undirected pair row %s value '%s'"
				% [FILE_LANES, str(row_index), pair]
			)
		else:
			pairs[pair] = true
		if not region_ids.has(region_id):
			errors.append(
				"%s: D-14e region_id unknown row %s value '%s'"
				% [FILE_LANES, str(row_index), region_id]
			)
		if waypoints < 1:
			errors.append(
				"%s: D-14e waypoints must be ≥ 1 row %s value '%s'"
				% [FILE_LANES, str(row_index), str(waypoints)]
			)
		if not SEA_LANE_TYPE_ALLOWED.has(lane_type):
			errors.append(
				"%s: D-14e lane_type allowlist row %s value '%s' (expect SPUR／TRUNK／NEIGHBOR)"
				% [FILE_LANES, str(row_index), lane_type]
			)


static func _write_sea_node_tres(
	rows: Array,
	nodes_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := SeaNode.new()
		def.node_id = String(row["node_id"])
		def.kind = String(row["kind"])
		def.name_zh = String(row["name_zh"])
		def.x = int(row["x"])
		def.y = int(row["y"])
		var path: String = nodes_dir.path_join("%s%s" % [def.node_id, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-29: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_sea_region_tres(
	rows: Array,
	regions_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := SeaRegion.new()
		def.region_id = String(row["region_id"])
		def.name_zh = String(row["name_zh"])
		def.note = String(row["note"])
		var path: String = regions_dir.path_join("%s%s" % [def.region_id, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-29: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_sea_lane_tres(
	rows: Array,
	lanes_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := SeaLane.new()
		def.lane_id = String(row["lane_id"])
		def.node_a = String(row["node_a"])
		def.node_b = String(row["node_b"])
		def.region_id = String(row["region_id"])
		def.length = float(row["length"])
		def.waypoints = int(row["waypoints"])
		def.lane_type = String(row["lane_type"])
		var path: String = lanes_dir.path_join("%s%s" % [def.lane_id, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-29: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _collect_wp18_rule_errors(
	city_rows: Array,
	public_rows: Array,
	ports: Array,
	errors: PackedStringArray
) -> void:
	var port_ids: Dictionary = {}
	for row_variant in ports:
		port_ids[String((row_variant as Dictionary)["port_id"])] = true

	var cb_regex := RegEx.new()
	var compile_err: int = cb_regex.compile(CB_ID_FORMAT_PATTERN)
	assert(compile_err == OK, "CB_ID_FORMAT_PATTERN must compile")

	_collect_wp18_city_center_errors(city_rows, port_ids, errors)
	_collect_wp18_opening_public_errors(public_rows, port_ids, cb_regex, errors)


static func _collect_wp18_city_center_errors(
	rows: Array,
	port_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var seen: Dictionary = {}
	var row_index: int = 0
	for row_variant in rows:
		row_index += 1
		var row: Dictionary = row_variant
		var port_id: String = String(row["port_id"])
		var public_slots: int = int(row["public_slots"])
		if not port_ids.has(port_id):
			errors.append(
				"%s: 10-06 ① unknown port_id row %s value '%s'"
				% [FILE_CITY_CENTER, str(row_index), port_id]
			)
		if public_slots < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field public_slots value %s"
				% [FILE_CITY_CENTER, str(row_index), str(public_slots)]
			)
		if seen.has(port_id):
			errors.append(
				"%s: 10-06 ⑥ duplicate key row %s port_id='%s'"
				% [FILE_CITY_CENTER, str(row_index), port_id]
			)
		else:
			seen[port_id] = true


static func _collect_wp18_opening_public_errors(
	rows: Array,
	port_ids: Dictionary,
	cb_regex: RegEx,
	errors: PackedStringArray
) -> void:
	var seen: Dictionary = {}
	var row_index: int = 0
	for row_variant in rows:
		row_index += 1
		var row: Dictionary = row_variant
		var port_id: String = String(row["port_id"])
		var cb_id: String = String(row["cb_id"])
		var level: int = int(row["level"])
		if not port_ids.has(port_id):
			errors.append(
				"%s: 10-06 ① unknown port_id row %s value '%s'"
				% [FILE_OPENING_PUBLIC, str(row_index), port_id]
			)
		var match: RegExMatch = cb_regex.search(cb_id)
		var full_match := match != null and match.get_string() == cb_id
		if not full_match:
			errors.append(
				"%s: 10-06 ③ cb_id format row %s value '%s' (expect %s)"
				% [FILE_OPENING_PUBLIC, str(row_index), cb_id, CB_ID_FORMAT_PATTERN]
			)
		if level < 0:
			errors.append(
				"%s: 10-06 ⑤ int below zero row %s field level value %s"
				% [FILE_OPENING_PUBLIC, str(row_index), str(level)]
			)
		var key: String = "%s%s%s" % [port_id, COMPOSITE_TRES_JOINER, cb_id]
		if seen.has(key):
			errors.append(
				"%s: 10-06 ⑥ duplicate key row %s (port_id, cb_id)=(%s, %s)"
				% [FILE_OPENING_PUBLIC, str(row_index), port_id, cb_id]
			)
		else:
			seen[key] = true


static func _write_city_center_tres(
	rows: Array,
	city_center_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := CityCenterDef.new()
		def.port_id = String(row["port_id"])
		def.public_slots = int(row["public_slots"])
		var path: String = city_center_dir.path_join("%s%s" % [def.port_id, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-18: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_opening_public_tres(
	rows: Array,
	opening_public_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := OpeningPublic.new()
		def.port_id = String(row["port_id"])
		def.cb_id = String(row["cb_id"])
		def.level = int(row["level"])
		var file_name: String = "%s%s%s%s" % [
			def.port_id, COMPOSITE_TRES_JOINER, def.cb_id, TRES_SUFFIX
		]
		var path: String = opening_public_dir.path_join(file_name)
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-18: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_building_tres(
	rows: Array,
	buildings_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := BuildingDef.new()
		def.type = String(row["type"])
		def.tier = int(row["tier"])
		def.max_workers = int(row["max_workers"])
		def.base_output_per_worker = float(row["base_output_per_worker"])
		def.output_good_id = String(row["output_good_id"])
		def.input1_good_id = String(row["input1_good_id"])
		def.input1_qty = float(row["input1_qty"])
		def.input2_good_id = String(row["input2_good_id"])
		def.input2_qty = float(row["input2_qty"])
		def.build_class = String(row["build_class"])
		var path: String = buildings_dir.path_join("%s%s" % [def.type, TRES_SUFFIX])
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-17: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_opening_workshop_tres(
	rows: Array,
	opening_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := OpeningWorkshop.new()
		def.port_id = String(row["port_id"])
		def.good_id = String(row["good_id"])
		def.count = int(row["count"])
		var file_name: String = "%s%s%s%s" % [
			def.port_id, COMPOSITE_TRES_JOINER, def.good_id, TRES_SUFFIX
		]
		var path: String = opening_dir.path_join(file_name)
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-17: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


static func _write_build_step_tres(
	rows: Array,
	build_queue_dir: String,
	written: PackedStringArray,
	errors: PackedStringArray
) -> void:
	for row_variant in rows:
		var row: Dictionary = row_variant
		var def := BuildStep.new()
		def.port_id = String(row["port_id"])
		def.step = int(row["step"])
		def.cb_id = String(row["cb_id"])
		def.target_level = int(row["target_level"])
		var file_name: String = "%s%s%s%s" % [
			def.port_id, COMPOSITE_TRES_JOINER, str(def.step), TRES_SUFFIX
		]
		var path: String = build_queue_dir.path_join(file_name)
		var err: Error = ResourceSaver.save(def, path)
		if err != OK:
			errors.append("WP-17: failed to write %s (err=%s)" % [path, str(err)])
		else:
			written.append(path)


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
