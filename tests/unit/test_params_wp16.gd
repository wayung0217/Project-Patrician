extends GutTest
## WP-16 Params SYS-07／SYS-08 load + validate (TechSpec 10-02..10-04／10-07).
## Fixture values only (D-09f); official params.json must not gain Phase 1 keys.


const FIXTURE_ALL := "res://tests/fixtures/params_all_keys.json"
const SCHEMA := "res://data/params/params_schema.json"

const KEY_SCALAR := "PRM-SYS07-SAT_IN_MIN"
const KEY_OBJECT := "PRM-SYS08-CLASS_SPEND_LI"
const KEY_ARRAY := "PRM-SYS07-TEMPLE_BONUS"
const KEY_ENUM := "PRM-SYS08-DEMAND_BASIS"
const KEY_NOVALUE := "PRM-SYS07-SAT_MAX_STEP"
const KEY_BUILD_CASH := "PRM-SYS08-BUILD_CASH_LI"
const KEY_BELOW_MIN := "PRM-SYS08-POP_UNIT"
const KEY_TYPE := "PRM-SYS07-LAMBDA_RING"


func before_each() -> void:
	Params.load_and_validate(FIXTURE_ALL)


func test_WP16_10_07_scalar_loads() -> void:
	# TechSpec 10-07: scalar shape loads and is readable.
	var errors: Array = Params.load_and_validate(FIXTURE_ALL)
	assert_eq(errors.size(), 0)
	assert_true(Params.is_loaded())
	assert_true(Params.has_prm(KEY_SCALAR))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	assert_eq(Params.get_int(KEY_SCALAR), floori(float(fixture[KEY_SCALAR])))


func test_WP16_10_07_object_loads() -> void:
	# TechSpec 10-07 / D-10a: object shape (exact POOR／CITIZEN／RICH) loads.
	var errors: Array = Params.load_and_validate(FIXTURE_ALL)
	assert_eq(errors.size(), 0)
	var got: Variant = Params.get_value(KEY_OBJECT)
	assert_typeof(got, TYPE_DICTIONARY)
	var d: Dictionary = got
	assert_true(d.has("POOR"))
	assert_true(d.has("CITIZEN"))
	assert_true(d.has("RICH"))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	assert_eq(int(d["POOR"]), floori(float(fixture[KEY_OBJECT]["POOR"])))


func test_WP16_10_07_array_loads() -> void:
	# TechSpec 10-07 / D-10a: fixed-length array shape loads.
	var errors: Array = Params.load_and_validate(FIXTURE_ALL)
	assert_eq(errors.size(), 0)
	var got: Variant = Params.get_value(KEY_ARRAY)
	assert_typeof(got, TYPE_ARRAY)
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	var expect_len: int = int(schema[KEY_ARRAY]["length"])
	assert_eq((got as Array).size(), expect_len)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	assert_eq(int((got as Array)[0]), floori(float(fixture[KEY_ARRAY][0])))


func test_WP16_10_07_missing_key_rejects() -> void:
	# TechSpec 10-07 / 10-04: missing Phase 1 key → refuse boot.
	var path := _write_without(KEY_SCALAR)
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_SCALAR, "MISSING_KEY"))


func test_WP16_10_07_object_extra_key_rejects() -> void:
	# TechSpec 10-07 / D-10a: object extra key → ERR.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	var obj: Dictionary = fixture[KEY_BUILD_CASH].duplicate(true)
	obj["EXTRA_CLASS"] = 1
	fixture[KEY_BUILD_CASH] = obj
	var path := _write_user_dict(fixture, "params_wp16_object_extra.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, "%s.EXTRA_CLASS" % KEY_BUILD_CASH, "UNKNOWN_KEY"))


func test_WP16_10_07_type_mismatch_rejects() -> void:
	# TechSpec 10-07: type mismatch → ERR.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	fixture[KEY_TYPE] = true
	var path := _write_user_dict(fixture, "params_wp16_bad_type.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_TYPE, "TYPE"))


func test_WP16_10_07_below_min_rejects() -> void:
	# TechSpec 10-07 / 10-03 / D-10b: below SYS-08 H-column floor → ERR.
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	var min_v: float = float(schema[KEY_BELOW_MIN]["min"])
	fixture[KEY_BELOW_MIN] = min_v - 1.0
	var path := _write_user_dict(fixture, "params_wp16_below_min.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_BELOW_MIN, "RANGE"))


func test_WP16_10_07_enum_rejects() -> void:
	# TechSpec 10-07 / 10-03: DEMAND_BASIS not in {1,2} → ERR.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	fixture[KEY_ENUM] = 0
	var path := _write_user_dict(fixture, "params_wp16_enum.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_ENUM, "ENUM"))


func test_WP16_10_07_novalue_key_missing_rejects() -> void:
	# TechSpec 10-07 / 10-04 / D-09f: [待審]／無值 key missing → refuse; no invented default.
	var path := _write_without(KEY_NOVALUE)
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_NOVALUE, "MISSING_KEY"))


func test_WP16_brief_empty_value_rejects() -> void:
	# Brief WP-16: empty value → refuse boot (no invented defaults).
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	fixture[KEY_SCALAR] = null
	var path := _write_user_dict(fixture, "params_wp16_empty.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())
	assert_true(_has_field_error(errors, KEY_SCALAR, "EMPTY_VALUE"))


func _write_without(erase_key: String) -> String:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_ALL))
	fixture.erase(erase_key)
	return _write_user_dict(fixture, "params_wp16_without_%s.json" % erase_key.replace("/", "_"))


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
