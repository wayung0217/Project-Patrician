extends GutTest
## WP-34 csv_import: demand_rates／satisfaction_weights／substitutions (D-25／D-36b／c).


const CsvImport := preload("res://tools/csv_import.gd")

const FIXTURE_OK := "res://tests/fixtures/demand/ok/"
const FIXTURE_MISSING := "res://tests/fixtures/demand/bad_missing_col/"
const FIXTURE_EXTRA := "res://tests/fixtures/demand/bad_extra_col/"
const FIXTURE_TYPE := "res://tests/fixtures/demand/bad_type/"
const FIXTURE_RATE_DEC := "res://tests/fixtures/demand/bad_rate_decimals/"
const FIXTURE_WEIGHT_SUM := "res://tests/fixtures/demand/bad_weight_sum/"
const FIXTURE_WEIGHT_NONINT := "res://tests/fixtures/demand/bad_weight_nonint/"
const FIXTURE_PPM_DEC := "res://tests/fixtures/demand/bad_ppm_decimals/"

const OUT_RATES := "res://tests/fixtures/demand/out/rates/"
const OUT_WEIGHTS := "res://tests/fixtures/demand/out/weights/"
const OUT_SUBST := "res://tests/fixtures/demand/out/substitutions/"

const RATE_SCALE := 100
const PPM_SCALE := 1000000
const WEIGHT_SUM := 100


func before_each() -> void:
	_wipe_out()


func test_WP34_headers_match_docs_spec_csv() -> void:
	## Special evidence (a): header constants == CSV first rows verbatim.
	var rate_h: PackedStringArray = CsvImport.expected_headers(CsvImport.KIND_DEMAND_RATE)
	var weight_h: PackedStringArray = CsvImport.expected_headers(CsvImport.KIND_SATISFACTION_WEIGHT)
	var subst_h: PackedStringArray = CsvImport.expected_headers(CsvImport.KIND_SUBSTITUTION_RULE)
	assert_eq(",".join(rate_h), _first_line("res://docs/spec/demand_rates.csv"))
	assert_eq(",".join(weight_h), _first_line("res://docs/spec/satisfaction_weights.csv"))
	assert_eq(",".join(subst_h), _first_line("res://docs/spec/substitutions.csv"))
	assert_eq(",".join(rate_h), _first_line(FIXTURE_OK.path_join("demand_rates.csv")))


func test_WP34_batch_ok_writes_28_28_7() -> void:
	var result: Dictionary = _run_ok()
	assert_true(result["ok"], "wp34 batch: %s" % str(result["errors"]))
	assert_eq((result["written"] as PackedStringArray).size(), 28 + 28 + 7)
	var rice: DemandRate = load(OUT_RATES + "GD-001.tres") as DemandRate
	assert_eq(rice.poor_rate_cj, 594)
	assert_eq(rice.citizen_rate_cj, 594)
	assert_eq(rice.rich_rate_cj, 594)
	var w: SatisfactionWeight = load(OUT_WEIGHTS + "GD-001.tres") as SatisfactionWeight
	assert_eq(w.poor_weight_pct, 30)
	var s: SubstitutionRule = load(OUT_SUBST + "GD-001__GD-014.tres") as SubstitutionRule
	assert_eq(s.cap_ppm, 300000)
	assert_eq(s.util_ppm, 700000)


func test_WP34_row_roundtrip_28_28_7() -> void:
	## Special evidence (c): import vs CSV row-by-row.
	assert_true(_run_ok()["ok"])
	var rate_lines: PackedStringArray = _data_lines(FIXTURE_OK.path_join("demand_rates.csv"))
	assert_eq(rate_lines.size(), 28)
	for line in rate_lines:
		var cols: PackedStringArray = line.split(",")
		var gid: String = cols[0]
		var def: DemandRate = load(OUT_RATES + gid + ".tres") as DemandRate
		assert_eq(
			def.poor_rate_cj,
			int(CsvImport.parse_scaled_decimal(cols[1], RATE_SCALE, 2)["value"])
		)
		assert_eq(
			def.citizen_rate_cj,
			int(CsvImport.parse_scaled_decimal(cols[2], RATE_SCALE, 2)["value"])
		)
		assert_eq(
			def.rich_rate_cj,
			int(CsvImport.parse_scaled_decimal(cols[3], RATE_SCALE, 2)["value"])
		)
	var weight_lines: PackedStringArray = _data_lines(
		FIXTURE_OK.path_join("satisfaction_weights.csv")
	)
	assert_eq(weight_lines.size(), 28)
	for line2 in weight_lines:
		var cols2: PackedStringArray = line2.split(",")
		var wdef: SatisfactionWeight = load(OUT_WEIGHTS + cols2[0] + ".tres") as SatisfactionWeight
		assert_eq(wdef.poor_weight_pct, cols2[1].to_int())
		assert_eq(wdef.citizen_weight_pct, cols2[2].to_int())
		assert_eq(wdef.rich_weight_pct, cols2[3].to_int())
	var subst_lines: PackedStringArray = _data_lines(FIXTURE_OK.path_join("substitutions.csv"))
	assert_eq(subst_lines.size(), 7)
	for line3 in subst_lines:
		var cols3: PackedStringArray = line3.split(",")
		var path: String = OUT_SUBST + cols3[0] + "__" + cols3[1] + ".tres"
		var sdef: SubstitutionRule = load(path) as SubstitutionRule
		assert_eq(
			sdef.cap_ppm, int(CsvImport.parse_scaled_decimal(cols3[2], PPM_SCALE, 6)["value"])
		)
		assert_eq(
			sdef.util_ppm, int(CsvImport.parse_scaled_decimal(cols3[3], PPM_SCALE, 6)["value"])
		)


func test_WP34_missing_col_aborts() -> void:
	var result: Dictionary = _run(FIXTURE_MISSING)
	assert_false(result["ok"])
	assert_eq((result["written"] as PackedStringArray).size(), 0)
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP34_extra_col_aborts() -> void:
	var result: Dictionary = _run(FIXTURE_EXTRA)
	assert_false(result["ok"])
	assert_eq((result["written"] as PackedStringArray).size(), 0)
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP34_type_mismatch_aborts() -> void:
	var result: Dictionary = _run(FIXTURE_TYPE)
	assert_false(result["ok"])
	assert_eq((result["written"] as PackedStringArray).size(), 0)
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP34_parse_scaled_decimal_examples() -> void:
	## Special evidence (h): 5.94→594、0.3→300000、超位报错.
	var a: Dictionary = CsvImport.parse_scaled_decimal("5.94", RATE_SCALE, 2)
	assert_true(a["ok"])
	assert_eq(int(a["value"]), 594)
	var b: Dictionary = CsvImport.parse_scaled_decimal("0.3", PPM_SCALE, 6)
	assert_true(b["ok"])
	assert_eq(int(b["value"]), 300000)
	var c: Dictionary = CsvImport.parse_scaled_decimal("5.941", RATE_SCALE, 2)
	assert_false(c["ok"])
	var d: Dictionary = CsvImport.parse_scaled_decimal("0.3000001", PPM_SCALE, 6)
	assert_false(d["ok"])


func test_WP34_rate_excess_decimals_aborts() -> void:
	var result: Dictionary = _run(FIXTURE_RATE_DEC)
	assert_false(result["ok"])
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP34_ppm_excess_decimals_aborts() -> void:
	var result: Dictionary = _run(FIXTURE_PPM_DEC)
	assert_false(result["ok"])
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP34_weight_non_int_aborts() -> void:
	var result: Dictionary = _run(FIXTURE_WEIGHT_NONINT)
	assert_false(result["ok"])
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP34_weight_sum_neq_weight_sum_aborts() -> void:
	var result: Dictionary = _run(FIXTURE_WEIGHT_SUM)
	assert_false(result["ok"])
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP34_all_or_nothing_keeps_stale_on_error() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_RATES))
	var stale := DemandRate.new()
	stale.good_id = "STALE"
	stale.poor_rate_cj = 1
	ResourceSaver.save(stale, OUT_RATES + "STALE.tres")
	var result: Dictionary = _run(FIXTURE_TYPE)
	assert_false(result["ok"])
	assert_true(FileAccess.file_exists(OUT_RATES + "STALE.tres"), "no clear+write on error")
	assert_push_error_count((result["errors"] as PackedStringArray).size())


# --- helpers ---


func _run_ok() -> Dictionary:
	return _run(FIXTURE_OK)


func _run(import_dir: String) -> Dictionary:
	return CsvImport.run_batch_demand(
		import_dir, OUT_RATES, OUT_WEIGHTS, OUT_SUBST, RATE_SCALE, PPM_SCALE, WEIGHT_SUM
	)


func _first_line(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_ne(f, null, path)
	var line: String = f.get_line().strip_edges()
	f.close()
	return line


func _data_lines(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_ne(f, null, path)
	f.get_line() # header
	var out := PackedStringArray()
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.is_empty():
			continue
		out.append(line)
	f.close()
	return out


func _wipe_out() -> void:
	for d in [OUT_RATES, OUT_WEIGHTS, OUT_SUBST, "res://tests/fixtures/demand/out/"]:
		var abs_path := ProjectSettings.globalize_path(d)
		if DirAccess.dir_exists_absolute(abs_path):
			_wipe_dir(d)


func _wipe_dir(rel: String) -> void:
	var abs_path := ProjectSettings.globalize_path(rel)
	DirAccess.make_dir_recursive_absolute(abs_path)
	var d := DirAccess.open(rel)
	if d == null:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir():
			d.remove(fn)
		elif fn != "." and fn != "..":
			_wipe_dir(rel.path_join(fn))
			d.remove(fn)
		fn = d.get_next()
	d.list_dir_end()
