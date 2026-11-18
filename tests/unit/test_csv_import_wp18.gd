extends GutTest
## WP-18 csv_import: zones.slots (D-11a) + city_center／opening_public (D-11c).


const CsvImport := preload("res://tools/csv_import.gd")

const FIXTURE_OK := "res://tests/fixtures/wp18_import_ok/"
const FIXTURE_BAD := "res://tests/fixtures/wp18_bad_public_slots/"

const OUT_CITY := "res://tests/fixtures/wp18_out/city_center/"
const OUT_PUBLIC := "res://tests/fixtures/wp18_out/opening_public/"


func test_WP18_11_07_9_csv_slots_and_new_csvs_ok() -> void:
	_wipe_out()
	var zones: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_OK,
		"res://tests/fixtures/wp18_out/zones/",
		"res://tests/fixtures/wp18_out/buildings/",
		"res://tests/fixtures/wp18_out/opening/",
		"res://tests/fixtures/wp18_out/build_queue/"
	)
	assert_true(zones["ok"], "zones batch must include slots column")
	var zone: ZoneDef = load("res://tests/fixtures/wp18_out/zones/PT-01__0.tres") as ZoneDef
	assert_not_null(zone)
	assert_eq(zone.slots, 4)

	var wp18: Dictionary = CsvImport.run_batch_wp18(FIXTURE_OK, OUT_CITY, OUT_PUBLIC)
	assert_true(wp18["ok"], "wp18 city_center/opening_public import")
	assert_true(FileAccess.file_exists(OUT_CITY + "PT-01.tres"))
	assert_true(FileAccess.file_exists(OUT_PUBLIC + "PT-01__CB-01.tres"))
	var cc: CityCenterDef = load(OUT_CITY + "PT-01.tres") as CityCenterDef
	assert_eq(cc.public_slots, 3)
	_wipe_out()


func test_WP18_11_07_9_csv_new_csvs_fail_10_06() -> void:
	_wipe_out()
	var wp18: Dictionary = CsvImport.run_batch_wp18(FIXTURE_BAD, OUT_CITY, OUT_PUBLIC)
	assert_false(wp18["ok"])
	var errors: PackedStringArray = wp18["errors"]
	var found := false
	for message in errors:
		if String(message).find("public_slots") >= 0 and String(message).find("10-06 ⑤") >= 0:
			found = true
			break
	assert_true(found)
	assert_eq((wp18["written"] as PackedStringArray).size(), 0)
	_wipe_out()


func _wipe_out() -> void:
	for d in [
		"res://tests/fixtures/wp18_out/",
	]:
		var abs := ProjectSettings.globalize_path(d)
		if DirAccess.dir_exists_absolute(abs):
			_wipe_dir(d)


func _wipe_dir(rel: String) -> void:
	var abs := ProjectSettings.globalize_path(rel)
	DirAccess.make_dir_recursive_absolute(abs)
	var dir := DirAccess.open(abs)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var n := dir.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		var path := abs.path_join(n)
		if dir.current_is_dir():
			_wipe_dir(rel.path_join(n))
			DirAccess.remove_absolute(path)
		else:
			DirAccess.remove_absolute(path)
	dir.list_dir_end()