extends GutTest
## WP-01 Params tests. Fixture values from TechSpec §4 / 1-A8 (fixtures only).


const FIXTURE_ALL := "res://tests/fixtures/params_all_keys.json"
const OFFICIAL := "res://data/params/params.json"
const SCHEMA := "res://data/params/params_schema.json"

const KEY_START_CASH := "PRM-SYS05-START_CASH"
const KEY_ARREARS := "PRM-SYS05-ARREARS_SEASONS_TO_BANKRUPT"
const KEY_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const KEY_CONSERVATION := "PRM-SYS03-CONSERVATION_CHECK_EVERY_TICK"
const KEY_HALF_SPREAD := "PRM-SYS04-HALF_SPREAD"
const KEY_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"


func before_each() -> void:
	Params.load_and_validate(FIXTURE_ALL)


func test_all_section4_params_json_keys_readable() -> void:
	# TechSpec WP-01: every §4 params.json PRM key is readable after load.
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	var errors: Array = Params.load_and_validate(FIXTURE_ALL)
	assert_eq(errors.size(), 0, "fixture with all keys must load cleanly")
	assert_true(Params.is_loaded())

	var ids: Array = schema.keys()
	ids.sort()
	for id_variant in ids:
		var id: String = String(id_variant)
		assert_true(Params.has_prm(id), "missing readable key %s" % id)
		var rule: Dictionary = schema[id]
		var type_name: String = String(rule["type"])
		match type_name:
			"int":
				var got: int = Params.get_int(id)
				assert_typeof(got, TYPE_INT)
			"float":
				var gotf: float = Params.get_float(id)
				assert_typeof(gotf, TYPE_FLOAT)
			"bool_debug_release":
				var gotb: bool = Params.get_bool(id)
				assert_typeof(gotb, TYPE_BOOL)


func test_fixture_values_match_techspec_section4() -> void:
	# Expected values: TechSpec §4 defaults copied into fixture (1-A8 uses 0 / 1).
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	Params.load_and_validate(FIXTURE_ALL)
	assert_eq(Params.get_int(KEY_DAYS_PER_SEASON), floori(float(fixture[KEY_DAYS_PER_SEASON])))
	assert_eq(Params.get_int(KEY_START_CASH), floori(float(fixture[KEY_START_CASH])))
	assert_eq(Params.get_int(KEY_ARREARS), floori(float(fixture[KEY_ARREARS])))
	assert_true(is_equal_approx(Params.get_float(KEY_HALF_SPREAD), float(fixture[KEY_HALF_SPREAD])))
	assert_true(is_equal_approx(Params.get_float(KEY_RATIO_MIN), float(fixture[KEY_RATIO_MIN])))
	# Conservation: OS.is_debug_build() selects debug/release (2.3-04).
	var expected_cons: bool = bool(fixture[KEY_CONSERVATION]["debug"]) if OS.is_debug_build() else bool(fixture[KEY_CONSERVATION]["release"])
	assert_eq(Params.get_bool(KEY_CONSERVATION), expected_cons)


func test_missing_start_cash_rejects() -> void:
	# 1-A8 / TechSpec §4: missing PRM-SYS05-START_CASH → refuse.
	var path := _write_user_fixture_without(KEY_START_CASH)
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_START_CASH, "MISSING_KEY"))


func test_missing_arrears_rejects() -> void:
	# 1-A8 / TechSpec §4: missing PRM-SYS05-ARREARS_SEASONS_TO_BANKRUPT → refuse.
	var path := _write_user_fixture_without(KEY_ARREARS)
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_ARREARS, "MISSING_KEY"))


func test_official_params_json_rejects_without_pending_keys() -> void:
	# Official params.json must not contain 待審 values (1-A8); missing keys refuse boot.
	var errors: Array = Params.load_and_validate(OFFICIAL)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_START_CASH, "MISSING_KEY"))
	assert_true(_has_field_error(errors, KEY_ARREARS, "MISSING_KEY"))


func test_type_mismatch_rejects() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	fixture[KEY_DAYS_PER_SEASON] = true
	var path := _write_user_dict(fixture, "params_bad_type.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_DAYS_PER_SEASON, "TYPE"))


func test_out_of_range_rejects() -> void:
	# Range bounds from schema (TechSpec §4); adjust by 1 (allowed literal).
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	var min_v: float = float(schema[KEY_DAYS_PER_SEASON]["min"])
	fixture[KEY_DAYS_PER_SEASON] = min_v - 1.0
	var path := _write_user_dict(fixture, "params_out_of_range.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_DAYS_PER_SEASON, "RANGE"))


func test_collects_all_missing_errors() -> void:
	# C-06: both 1-A8 missing keys reported together (official file).
	var errors: Array = Params.load_and_validate(OFFICIAL)
	assert_push_error_count(errors.size())
	assert_true(_has_field_error(errors, KEY_START_CASH, "MISSING_KEY"))
	assert_true(_has_field_error(errors, KEY_ARREARS, "MISSING_KEY"))


func _write_user_fixture_without(erase_key: String) -> String:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	fixture.erase(erase_key)
	return _write_user_dict(fixture, "params_without_%s.json" % erase_key)


func _write_user_dict(data: Dictionary, filename: String) -> String:
	var path := "user://%s" % filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "open user fixture")
	file.store_string(JSON.stringify(data))
	file.close()
	return path


func _has_field_error(errors: Array, field: String, code: String) -> bool:
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if String(e.get("field", "")) == field and String(e.get("code", "")) == code:
			return true
	return false
