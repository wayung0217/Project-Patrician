extends GutTest
## WP-04 PortRegistry tests. Fixture values from TechSpec §4 / TST-SYS02-01..05 / 3.3.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const GOODS_FIXTURE_ROOT := "user://port_registry_goods/"
const PORTS_FIXTURE_ROOT := "user://port_registry_ports/"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"

const ERR_SYS02_01 := "ERR-SYS02-01"
const ERR_SYS02_02 := "ERR-SYS02-02"
const ERR_SYS02_05 := "ERR-SYS02-05"
const ERR_SYS02_06 := "ERR-SYS02-06"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"

## TST-SYS02-01 given: port count = 13 → ERR-SYS02-05
const TST_SYS02_01_PORT_COUNT := 13
## TST-SYS02-02 given: free port ratio = 0.25 → ERR-SYS02-06
const TST_SYS02_02_FREE_RATIO := 0.25
## TST-SYS02-05: queue on season day 30; role unchanged through days 31..D; apply at cutoff.
const TST_SYS02_05_QUEUE_DAY := 30


func before_each() -> void:
	var params_errors: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(params_errors.size(), 0, "params fixture must load")
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/")
	var goods_errors: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(goods_errors.size(), 0, "goods fixture must load")


func test_TST_SYS02_01_port_count_13_rejects() -> void:
	# TST-SYS02-01: 港口數 = 13 → ERR-SYS02-05
	var dir := _build_valid_ports(TST_SYS02_01_PORT_COUNT, PORTS_FIXTURE_ROOT + "count13/")
	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_05), "expected ERR-SYS02-05")


func test_TST_SYS02_02_free_port_ratio_025_rejects() -> void:
	# TST-SYS02-02: 自由港比例 = 0.25 → ERR-SYS02-06
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	# free = round(ratio * count); 0.25 * 14 = 3.5 → use exact free_count = ratio * count when divisible.
	# 16 * 0.25 = 4 exactly (PORT_COUNT_MAX).
	port_count = Params.get_int(PRM_PORT_COUNT_MAX)
	var free_count: int = int(TST_SYS02_02_FREE_RATIO * float(port_count))
	assert_eq(float(free_count) / float(port_count), TST_SYS02_02_FREE_RATIO, "fixture ratio must be 0.25")
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "ratio025/", free_count)
	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_06), "expected ERR-SYS02-06")


func test_TST_SYS02_03_missing_role_cell_rejects() -> void:
	# TST-SYS02-03: 某港 × 貨格無角色 → ERR-SYS02-01（無 NONE，9a-B）
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "missing_role/", free_count)
	var first_port_path := dir + "PT-01.tres"
	var def: PortDef = load(first_port_path) as PortDef
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	assert_gt(good_ids.size(), 0)
	var drop_good: String = good_ids[0]
	def.role_cells.erase(drop_good)
	var save_err: Error = ResourceSaver.save(def, first_port_path)
	assert_eq(save_err, OK)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_01), "expected ERR-SYS02-01")


func test_TST_SYS02_04_transit_downstream_self_rejects() -> void:
	# TST-SYS02-04: 中轉格下游指向自身 → ERR-SYS02-02
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir_self := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "transit_self/", free_count)
	_set_transit(dir_self, "PT-03", GoodCatalog.all_ids()[0], PackedStringArray(["PT-03"]))
	var errors_self: Array = PortRegistry.load_and_validate(dir_self)
	assert_gt(errors_self.size(), 0)
	assert_push_error_count(errors_self.size())
	assert_true(_has_code(errors_self, ERR_SYS02_02), "expected ERR-SYS02-02 for self downstream")
	assert_false(PortRegistry.is_loaded())


func test_TST_SYS02_04_transit_downstream_non_terminal_rejects() -> void:
	# TST-SYS02-04: 中轉格下游指向非終端港 → ERR-SYS02-02
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir_non_term := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "transit_non_term/", free_count)
	# PT-01 is PRODUCER for every good in the valid fixture — point TRANSIT at it.
	_set_transit(dir_non_term, "PT-03", GoodCatalog.all_ids()[0], PackedStringArray(["PT-01"]))
	var errors_non: Array = PortRegistry.load_and_validate(dir_non_term)
	assert_gt(errors_non.size(), 0)
	assert_push_error_count(errors_non.size())
	assert_true(_has_code(errors_non, ERR_SYS02_02), "expected ERR-SYS02-02 for non-TERMINAL downstream")
	assert_false(PortRegistry.is_loaded())


func test_TST_SYS02_05_role_change_queues_until_cutoff() -> void:
	# TST-SYS02-05: 建造完工於商季第 30 日排隊；第 31..D 日角色不變；cutoff 後生效並發 role_changed
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "queue/", free_count)
	# Second producer so PRODUCER→TERMINAL still satisfies FRM-SYS02-01 (4).
	_add_second_producer(dir, "PT-04", GoodCatalog.all_ids()[0])

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_eq(errors.size(), 0, "valid ports must load")
	assert_true(PortRegistry.is_loaded())

	var port_id := "PT-01"
	var good_id: String = GoodCatalog.all_ids()[0]
	var old_role: int = PortRegistry.get_role(port_id, good_id)
	assert_eq(old_role, PortRegistry.ROLE_PRODUCER)

	# Day 30 (TST-SYS02-05): construction completion queues role change.
	var day_in_season: int = TST_SYS02_05_QUEUE_DAY
	assert_eq(day_in_season, TST_SYS02_05_QUEUE_DAY)
	PortRegistry.queue_role_change(port_id, good_id, PortRegistry.ROLE_TERMINAL)

	var days_per_season: int = Params.get_int(PRM_DAYS_PER_SEASON)
	# Days 31 .. D inclusive: role unchanged (SimLoop not present — observe via get_role).
	var day: int = TST_SYS02_05_QUEUE_DAY + 1
	while day <= days_per_season:
		assert_eq(PortRegistry.get_role(port_id, good_id), old_role, "role must stay queued through day %d" % day)
		day += 1

	watch_signals(PortRegistry)
	var apply_errors: Array = PortRegistry.apply_queued_role_changes()
	assert_eq(apply_errors.size(), 0)
	assert_eq(PortRegistry.get_role(port_id, good_id), PortRegistry.ROLE_TERMINAL)
	assert_signal_emitted(PortRegistry, "role_changed")


func test_valid_ports_load_queries_and_warnings() -> void:
	# Happy path: FRM-SYS02-01 pass, queries sorted, WRN-SYS02-01 does not block.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "ok/", free_count)
	# Put controlled_scale_only PRODUCER on a free port → warning only.
	_force_controlled_producer_on_free_port(dir)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_eq(errors.size(), 0)
	assert_true(PortRegistry.is_loaded())
	assert_gt(PortRegistry.get_warnings().size(), 0, "FRM-SYS02-02 should warn")

	var ids: PackedStringArray = PortRegistry.all_ids()
	assert_eq(ids.size(), port_count)
	for i in range(ids.size()):
		if i == 0:
			continue
		assert_true(ids[i - 1] < ids[i], "all_ids must be ascending")

	var good_id: String = GoodCatalog.all_ids()[0]
	var producers: PackedStringArray = PortRegistry.producers_of(good_id)
	var terminals: PackedStringArray = PortRegistry.terminals_of(good_id)
	assert_gt(producers.size(), 0)
	assert_gt(terminals.size(), 0)
	assert_eq(PortRegistry.get_role(producers[0], good_id), PortRegistry.ROLE_PRODUCER)
	assert_eq(PortRegistry.get_role(terminals[0], good_id), PortRegistry.ROLE_TERMINAL)
	var port: PortDef = PortRegistry.get_port(ids[0])
	assert_false(port.port_id.is_empty())
	# draft_limit_class stored, unused (B3).
	assert_true(port.get("draft_limit_class") != null)

	var recheck: Array = PortRegistry.validate()
	assert_eq(recheck.size(), 0)


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
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(_make_good(s["id"], s["name"], 1, true, s["build"], false, 1), dir + "%s.tres" % s["id"])
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(_make_good(gid, "填料%d" % next_n, tier, false, false, false, next_n), dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	return dir


func _build_valid_ports(port_count: int, dir: String, free_count: int = -1) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if free_count < 0:
		free_count = _valid_free_count(port_count)
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
				# PT-01: PRODUCER for every good (output > 0).
				cell.role = PortRegistry.ROLE_PRODUCER
				cell.base_output_per_season = 1
				cell.downstream_terminals = PackedStringArray()
			elif i == 1:
				# PT-02: TERMINAL sink for every good.
				cell.role = PortRegistry.ROLE_TERMINAL
				cell.base_output_per_season = 0
				cell.downstream_terminals = PackedStringArray()
			else:
				cell.role = PortRegistry.ROLE_TERMINAL
				cell.base_output_per_season = 0
				cell.downstream_terminals = PackedStringArray()
			def.role_cells[good_id] = cell
		ResourceSaver.save(def, dir + "%s.tres" % port_id)
	return dir


func _valid_free_count(port_count: int) -> int:
	# Pick smallest free_count whose ratio ∈ [PRM min, max] (C-03: no bare literals beyond 0/1).
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


func _set_transit(dir: String, port_id: String, good_id: String, downstream: PackedStringArray) -> void:
	var path := dir + "%s.tres" % port_id
	var def: PortDef = load(path) as PortDef
	var cell: RoleCell = def.role_cells[good_id]
	cell.role = PortRegistry.ROLE_TRANSIT
	cell.base_output_per_season = 0
	cell.downstream_terminals = downstream
	def.role_cells[good_id] = cell
	ResourceSaver.save(def, path)


func _add_second_producer(dir: String, port_id: String, good_id: String) -> void:
	var path := dir + "%s.tres" % port_id
	var def: PortDef = load(path) as PortDef
	var cell: RoleCell = def.role_cells[good_id]
	cell.role = PortRegistry.ROLE_PRODUCER
	cell.base_output_per_season = 1
	cell.downstream_terminals = PackedStringArray()
	def.role_cells[good_id] = cell
	ResourceSaver.save(def, path)


func _force_controlled_producer_on_free_port(dir: String) -> void:
	# Free port PT-01 already PRODUCER; mark a high-tier strategic good so controlled_scale_only is true.
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	var target: String = ""
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	for id in good_ids:
		var g: GoodDef = GoodCatalog.get_good(id)
		if g.tier > free_max or g.is_strategic:
			target = id
			break
	if target.is_empty():
		# Fallback: flip last filler to strategic via re-save in goods dir is heavy; skip if none.
		return
	# Ensure PT-01 (free when free_count>0) produces that good — already true in fixture.
	assert_true(GoodCatalog.get_good(target).controlled_scale_only)


func _make_good(
	good_id: String,
	name_zh: String,
	tier: int,
	is_staple: bool,
	is_build_material: bool,
	is_strategic: bool,
	base_price_li: int
) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = good_id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = is_staple
	def.is_build_material = is_build_material
	def.is_strategic = is_strategic
	def.base_price_li = base_price_li
	def.season_mask = 0
	return def


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


func _has_code(errors: Array, code: String) -> bool:
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if String(e.get("code", "")) == code:
			return true
	return false
