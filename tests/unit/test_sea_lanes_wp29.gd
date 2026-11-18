extends GutTest
## WP-29 / TechSpec 13-06 SeaLanes acceptance (TST-SYS14-01..04、09 path；13-05 ties).


const CsvImport := preload("res://tools/csv_import.gd")

const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const SEA_OK_CSV := "res://tests/fixtures/wp29_sea_ok/"
const ROOT := "user://wp29_sea/"
const GOODS_ROOT := ROOT + "goods/"
const PORTS_ROOT := ROOT + "ports/"
const SEA_ROOT := ROOT + "sea/"

const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"
const ANCHOR_LI := 1000

const PT_YUE := "PT-01" ## 月港
const PT_FUZHOU := "PT-03" ## 福州
const PT_DAYUAN := "PT-07" ## 大員
const PT_NAHA := "PT-11" ## 那霸


func before_each() -> void:
	_wipe_dir(ROOT)
	SeaLanes._loaded = false
	SeaLanes._nodes = {}
	SeaLanes._regions = {}
	SeaLanes._lanes = {}
	SeaLanes._adj = {}
	SeaLanes._last_error = {}


func test_TST_SYS14_01_55_lanes_zero_errors_16_ports_reachable() -> void:
	_boot_full_chart()
	assert_true(SeaLanes.is_loaded())
	assert_eq(SeaLanes._lanes.size(), 55)
	var port_count := 0
	for node_variant in SeaLanes.nodes():
		var node: SeaNode = node_variant
		if node.kind == SeaNode.KIND_PORT:
			port_count += 1
	assert_eq(port_count, 16)
	var ports: PackedStringArray = PackedStringArray()
	for id_variant in PortRegistry.all_ids():
		ports.append(String(id_variant))
	ports.sort()
	for i in range(ports.size()):
		for j in range(i + 1, ports.size()):
			var p: Array = SeaLanes.path(ports[i], ports[j])
			assert_gt(p.size(), 0, "%s→%s must be reachable" % [ports[i], ports[j]])


func test_TST_SYS14_02_unknown_node_and_waypoints_zero_both_listed() -> void:
	_setup_ports_goods(16)
	var sea := _install_sea_ok()
	# Inject two bad lanes into tres after import.
	var bad_unknown := SeaLane.new()
	bad_unknown.lane_id = "LN-99"
	bad_unknown.node_a = "PT-01"
	bad_unknown.node_b = "JN-99"
	bad_unknown.region_id = "RG-01"
	bad_unknown.length = 10.0
	bad_unknown.waypoints = 2
	bad_unknown.lane_type = SeaLane.TYPE_SPUR
	ResourceSaver.save(bad_unknown, sea["lanes"] + "LN-99.tres")

	var bad_wp := SeaLane.new()
	bad_wp.lane_id = "LN-98"
	bad_wp.node_a = "PT-03"
	bad_wp.node_b = "JN-12"
	bad_wp.region_id = "RG-01"
	bad_wp.length = 10.0
	bad_wp.waypoints = 0
	bad_wp.lane_type = SeaLane.TYPE_SPUR
	ResourceSaver.save(bad_wp, sea["lanes"] + "LN-98.tres")

	var errors: Array = SeaLanes.load_and_validate(sea["nodes"], sea["regions"], sea["lanes"])
	assert_gt(errors.size(), 0)
	assert_false(SeaLanes.is_loaded())
	var unknown_listed := false
	var wp_zero_listed := false
	for err_variant in errors:
		var err: Dictionary = err_variant
		assert_eq(StringName(err.get(ErrorInfoUtil.KEY_CODE, &"")), SeaLanes.ERR_SYS14_01)
		var detail: Dictionary = err.get(ErrorInfoUtil.KEY_DETAIL, {})
		var msg := String(detail.get(ErrorInfoUtil.DETAIL_MESSAGE, ""))
		var value := str(detail.get(ErrorInfoUtil.DETAIL_VALUE, ""))
		if value.find("LN-99") >= 0 or msg.find("endpoint") >= 0 and value.find("LN-99") >= 0:
			unknown_listed = true
		if value.find("LN-99") >= 0 and msg.find("missing") >= 0:
			unknown_listed = true
		if value == "LN-99" or (msg.find("endpoint") >= 0 and msg.find("LN-99") >= 0):
			unknown_listed = true
		if String(detail.get(ErrorInfoUtil.DETAIL_FIELD, "")) == "waypoints" and str(detail.get(ErrorInfoUtil.DETAIL_VALUE, "")) == "0":
			wp_zero_listed = true
		if value == "LN-98" or (msg.find("waypoints") >= 0 and value.find("0") >= 0):
			wp_zero_listed = true
	# Stronger: scan by lane id in value/message.
	for err_variant in errors:
		var err: Dictionary = err_variant
		var detail: Dictionary = err.get(ErrorInfoUtil.KEY_DETAIL, {})
		var blob := "%s %s" % [
			str(detail.get(ErrorInfoUtil.DETAIL_VALUE, "")),
			str(detail.get(ErrorInfoUtil.DETAIL_MESSAGE, "")),
		]
		if blob.find("LN-99") >= 0 or blob.find("JN-99") >= 0:
			unknown_listed = true
		if blob.find("LN-98") >= 0 or (blob.find("waypoints") >= 0 and blob.find("0") >= 0):
			wp_zero_listed = true
	assert_true(unknown_listed, "unknown-node lane must be listed: %s" % str(errors))
	assert_true(wp_zero_listed, "waypoints=0 lane must be listed: %s" % str(errors))
	assert_push_error_count(errors.size())


func test_TST_SYS14_03_fuzhou_to_naha_path() -> void:
	_boot_full_chart()
	var p: Array = SeaLanes.path(PT_FUZHOU, PT_NAHA)
	var lane_ids: PackedStringArray = PackedStringArray()
	var total_wp := 0
	for hop_variant in p:
		var hop: Dictionary = hop_variant
		var lid: String = String(hop["lane_id"])
		lane_ids.append(lid)
		total_wp += SeaLanes.waypoints(lid)
	assert_eq(lane_ids, PackedStringArray(["LN-01", "LN-30", "LN-32", "LN-34", "LN-22"]))
	assert_eq(total_wp, 16)
	assert_eq(String(p[0]["from_node"]), PT_FUZHOU)


func test_TST_SYS14_04_yuegang_to_dayuan_avoids_penghu_port() -> void:
	_boot_full_chart()
	var p: Array = SeaLanes.path(PT_YUE, PT_DAYUAN)
	var lane_ids: PackedStringArray = PackedStringArray()
	var total_wp := 0
	var visited_ports: Dictionary = {}
	for hop_variant in p:
		var hop: Dictionary = hop_variant
		var lid: String = String(hop["lane_id"])
		var from_n: String = String(hop["from_node"])
		lane_ids.append(lid)
		total_wp += SeaLanes.waypoints(lid)
		var lane: SeaLane = SeaLanes._lanes[lid]
		var other: String = lane.node_b if from_n == lane.node_a else lane.node_a
		for nid in [from_n, other]:
			var node: SeaNode = SeaLanes._nodes[nid]
			if node.kind == SeaNode.KIND_PORT:
				visited_ports[nid] = true
	assert_eq(lane_ids, PackedStringArray(["LN-04", "LN-28", "LN-25"]))
	assert_eq(total_wp, 7)
	assert_false(visited_ports.has("PT-06"), "must not transit 澎湖 port")
	assert_eq(visited_ports.size(), 2)


func test_TST_SYS14_09_path_deterministic_twice() -> void:
	_boot_full_chart()
	var a: Array = SeaLanes.path(PT_FUZHOU, PT_NAHA)
	var b: Array = SeaLanes.path(PT_FUZHOU, PT_NAHA)
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		assert_eq(String(a[i]["lane_id"]), String(b[i]["lane_id"]))
		assert_eq(String(a[i]["from_node"]), String(b[i]["from_node"]))


func test_WP29_13_06_1_csv_headers_missing_extra_type_abort() -> void:
	var missing: Dictionary = CsvImport.import_csv(
		"res://tests/fixtures/wp29_csv_bad_missing/nodes.csv",
		CsvImport.KIND_SEA_NODE
	)
	assert_false(missing["ok"])
	assert_gt((missing["errors"] as PackedStringArray).size(), 0)

	var extra: Dictionary = CsvImport.import_csv(
		"res://tests/fixtures/wp29_csv_bad_extra/nodes.csv",
		CsvImport.KIND_SEA_NODE
	)
	assert_false(extra["ok"])

	var typed: Dictionary = CsvImport.import_csv(
		"res://tests/fixtures/wp29_csv_bad_type/nodes.csv",
		CsvImport.KIND_SEA_NODE
	)
	assert_false(typed["ok"])

	var push_total: int = (
		(missing["errors"] as PackedStringArray).size()
		+ (extra["errors"] as PackedStringArray).size()
		+ (typed["errors"] as PackedStringArray).size()
	)
	assert_push_error_count(push_total)

	var regions_ok_header: Dictionary = CsvImport.import_csv(
		SEA_OK_CSV + "regions.csv",
		CsvImport.KIND_SEA_REGION,
		false
	)
	assert_true(regions_ok_header["ok"])
	var lanes_ok_header: Dictionary = CsvImport.import_csv(
		SEA_OK_CSV + "lanes.csv",
		CsvImport.KIND_SEA_LANE,
		false
	)
	assert_true(lanes_ok_header["ok"])
	assert_eq(CsvImport.expected_headers(CsvImport.KIND_SEA_NODE), PackedStringArray([
		"node_id", "kind", "name_zh", "x", "y"
	]))
	assert_eq(CsvImport.expected_headers(CsvImport.KIND_SEA_REGION), PackedStringArray([
		"region_id", "name_zh", "note"
	]))
	assert_eq(CsvImport.expected_headers(CsvImport.KIND_SEA_LANE), PackedStringArray([
		"lane_id", "node_a", "node_b", "region_id", "length", "waypoints", "lane_type"
	]))


func test_WP29_13_06_2_port_registry_mismatch_err_sys14_01() -> void:
	# Only 14 ports in PortRegistry; sea chart still has 16 PORT nodes.
	_setup_ports_goods(14)
	var sea := _install_sea_ok()
	var errors: Array = SeaLanes.load_and_validate(sea["nodes"], sea["regions"], sea["lanes"])
	assert_gt(errors.size(), 0)
	assert_false(SeaLanes.is_loaded())
	assert_true(_has_code(errors, SeaLanes.ERR_SYS14_01))
	assert_push_error_count(errors.size())


func test_WP29_13_06_3_tie_break_fewer_hops() -> void:
	## Same waypoints, fewer lanes wins.
	_setup_ports_goods(16)
	var dirs := _write_tiny_sea_tie_hops()
	var errors: Array = SeaLanes.load_and_validate(dirs["nodes"], dirs["regions"], dirs["lanes"])
	assert_eq(errors.size(), 0, str(errors))
	var p: Array = SeaLanes.path("PT-01", "PT-02")
	assert_eq(p.size(), 1)
	assert_eq(String(p[0]["lane_id"]), "LN-B")


func test_WP29_13_06_4_tie_break_lane_id_lexicographic() -> void:
	## Same waypoints and hop count → smaller lane_id sequence wins.
	_setup_ports_goods(16)
	var dirs := _write_tiny_sea_tie_lex()
	var errors: Array = SeaLanes.load_and_validate(dirs["nodes"], dirs["regions"], dirs["lanes"])
	assert_eq(errors.size(), 0, str(errors))
	var p: Array = SeaLanes.path("PT-01", "PT-02")
	assert_eq(p.size(), 2)
	assert_eq(String(p[0]["lane_id"]), "LN-A1")
	assert_eq(String(p[1]["lane_id"]), "LN-A2")


func test_WP29_13_06_5_ports_not_intermediate() -> void:
	_boot_full_chart()
	# Neighbor chain PT-01→PT-02→PT-06 would use intermediate port; must not appear.
	var p: Array = SeaLanes.path(PT_YUE, "PT-06")
	var intermediate_ports: Array = []
	for i in range(p.size()):
		var hop: Dictionary = p[i]
		var lid: String = String(hop["lane_id"])
		var from_n: String = String(hop["from_node"])
		var lane: SeaLane = SeaLanes._lanes[lid]
		var other: String = lane.node_b if from_n == lane.node_a else lane.node_a
		# from_node of hops after the first, and arrival nodes before last, must not be foreign ports.
		if i > 0:
			var node: SeaNode = SeaLanes._nodes[from_n]
			if node.kind == SeaNode.KIND_PORT and from_n != PT_YUE and from_n != "PT-06":
				intermediate_ports.append(from_n)
		if i < p.size() - 1:
			var arr: SeaNode = SeaLanes._nodes[other]
			if arr.kind == SeaNode.KIND_PORT and other != PT_YUE and other != "PT-06":
				intermediate_ports.append(other)
	assert_eq(intermediate_ports.size(), 0, "intermediate ports: %s path=%s" % [str(intermediate_ports), str(p)])


func test_WP29_13_05_same_origin_dest_err_sys14_04() -> void:
	_boot_full_chart()
	var p: Array = SeaLanes.path(PT_FUZHOU, PT_FUZHOU)
	assert_eq(p.size(), 0)
	assert_eq(StringName(SeaLanes.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), SeaLanes.ERR_SYS14_04)
	assert_push_error_count(1)


func test_WP29_13_05_no_path_err_sys14_03() -> void:
	_boot_full_chart()
	var none: Array = SeaLanes.path(PT_FUZHOU, "PT-99")
	assert_eq(none.size(), 0)
	assert_eq(StringName(SeaLanes.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), SeaLanes.ERR_SYS14_03)
	assert_push_error_count(1)


# --- helpers ---


func _boot_full_chart() -> void:
	_setup_ports_goods(16)
	var sea := _install_sea_ok()
	var errors: Array = SeaLanes.load_and_validate(sea["nodes"], sea["regions"], sea["lanes"])
	assert_eq(errors.size(), 0, "sea load: %s" % str(errors))
	assert_true(SeaLanes.is_loaded())


func _setup_ports_goods(port_count: int) -> void:
	var perr: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(perr.size(), 0)
	var goods_dir := _build_valid_goods(GOODS_ROOT)
	var gerr: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(gerr.size(), 0)
	var ports_dir := _build_valid_ports(port_count, PORTS_ROOT)
	var perr2: Array = PortRegistry.load_and_validate(ports_dir)
	assert_eq(perr2.size(), 0, "ports: %s" % str(perr2))


func _install_sea_ok() -> Dictionary:
	var nodes_dir: String = SEA_ROOT + "ok/nodes/"
	var regions_dir: String = SEA_ROOT + "ok/regions/"
	var lanes_dir: String = SEA_ROOT + "ok/lanes/"
	_wipe_dir(nodes_dir)
	_wipe_dir(regions_dir)
	_wipe_dir(lanes_dir)
	var result: Dictionary = CsvImport.run_batch_wp29(
		SEA_OK_CSV, nodes_dir, regions_dir, lanes_dir
	)
	assert_true(result["ok"], "import: %s" % str(result["errors"]))
	return {"nodes": nodes_dir, "regions": regions_dir, "lanes": lanes_dir}


func _write_tiny_sea_tie_hops() -> Dictionary:
	## PT-01 —LN-A(3)→ JN-01 —LN-C(3)→ PT-02  (6 wp, 2 hops)
	## PT-01 —LN-B(6)→ PT-02                 (6 wp, 1 hop) ← wins
	var root := SEA_ROOT + "tie_hops/"
	var nodes := root + "nodes/"
	var regions := root + "regions/"
	var lanes := root + "lanes/"
	_wipe_dir(nodes)
	_wipe_dir(regions)
	_wipe_dir(lanes)
	_write_all_ports_as_nodes(nodes)
	_write_region(regions, "RG-01")
	_write_junction(nodes, "JN-01", 0, 0)
	_write_lane(lanes, "LN-A", "PT-01", "JN-01", 3)
	_write_lane(lanes, "LN-C", "JN-01", "PT-02", 3)
	_write_lane(lanes, "LN-B", "PT-01", "PT-02", 6, SeaLane.TYPE_NEIGHBOR)
	# Fill remaining ports with junctions so 16 ports pairwise reachable:
	# star via JN-HUB
	# Expensive hub so it does not steal the PT-01→PT-02 tie under test.
	_write_junction(nodes, "JN-HUB", 1, 1)
	for i in range(1, 17):
		var pid := "PT-%02d" % i
		_write_lane(lanes, "LN-H%02d" % i, pid, "JN-HUB", 100)
	return {"nodes": nodes, "regions": regions, "lanes": lanes}


func _write_tiny_sea_tie_lex() -> Dictionary:
	## Two 2-hop paths, equal waypoints:
	## PT-01 —LN-A1(2)→ JN-A —LN-A2(2)→ PT-02
	## PT-01 —LN-B1(2)→ JN-B —LN-B2(2)→ PT-02
	## Lex: LN-A1,LN-A2 < LN-B1,LN-B2
	var root := SEA_ROOT + "tie_lex/"
	var nodes := root + "nodes/"
	var regions := root + "regions/"
	var lanes := root + "lanes/"
	_wipe_dir(nodes)
	_wipe_dir(regions)
	_wipe_dir(lanes)
	_write_all_ports_as_nodes(nodes)
	_write_region(regions, "RG-01")
	_write_junction(nodes, "JN-A", 0, 0)
	_write_junction(nodes, "JN-B", 1, 0)
	_write_lane(lanes, "LN-A1", "PT-01", "JN-A", 2)
	_write_lane(lanes, "LN-A2", "JN-A", "PT-02", 2)
	_write_lane(lanes, "LN-B1", "PT-01", "JN-B", 2)
	_write_lane(lanes, "LN-B2", "JN-B", "PT-02", 2)
	_write_junction(nodes, "JN-HUB", 2, 2)
	for i in range(1, 17):
		var pid := "PT-%02d" % i
		_write_lane(lanes, "LN-X%02d" % i, pid, "JN-HUB", 100)
	return {"nodes": nodes, "regions": regions, "lanes": lanes}


func _write_all_ports_as_nodes(nodes_dir: String) -> void:
	var names := {
		1: "月港", 2: "安海", 3: "福州", 4: "寧波", 5: "松江", 6: "澎湖",
		7: "大員", 8: "雞籠", 9: "淡水", 10: "魍港", 11: "那霸", 12: "長崎",
		13: "平戶", 14: "博多", 15: "鹿兒島", 16: "釜山倭館",
	}
	for i in range(1, 17):
		var node := SeaNode.new()
		node.node_id = "PT-%02d" % i
		node.kind = SeaNode.KIND_PORT
		node.name_zh = String(names[i])
		node.x = i
		node.y = i
		ResourceSaver.save(node, nodes_dir + "%s.tres" % node.node_id)


func _write_junction(nodes_dir: String, node_id: String, x: int, y: int) -> void:
	var node := SeaNode.new()
	node.node_id = node_id
	node.kind = SeaNode.KIND_JUNCTION
	node.name_zh = node_id
	node.x = x
	node.y = y
	ResourceSaver.save(node, nodes_dir + "%s.tres" % node_id)


func _write_region(regions_dir: String, region_id: String) -> void:
	var region := SeaRegion.new()
	region.region_id = region_id
	region.name_zh = region_id
	region.note = ""
	ResourceSaver.save(region, regions_dir + "%s.tres" % region_id)


func _write_lane(
	lanes_dir: String,
	lane_id: String,
	a: String,
	b: String,
	waypoints: int,
	lane_type: String = SeaLane.TYPE_SPUR
) -> void:
	var lane := SeaLane.new()
	lane.lane_id = lane_id
	lane.node_a = a
	lane.node_b = b
	lane.region_id = "RG-01"
	lane.length = float(waypoints)
	lane.waypoints = waypoints
	lane.lane_type = lane_type
	ResourceSaver.save(lane, lanes_dir + "%s.tres" % lane_id)


func _build_valid_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
		{"id": "GD-004", "name": STAPLE_FISH, "build": false},
	]
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], false),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (Params.get_int(PRM_FREE_PORT_TIER_MAX) + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(
			_make_good(gid, "填料%d" % next_n, tier, false, false, false),
			dir + "%s.tres" % gid
		)
		written += 1
		next_n += 1
	return dir


func _build_valid_ports(port_count: int, dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var free_count: int = _valid_free_count(port_count)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	for i in range(port_count):
		var n: int = i + 1
		var port_id := "PT-%02d" % n
		var def := PortDef.new()
		def.port_id = port_id
		def.name_zh = "港%d" % n
		def.is_free_port = i < free_count
		def.draft_limit_class = 0
		def.regime_id = "RG-TEST"
		def.role_cells = {}
		for good_variant in good_ids:
			var good_id: String = String(good_variant)
			var cell := RoleCell.new()
			if i == 0:
				cell.role = PortRegistry.ROLE_PRODUCER
				cell.base_output_per_season = 1
				cell.downstream_terminals = PackedStringArray()
			else:
				cell.role = PortRegistry.ROLE_TERMINAL
				cell.base_output_per_season = 0
				cell.downstream_terminals = PackedStringArray()
			def.role_cells[good_id] = cell
		ResourceSaver.save(def, dir + "%s.tres" % port_id)
	return dir


func _valid_free_count(port_count: int) -> int:
	var ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	if port_count <= 0:
		return 0
	var free_count: int = 0
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return free_count
		free_count += 1
	return 0


func _make_good(
	good_id: String,
	name_zh: String,
	tier: int,
	is_staple: bool,
	is_build_material: bool,
	is_strategic: bool
) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = good_id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = is_staple
	def.is_build_material = is_build_material
	def.is_strategic = is_strategic
	def.base_price_li = ANCHOR_LI
	def.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
	return def


func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if typeof(e) == TYPE_DICTIONARY and StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) == code:
			return true
	return false


func _wipe_dir(rel: String) -> void:
	var abs := ProjectSettings.globalize_path(rel)
	if DirAccess.dir_exists_absolute(abs):
		var dir := DirAccess.open(abs)
		if dir != null:
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
	DirAccess.make_dir_recursive_absolute(abs)
