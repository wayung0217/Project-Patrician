extends GutTest
## Acceptance tests for 05_TechSpec 2.1-04 rules ①–⑤ (WP-09).
## No dedicated TST-* IDs exist for csv_import in TechSpec §5 — names cite 2.1-04.


const CsvImport := preload("res://tools/csv_import.gd")

const FIXTURE_GOOD_VALID := "res://tests/fixtures/good_def_valid.csv"
const FIXTURE_GOOD_MISSING := "res://tests/fixtures/good_def_missing_column.csv"
const FIXTURE_GOOD_EXTRA := "res://tests/fixtures/good_def_extra_column.csv"
const FIXTURE_GOOD_TYPE := "res://tests/fixtures/good_def_type_mismatch.csv"
const FIXTURE_PORT_VALID := "res://tests/fixtures/port_def_valid.csv"

## D-08i batch fixtures (2.1-04 ④ — tests load CSV only under fixtures).
const FIXTURE_D08I_OK := "res://tests/fixtures/d08i_import_ok/"
const FIXTURE_D08I_BAD_GOODS := "res://tests/fixtures/d08i_import_bad_goods/"
const FIXTURE_D08I_OUT_GOODS := "res://tests/fixtures/d08i_out/goods/"
const FIXTURE_D08I_OUT_PORTS := "res://tests/fixtures/d08i_out/ports/"
const FIXTURE_D08I_OUT_MARKET := "res://tests/fixtures/d08i_out/market/"
const FIXTURE_D08I_CURVE_OUT := FIXTURE_D08I_OUT_MARKET + "price_curve.tres"
const STALE_GOOD_PATH := FIXTURE_D08I_OUT_GOODS + "STALE-OLD.tres"
const STALE_PORT_PATH := FIXTURE_D08I_OUT_PORTS + "STALE-OLD.tres"
const STALE_CURVE_PATH := FIXTURE_D08I_CURVE_OUT

const DATA_SUBDIRS: Array[String] = [
	"res://data/goods",
	"res://data/ports",
	"res://data/market",
	"res://data/params",
	"res://data/import",
	"res://data/zones",
	"res://data/buildings",
	"res://data/opening",
	"res://data/build_queue",
	"res://data/sea/nodes",
	"res://data/sea/regions",
	"res://data/sea/lanes",
]


## 2.1-04 ① — PortDef CSV rejected when claimed as GoodDef.
func test_2_1_04_rule1_port_csv_rejected_as_good_def() -> void:
	var as_good: Dictionary = CsvImport.import_csv(FIXTURE_PORT_VALID, CsvImport.KIND_GOOD_DEF)
	assert_false(
		as_good["ok"],
		"source 2.1-04 ①: PortDef CSV must not import as GoodDef"
	)
	var as_good_errors: PackedStringArray = as_good["errors"]
	assert_gt(as_good_errors.size(), 0, "source 2.1-04 ①: expect header errors")
	assert_push_error_count(
		as_good_errors.size(),
		"source 2.1-04 ③: push_error once per collected error"
	)


## 2.1-04 ① — GoodDef CSV rejected when claimed as PortDef.
func test_2_1_04_rule1_good_csv_rejected_as_port_def() -> void:
	var as_port: Dictionary = CsvImport.import_csv(FIXTURE_GOOD_VALID, CsvImport.KIND_PORT_DEF)
	assert_false(
		as_port["ok"],
		"source 2.1-04 ①: GoodDef CSV must not import as PortDef"
	)
	var as_port_errors: PackedStringArray = as_port["errors"]
	assert_gt(as_port_errors.size(), 0, "source 2.1-04 ①: expect header errors")
	assert_push_error_count(
		as_port_errors.size(),
		"source 2.1-04 ③: push_error once per collected error"
	)


## 2.1-04 ① — matching kind succeeds (one resource kind per CSV).
func test_2_1_04_rule1_matching_kind_imports() -> void:
	var good_ok: Dictionary = CsvImport.import_csv(FIXTURE_GOOD_VALID, CsvImport.KIND_GOOD_DEF)
	assert_true(good_ok["ok"], "source 2.1-04 ①: GoodDef CSV imports as GoodDef")
	assert_eq((good_ok["rows"] as Array).size(), 1, "source 2.1-04 ①: one data row")

	var port_ok: Dictionary = CsvImport.import_csv(FIXTURE_PORT_VALID, CsvImport.KIND_PORT_DEF)
	assert_true(port_ok["ok"], "source 2.1-04 ①: PortDef CSV imports as PortDef")
	assert_eq((port_ok["rows"] as Array).size(), 1, "source 2.1-04 ①: one data row")


## 2.1-04 ② — headers must equal 03_Systems field names exactly.
func test_2_1_04_rule2_headers_match_field_names() -> void:
	var expected: PackedStringArray = CsvImport.expected_headers(CsvImport.KIND_GOOD_DEF)
	assert_eq(expected[0], "good_id", "source 03_Systems r234")
	assert_eq(expected[expected.size() - 1], "season_mask", "source 03_Systems r241")

	var result: Dictionary = CsvImport.import_csv(FIXTURE_GOOD_VALID, CsvImport.KIND_GOOD_DEF)
	assert_true(result["ok"], "source 2.1-04 ②: valid headers accepted")
	var row: Dictionary = (result["rows"] as Array)[0]
	assert_eq(row["good_id"], "GD-001", "source fixture good_def_valid.csv")
	assert_eq(row["name_zh"], "米", "source fixture good_def_valid.csv")
	assert_eq(row["tier"], 1, "source fixture good_def_valid.csv")
	assert_eq(row["is_staple"], true, "source fixture good_def_valid.csv")
	assert_eq(row["is_build_material"], false, "source fixture good_def_valid.csv")
	assert_eq(row["is_strategic"], false, "source fixture good_def_valid.csv")
	assert_eq(row["base_price_li"], 1000, "source fixture good_def_valid.csv")
	assert_eq(row["season_mask"], 0, "source fixture good_def_valid.csv")


## 2.1-04 ③ — missing column aborts.
func test_2_1_04_rule3_missing_column_aborts() -> void:
	var result: Dictionary = CsvImport.import_csv(FIXTURE_GOOD_MISSING, CsvImport.KIND_GOOD_DEF)
	assert_false(result["ok"], "source 2.1-04 ③ 缺欄: must abort")
	assert_eq((result["rows"] as Array).size(), 0, "source 2.1-04 ③: no partial rows")
	var errors: PackedStringArray = result["errors"]
	var found_missing := false
	for message in errors:
		if String(message).find("missing column: season_mask") >= 0:
			found_missing = true
			break
	assert_true(found_missing, "source 2.1-04 ③: error names missing season_mask")
	assert_push_error_count(errors.size(), "source 2.1-04 ③: push_error per error")


## 2.1-04 ③ — extra column aborts.
func test_2_1_04_rule3_extra_column_aborts() -> void:
	var result: Dictionary = CsvImport.import_csv(FIXTURE_GOOD_EXTRA, CsvImport.KIND_GOOD_DEF)
	assert_false(result["ok"], "source 2.1-04 ③ 多欄: must abort")
	assert_eq((result["rows"] as Array).size(), 0, "source 2.1-04 ③: no partial rows")
	var errors: PackedStringArray = result["errors"]
	var found_extra := false
	for message in errors:
		if String(message).find("extra column: extra_field") >= 0:
			found_extra = true
			break
	assert_true(found_extra, "source 2.1-04 ③: error names extra_field")
	assert_push_error_count(errors.size(), "source 2.1-04 ③: push_error per error")


## 2.1-04 ③ — type mismatch aborts.
func test_2_1_04_rule3_type_mismatch_aborts() -> void:
	var result: Dictionary = CsvImport.import_csv(FIXTURE_GOOD_TYPE, CsvImport.KIND_GOOD_DEF)
	assert_false(result["ok"], "source 2.1-04 ③ 型別不符: must abort")
	assert_eq((result["rows"] as Array).size(), 0, "source 2.1-04 ③: no partial rows")
	var errors: PackedStringArray = result["errors"]
	var found_type := false
	for message in errors:
		if String(message).find("type mismatch") >= 0 and String(message).find("tier") >= 0:
			found_type = true
			break
	assert_true(found_type, "source 2.1-04 ③: error names tier type mismatch")
	assert_push_error_count(errors.size(), "source 2.1-04 ③: push_error per error")


## 2.1-04 ④ — unit tests only load CSV under res://tests/fixtures/.
func test_2_1_04_rule4_tests_use_fixtures_only() -> void:
	var fixture_paths: Array[String] = [
		FIXTURE_GOOD_VALID,
		FIXTURE_GOOD_MISSING,
		FIXTURE_GOOD_EXTRA,
		FIXTURE_GOOD_TYPE,
		FIXTURE_PORT_VALID,
		FIXTURE_D08I_OK + "goods.csv",
		FIXTURE_D08I_OK + "ports.csv",
		FIXTURE_D08I_OK + "role_cells.csv",
		FIXTURE_D08I_OK + "price_curve.csv",
		FIXTURE_D08I_BAD_GOODS + "goods.csv",
	]
	for path in fixture_paths:
		assert_true(
			CsvImport.is_fixture_path(path),
			"source 2.1-04 ④: %s must be under fixtures" % path
		)
		assert_false(
			CsvImport.is_formal_data_path(path),
			"source 2.1-04 ④: fixture must not be formal data path"
		)


## 2.1-04 ⑤ / N-09 — no hand-written formal CSV or .tres under res://data/.
func test_2_1_04_rule5_no_formal_data_csv_or_tres() -> void:
	for dir_path in DATA_SUBDIRS:
		assert_true(DirAccess.dir_exists_absolute(dir_path), "data dir exists: %s" % dir_path)
		var dir: DirAccess = DirAccess.open(dir_path)
		assert_not_null(dir, "open data dir: %s" % dir_path)
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var lower: String = file_name.to_lower()
				var is_csv := lower.ends_with(".csv")
				var is_tres := lower.ends_with(".tres")
				assert_false(
					is_csv or is_tres,
					"source 2.1-04 ⑤: formal data must not contain %s/%s" % [dir_path, file_name]
				)
			file_name = dir.get_next()
		dir.list_dir_end()


## D-08i / TST — fixed formal import／output path constants.
func test_D08i_fixed_in_out_paths() -> void:
	assert_eq(CsvImport.IMPORT_DIR, "res://data/import/", "source D-08i import dir")
	assert_eq(CsvImport.IMPORT_GOODS_CSV, "res://data/import/goods.csv", "source D-08i goods.csv")
	assert_eq(CsvImport.IMPORT_PORTS_CSV, "res://data/import/ports.csv", "source D-08i ports.csv")
	assert_eq(
		CsvImport.IMPORT_ROLE_CELLS_CSV,
		"res://data/import/role_cells.csv",
		"source D-08i role_cells.csv"
	)
	assert_eq(
		CsvImport.IMPORT_PRICE_CURVE_CSV,
		"res://data/import/price_curve.csv",
		"source D-08i price_curve.csv"
	)
	assert_eq(CsvImport.GOODS_OUT_DIR, "res://data/goods/", "source D-08i goods out")
	assert_eq(CsvImport.PORTS_OUT_DIR, "res://data/ports/", "source D-08i ports out")
	assert_eq(
		CsvImport.PRICE_CURVE_OUT_PATH,
		"res://data/market/price_curve.tres",
		"source D-08i price_curve out"
	)


## D-08i / TST — any CSV error → write nothing; errors listed once (all-or-nothing).
func test_D08i_all_or_nothing_no_write_on_error() -> void:
	_wipe_d08i_out()
	# Plant a stale output that must remain when batch aborts (no clear+write on error).
	_ensure_dir(FIXTURE_D08I_OUT_GOODS)
	var stale := GoodDef.new()
	stale.good_id = "STALE-KEEP"
	ResourceSaver.save(stale, FIXTURE_D08I_OUT_GOODS + "STALE-KEEP.tres")

	var result: Dictionary = CsvImport.run_batch(
		FIXTURE_D08I_BAD_GOODS,
		FIXTURE_D08I_OUT_GOODS,
		FIXTURE_D08I_OUT_PORTS,
		FIXTURE_D08I_OUT_MARKET
	)
	assert_false(result["ok"], "source D-08i: batch must abort when any CSV fails")
	var errors: PackedStringArray = result["errors"]
	assert_gt(errors.size(), 0, "source D-08i: errors listed")
	var found_missing := false
	for message in errors:
		if String(message).find("missing column: season_mask") >= 0:
			found_missing = true
			break
	assert_true(found_missing, "source D-08i: goods.csv missing-column error present")
	assert_eq((result["written"] as PackedStringArray).size(), 0, "source D-08i: nothing written")
	assert_true(
		FileAccess.file_exists(FIXTURE_D08I_OUT_GOODS + "STALE-KEEP.tres"),
		"source D-08i: abort must not clear／overwrite outputs"
	)
	assert_false(
		FileAccess.file_exists(FIXTURE_D08I_OUT_GOODS + "GD-001.tres"),
		"source D-08i: no new good tres on abort"
	)
	assert_false(
		FileAccess.file_exists(FIXTURE_D08I_CURVE_OUT),
		"source D-08i: no price_curve.tres on abort"
	)
	assert_push_error_count(errors.size(), "source D-08i: push_error once per collected error")
	_wipe_d08i_out()


## D-08i / TST — successful batch writes goods／ports／price_curve from four CSVs.
func test_D08i_batch_writes_all_outputs() -> void:
	_wipe_d08i_out()
	var result: Dictionary = CsvImport.run_batch(
		FIXTURE_D08I_OK,
		FIXTURE_D08I_OUT_GOODS,
		FIXTURE_D08I_OUT_PORTS,
		FIXTURE_D08I_OUT_MARKET
	)
	assert_true(result["ok"], "source D-08i: valid four CSVs must succeed")
	assert_eq((result["errors"] as PackedStringArray).size(), 0, "source D-08i: no errors")
	assert_true(FileAccess.file_exists(FIXTURE_D08I_OUT_GOODS + "GD-001.tres"), "source D-08i good out")
	assert_true(FileAccess.file_exists(FIXTURE_D08I_OUT_PORTS + "PT-01.tres"), "source D-08i port out")
	assert_true(FileAccess.file_exists(FIXTURE_D08I_CURVE_OUT), "source D-08i curve out")

	var good: GoodDef = load(FIXTURE_D08I_OUT_GOODS + "GD-001.tres") as GoodDef
	assert_not_null(good, "source D-08i: GoodDef resource")
	assert_eq(good.good_id, "GD-001", "source fixture d08i_import_ok/goods.csv")
	assert_eq(good.name_zh, "米", "source fixture d08i_import_ok/goods.csv")
	assert_eq(good.base_price_li, 1000, "source fixture d08i_import_ok/goods.csv")

	var port: PortDef = load(FIXTURE_D08I_OUT_PORTS + "PT-01.tres") as PortDef
	assert_not_null(port, "source D-08i: PortDef resource")
	assert_eq(port.port_id, "PT-01", "source fixture d08i_import_ok/ports.csv")
	assert_true(port.role_cells.has("GD-001"), "source D-08i: role_cells merged by good_id")
	var cell: RoleCell = port.role_cells["GD-001"]
	assert_eq(cell.role, CsvImport.ROLE_VALUE_PRODUCER, "source fixture role PRODUCER")
	assert_eq(cell.base_output_per_season, 10, "source fixture d08i_import_ok/role_cells.csv")

	var curve: PriceCurve = load(FIXTURE_D08I_CURVE_OUT) as PriceCurve
	assert_not_null(curve, "source D-08i: PriceCurve resource")
	assert_eq(curve.weeks.size(), 5, "source fixture d08i_import_ok/price_curve.csv rows")
	assert_eq(curve.weeks[0], 0.0, "source PRM-SYS04-CURVE_W1")
	assert_eq(curve.mults[0], 2.0, "source PRM-SYS04-CURVE_M1")
	assert_eq(curve.mults[4], 0.6, "source PRM-SYS04-CURVE_M5")
	_wipe_d08i_out()


## D-08i / TST — clear old .tres outputs before writing new ones.
func test_D08i_clears_old_outputs_before_write() -> void:
	_wipe_d08i_out()
	_ensure_dir(FIXTURE_D08I_OUT_GOODS)
	_ensure_dir(FIXTURE_D08I_OUT_PORTS)
	_ensure_dir(FIXTURE_D08I_OUT_MARKET)
	var stale_good := GoodDef.new()
	stale_good.good_id = "STALE-OLD"
	ResourceSaver.save(stale_good, STALE_GOOD_PATH)
	var stale_port := PortDef.new()
	stale_port.port_id = "STALE-OLD"
	ResourceSaver.save(stale_port, STALE_PORT_PATH)
	var stale_curve := PriceCurve.new()
	stale_curve.weeks = PackedFloat64Array([0.0])
	stale_curve.mults = PackedFloat64Array([1.0])
	ResourceSaver.save(stale_curve, STALE_CURVE_PATH)
	assert_true(FileAccess.file_exists(STALE_GOOD_PATH), "precondition stale good")
	assert_true(FileAccess.file_exists(STALE_PORT_PATH), "precondition stale port")
	assert_true(FileAccess.file_exists(STALE_CURVE_PATH), "precondition stale curve")

	var result: Dictionary = CsvImport.run_batch(
		FIXTURE_D08I_OK,
		FIXTURE_D08I_OUT_GOODS,
		FIXTURE_D08I_OUT_PORTS,
		FIXTURE_D08I_OUT_MARKET
	)
	assert_true(result["ok"], "source D-08i: batch succeeds after clear")
	assert_false(FileAccess.file_exists(STALE_GOOD_PATH), "source D-08i: stale good cleared")
	assert_false(FileAccess.file_exists(STALE_PORT_PATH), "source D-08i: stale port cleared")
	assert_true(FileAccess.file_exists(FIXTURE_D08I_OUT_GOODS + "GD-001.tres"), "source D-08i new good")
	assert_true(FileAccess.file_exists(FIXTURE_D08I_OUT_PORTS + "PT-01.tres"), "source D-08i new port")
	assert_true(FileAccess.file_exists(FIXTURE_D08I_CURVE_OUT), "source D-08i new curve")
	var curve: PriceCurve = load(FIXTURE_D08I_CURVE_OUT) as PriceCurve
	assert_eq(curve.weeks.size(), 5, "source D-08i: curve replaced not appended")
	_wipe_d08i_out()


func _wipe_d08i_out() -> void:
	_wipe_dir(FIXTURE_D08I_OUT_GOODS)
	_wipe_dir(FIXTURE_D08I_OUT_PORTS)
	_wipe_dir(FIXTURE_D08I_OUT_MARKET)


func _wipe_dir(dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs_path):
		var d := DirAccess.open(dir)
		if d:
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if not d.current_is_dir():
					d.remove(fn)
				fn = d.get_next()
			d.list_dir_end()
	DirAccess.make_dir_recursive_absolute(abs_path)


func _ensure_dir(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
