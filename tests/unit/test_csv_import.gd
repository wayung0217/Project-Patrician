extends GutTest
## Acceptance tests for 05_TechSpec 2.1-04 rules ①–⑤ (WP-09).
## No dedicated TST-* IDs exist for csv_import in TechSpec §5 — names cite 2.1-04.


const CsvImport := preload("res://tools/csv_import.gd")

const FIXTURE_GOOD_VALID := "res://tests/fixtures/good_def_valid.csv"
const FIXTURE_GOOD_MISSING := "res://tests/fixtures/good_def_missing_column.csv"
const FIXTURE_GOOD_EXTRA := "res://tests/fixtures/good_def_extra_column.csv"
const FIXTURE_GOOD_TYPE := "res://tests/fixtures/good_def_type_mismatch.csv"
const FIXTURE_PORT_VALID := "res://tests/fixtures/port_def_valid.csv"

const DATA_SUBDIRS: Array[String] = [
	"res://data/goods",
	"res://data/ports",
	"res://data/market",
	"res://data/params",
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
