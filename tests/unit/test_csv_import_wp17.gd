extends GutTest
## WP-17 acceptance: TechSpec 10-05／10-06／10-07 (zones／buildings／opening／build_queue).


const CsvImport := preload("res://tools/csv_import.gd")

const FIXTURE_OK := "res://tests/fixtures/wp17_import_ok/"
const FIXTURE_BAD_FK := "res://tests/fixtures/wp17_bad_fk/"
const FIXTURE_BAD_BUILD_CLASS := "res://tests/fixtures/wp17_bad_build_class/"
const FIXTURE_BAD_CB_ID := "res://tests/fixtures/wp17_bad_cb_id/"
const FIXTURE_BAD_OPEN := "res://tests/fixtures/wp17_bad_open_at_start/"
const FIXTURE_BAD_INT := "res://tests/fixtures/wp17_bad_int_negative/"
const FIXTURE_BAD_UNIQUE := "res://tests/fixtures/wp17_bad_unique/"
const FIXTURE_BAD_AON := "res://tests/fixtures/wp17_bad_all_or_nothing/"

const OUT_ZONES := "res://tests/fixtures/wp17_out/zones/"
const OUT_BUILDINGS := "res://tests/fixtures/wp17_out/buildings/"
const OUT_OPENING := "res://tests/fixtures/wp17_out/opening/"
const OUT_QUEUE := "res://tests/fixtures/wp17_out/build_queue/"

const STALE_ZONE := OUT_ZONES + "STALE__0.tres"
const STALE_BUILDING := OUT_BUILDINGS + "STALE-KEEP.tres"


## 10-07 — zones.csv normal fixture import.
func test_WP17_zones_ok_import() -> void:
	_wipe_out()
	var result: Dictionary = _run_ok_batch()
	assert_true(result["ok"], "source 10-07: zones batch ok")
	assert_true(
		FileAccess.file_exists(OUT_ZONES + "PT-01__0.tres"),
		"source 10-05: zone tres written"
	)
	var zone: ZoneDef = load(OUT_ZONES + "PT-01__0.tres") as ZoneDef
	assert_not_null(zone, "source 10-05: ZoneDef")
	assert_eq(zone.port_id, "PT-01", "source fixture wp17_import_ok/zones.csv")
	assert_eq(zone.zone, 0, "source fixture wp17_import_ok/zones.csv")
	assert_eq(zone.slot_share, 0.5, "source fixture wp17_import_ok/zones.csv")
	assert_eq(zone.rings, 2, "source fixture wp17_import_ok/zones.csv")
	assert_eq(zone.slots, 4, "source fixture wp17_import_ok/zones.csv slots")
	assert_eq(zone.open_at_start, 1, "source fixture wp17_import_ok/zones.csv")
	_wipe_out()


## 10-07 — buildings.csv normal fixture import.
func test_WP17_buildings_ok_import() -> void:
	_wipe_out()
	var result: Dictionary = _run_ok_batch()
	assert_true(result["ok"], "source 10-07: buildings batch ok")
	assert_true(
		FileAccess.file_exists(OUT_BUILDINGS + "WS-RICE.tres"),
		"source 10-05: building tres written"
	)
	var building: BuildingDef = load(OUT_BUILDINGS + "WS-RICE.tres") as BuildingDef
	assert_not_null(building, "source 10-05: BuildingDef")
	assert_eq(building.type, "WS-RICE", "source fixture wp17_import_ok/buildings.csv")
	assert_eq(building.tier, 1, "source fixture wp17_import_ok/buildings.csv")
	assert_eq(building.max_workers, 4, "source fixture wp17_import_ok/buildings.csv")
	assert_eq(building.base_output_per_worker, 1.5, "source fixture wp17_import_ok/buildings.csv")
	assert_eq(building.output_good_id, "GD-001", "source fixture wp17_import_ok/buildings.csv")
	assert_eq(building.input1_good_id, "", "source fixture wp17_import_ok/buildings.csv")
	assert_eq(building.input1_qty, 0, "source fixture wp17_import_ok/buildings.csv")
	assert_eq(building.build_class, "IND1", "source fixture wp17_import_ok/buildings.csv")
	_wipe_out()


## 10-07 — opening_workshops.csv normal fixture import.
func test_WP17_opening_workshops_ok_import() -> void:
	_wipe_out()
	var result: Dictionary = _run_ok_batch()
	assert_true(result["ok"], "source 10-07: opening batch ok")
	assert_true(
		FileAccess.file_exists(OUT_OPENING + "PT-01__GD-001.tres"),
		"source 10-05: opening tres written"
	)
	var opening: OpeningWorkshop = load(OUT_OPENING + "PT-01__GD-001.tres") as OpeningWorkshop
	assert_not_null(opening, "source 10-05: OpeningWorkshop")
	assert_eq(opening.port_id, "PT-01", "source fixture wp17_import_ok/opening_workshops.csv")
	assert_eq(opening.good_id, "GD-001", "source fixture wp17_import_ok/opening_workshops.csv")
	assert_eq(opening.count, 2, "source fixture wp17_import_ok/opening_workshops.csv")
	_wipe_out()


## 10-07 — build_queue.csv normal fixture import.
func test_WP17_build_queue_ok_import() -> void:
	_wipe_out()
	var result: Dictionary = _run_ok_batch()
	assert_true(result["ok"], "source 10-07: build_queue batch ok")
	assert_true(
		FileAccess.file_exists(OUT_QUEUE + "PT-01__0.tres"),
		"source 10-05: build_step tres written"
	)
	var step: BuildStep = load(OUT_QUEUE + "PT-01__0.tres") as BuildStep
	assert_not_null(step, "source 10-05: BuildStep")
	assert_eq(step.port_id, "PT-01", "source fixture wp17_import_ok/build_queue.csv")
	assert_eq(step.step, 0, "source fixture wp17_import_ok/build_queue.csv")
	assert_eq(step.cb_id, "CB-01", "source fixture wp17_import_ok/build_queue.csv")
	assert_eq(step.target_level, 1, "source fixture wp17_import_ok/build_queue.csv")
	_wipe_out()


## 10-06 ① — port_id／good_id must exist in imported ports／goods.
func test_WP17_10_06_1_port_or_good_id_missing() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_BAD_FK, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)
	assert_false(result["ok"], "source 10-06 ①: must abort on unknown good_id")
	var errors: PackedStringArray = result["errors"]
	var found := false
	for message in errors:
		if String(message).find("10-06 ①") >= 0 and String(message).find("GD-999") >= 0:
			found = true
			break
	assert_true(found, "source 10-06 ①: error names unknown good_id GD-999")
	assert_eq((result["written"] as PackedStringArray).size(), 0, "source 10-06 ①: nothing written")
	assert_push_error_count(errors.size(), "source C-06: push_error per collected error")
	_wipe_out()


## 10-06 ② — build_class allowlist.
func test_WP17_10_06_2_build_class_invalid() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_BAD_BUILD_CLASS, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)
	assert_false(result["ok"], "source 10-06 ②: must abort on bad build_class")
	var errors: PackedStringArray = result["errors"]
	var found := false
	for message in errors:
		if String(message).find("10-06 ②") >= 0 and String(message).find("FACTORY") >= 0:
			found = true
			break
	assert_true(found, "source 10-06 ②: error names FACTORY")
	assert_push_error_count(errors.size(), "source C-06: push_error per collected error")
	_wipe_out()


## 10-06 ③ — cb_id format ^CB-[0-9]{2}$.
func test_WP17_10_06_3_cb_id_format() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_BAD_CB_ID, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)
	assert_false(result["ok"], "source 10-06 ③: must abort on bad cb_id")
	var errors: PackedStringArray = result["errors"]
	var found := false
	for message in errors:
		if String(message).find("10-06 ③") >= 0 and String(message).find("CB-1") >= 0:
			found = true
			break
	assert_true(found, "source 10-06 ③: error names CB-1")
	assert_push_error_count(errors.size(), "source C-06: push_error per collected error")
	_wipe_out()


## 10-06 ④ — open_at_start limited to 0／1.
func test_WP17_10_06_4_open_at_start_range() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_BAD_OPEN, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)
	assert_false(result["ok"], "source 10-06 ④: must abort when open_at_start not 0／1")
	var errors: PackedStringArray = result["errors"]
	var found := false
	for message in errors:
		if String(message).find("10-06 ④") >= 0:
			found = true
			break
	assert_true(found, "source 10-06 ④: open_at_start error present")
	assert_push_error_count(errors.size(), "source C-06: push_error per collected error")
	_wipe_out()


## 10-06 ⑤ — int columns must be ≥ 0.
func test_WP17_10_06_5_int_nonnegative() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_BAD_INT, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)
	assert_false(result["ok"], "source 10-06 ⑤: must abort on negative int")
	var errors: PackedStringArray = result["errors"]
	var found := false
	for message in errors:
		if String(message).find("10-06 ⑤") >= 0 and String(message).find("count") >= 0:
			found = true
			break
	assert_true(found, "source 10-06 ⑤: error names count below zero")
	assert_push_error_count(errors.size(), "source C-06: push_error per collected error")
	_wipe_out()


## 10-06 ⑥ — unique keys per CSV.
func test_WP17_10_06_6_unique_keys() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_BAD_UNIQUE, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)
	assert_false(result["ok"], "source 10-06 ⑥: must abort on duplicate key")
	var errors: PackedStringArray = result["errors"]
	var found := false
	for message in errors:
		if String(message).find("10-06 ⑥") >= 0 and String(message).find("duplicate key") >= 0:
			found = true
			break
	assert_true(found, "source 10-06 ⑥: duplicate key error present")
	assert_push_error_count(errors.size(), "source C-06: push_error per collected error")
	_wipe_out()


## 10-07／D-08i — any CSV error → write nothing; stale outputs uncleared.
func test_WP17_all_or_nothing() -> void:
	_wipe_out()
	_ensure_dir(OUT_ZONES)
	_ensure_dir(OUT_BUILDINGS)
	var stale_zone := ZoneDef.new()
	stale_zone.port_id = "STALE"
	stale_zone.zone = 0
	ResourceSaver.save(stale_zone, STALE_ZONE)
	var stale_building := BuildingDef.new()
	stale_building.type = "STALE-KEEP"
	ResourceSaver.save(stale_building, STALE_BUILDING)
	assert_true(FileAccess.file_exists(STALE_ZONE), "precondition stale zone")
	assert_true(FileAccess.file_exists(STALE_BUILDING), "precondition stale building")

	var result: Dictionary = CsvImport.run_batch_wp17(
		FIXTURE_BAD_AON, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)
	assert_false(result["ok"], "source 10-05／D-08i: batch aborts on any CSV error")
	assert_eq((result["written"] as PackedStringArray).size(), 0, "source D-08i: nothing written")
	assert_true(
		FileAccess.file_exists(STALE_ZONE),
		"source D-08i: abort must not clear outputs"
	)
	assert_true(
		FileAccess.file_exists(STALE_BUILDING),
		"source D-08i: abort must not clear outputs"
	)
	assert_false(
		FileAccess.file_exists(OUT_BUILDINGS + "WS-RICE.tres"),
		"source D-08i: no new building tres on abort"
	)
	var errors: PackedStringArray = result["errors"]
	assert_gt(errors.size(), 0, "source D-08i: errors listed")
	assert_push_error_count(errors.size(), "source C-06: push_error per collected error")
	_wipe_out()


func _run_ok_batch() -> Dictionary:
	return CsvImport.run_batch_wp17(
		FIXTURE_OK, OUT_ZONES, OUT_BUILDINGS, OUT_OPENING, OUT_QUEUE
	)


func _wipe_out() -> void:
	_wipe_dir(OUT_ZONES)
	_wipe_dir(OUT_BUILDINGS)
	_wipe_dir(OUT_OPENING)
	_wipe_dir(OUT_QUEUE)


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
