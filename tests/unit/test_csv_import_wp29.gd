extends GutTest
## WP-29 csv_import: nodes／regions／lanes (D-14e) all-or-nothing batch.


const CsvImport := preload("res://tools/csv_import.gd")

const FIXTURE_OK := "res://tests/fixtures/wp29_sea_ok/"
const FIXTURE_BAD_LANE := "res://tests/fixtures/wp29_sea_bad_lane/"
const FIXTURE_BAD_MISSING := "res://tests/fixtures/wp29_csv_bad_missing/"

const OUT_NODES := "res://tests/fixtures/wp29_out/nodes/"
const OUT_REGIONS := "res://tests/fixtures/wp29_out/regions/"
const OUT_LANES := "res://tests/fixtures/wp29_out/lanes/"


func test_WP29_D14e_batch_ok_writes_sea_tres() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp29(FIXTURE_OK, OUT_NODES, OUT_REGIONS, OUT_LANES)
	assert_true(result["ok"], "wp29 batch: %s" % str(result["errors"]))
	assert_eq((result["written"] as PackedStringArray).size(), 29 + 7 + 55)
	assert_true(FileAccess.file_exists(OUT_NODES + "PT-03.tres"))
	assert_true(FileAccess.file_exists(OUT_NODES + "JN-01.tres"))
	assert_true(FileAccess.file_exists(OUT_REGIONS + "RG-01.tres"))
	assert_true(FileAccess.file_exists(OUT_LANES + "LN-01.tres"))
	var node: SeaNode = load(OUT_NODES + "PT-03.tres") as SeaNode
	assert_eq(node.kind, SeaNode.KIND_PORT)
	assert_eq(node.name_zh, "福州")
	assert_eq(node.x, 215)
	var lane: SeaLane = load(OUT_LANES + "LN-01.tres") as SeaLane
	assert_eq(lane.waypoints, 2)
	assert_eq(lane.lane_type, SeaLane.TYPE_SPUR)
	assert_eq(lane.node_a, "PT-03")
	assert_eq(CsvImport.SEA_NODES_OUT_DIR, "res://data/sea/nodes/")
	assert_eq(CsvImport.SEA_REGIONS_OUT_DIR, "res://data/sea/regions/")
	assert_eq(CsvImport.SEA_LANES_OUT_DIR, "res://data/sea/lanes/")
	_wipe_out()


func test_WP29_D14e_batch_all_or_nothing_on_bad_lane() -> void:
	_wipe_out()
	# Plant stale output that must remain when batch aborts.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_NODES))
	var stale := SeaNode.new()
	stale.node_id = "STALE"
	stale.kind = SeaNode.KIND_JUNCTION
	stale.name_zh = "stale"
	ResourceSaver.save(stale, OUT_NODES + "STALE.tres")

	var result: Dictionary = CsvImport.run_batch_wp29(
		FIXTURE_BAD_LANE, OUT_NODES, OUT_REGIONS, OUT_LANES
	)
	assert_false(result["ok"])
	assert_eq((result["written"] as PackedStringArray).size(), 0)
	assert_true(FileAccess.file_exists(OUT_NODES + "STALE.tres"), "no clear+write on error")
	assert_false(FileAccess.file_exists(OUT_LANES + "LN-01.tres"))
	assert_push_error_count((result["errors"] as PackedStringArray).size())
	_wipe_out()


func test_WP29_D14e_header_mismatch_aborts_batch() -> void:
	_wipe_out()
	var result: Dictionary = CsvImport.run_batch_wp29(
		FIXTURE_BAD_MISSING, OUT_NODES, OUT_REGIONS, OUT_LANES
	)
	assert_false(result["ok"])
	assert_eq((result["written"] as PackedStringArray).size(), 0)
	assert_push_error_count((result["errors"] as PackedStringArray).size())
	_wipe_out()


func _wipe_out() -> void:
	for d in ["res://tests/fixtures/wp29_out/"]:
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
