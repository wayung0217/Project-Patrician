extends GutTest
## WP-49 property：transfer 全有或全無 FRM-SYS03-02（派工 17-41 D／D-59b）.
## 失敗時雙方數量不變.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const GOODS_FIXTURE_ROOT := "user://prop_transfer_aon_goods/"
const PORTS_FIXTURE_ROOT := "user://prop_transfer_aon_ports/"

## 種子＝具名常數（C-08）.
const PROP_SEED_TRANSFER_AON := 20261121
## 測試預算，非規格值.
const PROP_SEQ_LEN_TRANSFER := 200
const PROP_HOLD_CAP := 30
const PROP_MAX_QTY := 40
const PROP_SEED_STOCK := 15

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"


class TestCapacityProvider extends CapacityProvider:
	var _caps: Dictionary = {}

	func set_cap(container: Dictionary, cap: int) -> void:
		_caps[_key(container)] = cap

	func capacity(container: Variant) -> int:
		var k: String = _key(container)
		if not _caps.has(k):
			return CAPACITY_FAILURE
		return int(_caps[k])

	func _key(container: Variant) -> String:
		if typeof(container) != TYPE_DICTIONARY:
			return ""
		var d: Dictionary = container
		var kind: String = String(d.get("kind", ""))
		match kind:
			"HOLD":
				return "HOLD|%s" % String(d.get("ship", ""))
			"WAREHOUSE":
				return "WAREHOUSE|%s|%s" % [String(d.get("owner", "")), String(d.get("port", ""))]
			_:
				return kind


func before_each() -> void:
	var params_errors: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(params_errors.size(), 0)
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	## D-32b 重置輔助：ShipRegistry 私有欄.
	ShipRegistry._loaded = false
	ShipRegistry._sailor_pool = null
	assert_eq(GoodCatalog.load_and_validate(_build_valid_goods(GOODS_FIXTURE_ROOT + "base/")).size(), 0)
	assert_eq(
		PortRegistry.load_and_validate(
			_build_valid_ports(Params.get_int("PRM-SYS02-PORT_COUNT_MIN"), PORTS_FIXTURE_ROOT + "base/")
		).size(),
		0
	)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)


func test_PROP_FRM_SYS03_02_failed_transfer_leaves_both_sides_unchanged() -> void:
	# FRM-SYS03-02／TST-SYS03-02／03：失敗 → 雙方數量不變（全有或全無）.
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-PROP-AON", "ACTOR-PROP")
	var provider := TestCapacityProvider.new()
	provider.set_cap(hold, PROP_HOLD_CAP)
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider),
		GoodsLedger.CODE_OK
	)

	# Seed market stock so some transfers succeed and some fail.
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			market,
			good,
			PROP_SEED_STOCK,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)

	var stream := PropStream.new()
	stream.reset(
		Rng.derive_seed(PROP_SEED_TRANSFER_AON, 0, "PT-01", String(good), "PROP_AON")
	)

	var fail_count: int = 0
	for _i in PROP_SEQ_LEN_TRANSFER:
		var qty: int = stream.next_qty(PROP_MAX_QTY)
		var op: int = stream.next_index(1 + 1) ## 0=LOAD market→hold；1=UNLOAD hold→market
		var from_c: Dictionary = market if op == 0 else hold
		var to_c: Dictionary = hold if op == 0 else market
		var reason: StringName = (
			GoodsLedger.REASON_LOAD if op == 0 else GoodsLedger.REASON_UNLOAD
		)
		var from_before: int = GoodsLedger.get_qty(from_c, good)
		var to_before: int = GoodsLedger.get_qty(to_c, good)
		var seq: int = GoodsLedger.transfer(from_c, to_c, good, qty, reason, &"TEST")
		if seq == 0:
			fail_count += 1
			assert_eq(
				GoodsLedger.get_qty(from_c, good),
				from_before,
				"FRM-SYS03-02 from unchanged on fail"
			)
			assert_eq(
				GoodsLedger.get_qty(to_c, good),
				to_before,
				"FRM-SYS03-02 to unchanged on fail"
			)
		else:
			assert_eq(GoodsLedger.get_qty(from_c, good), from_before - qty)
			assert_eq(GoodsLedger.get_qty(to_c, good), to_before + qty)

	assert_gt(fail_count, 0, "budget must include failed transfers to exercise FRM-SYS03-02")
	_consume_expected_push_errors()


func _consume_expected_push_errors() -> void:
	## Expected ERR-SYS03-02／03 push_error from failing transfers under test.
	for e in get_errors():
		e.handled = true


func _build_valid_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int("PRM-SYS01-GOOD_COUNT_MIN")
	var staples: Array = [
		{"id": "GD-001", "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
		{"id": "GD-004", "name": STAPLE_FISH, "build": false},
	]
	var free_max: int = Params.get_int("PRM-SYS01-FREE_PORT_TIER_MAX")
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], false, 1),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int("PRM-SYS01-TIER_MAX"):
			tier = Params.get_int("PRM-SYS01-TIER_MAX")
		ResourceSaver.save(
			_make_good(gid, "填料%d" % next_n, tier, false, false, false, next_n),
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
	var ratio_min: float = Params.get_float("PRM-SYS02-FREE_PORT_RATIO_MIN")
	var ratio_max: float = Params.get_float("PRM-SYS02-FREE_PORT_RATIO_MAX")
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
	def.season_mask = (1 << Params.get_int("PRM-SYS00-SEASONS_PER_YEAR")) - 1
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
