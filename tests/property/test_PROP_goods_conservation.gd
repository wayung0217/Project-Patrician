extends GutTest
## WP-49 property：貨物守恆 FRM-SYS03-01（派工 17-41 D／D-59b）.
## 固定種子大量隨機 GENESIS／PRODUCE／CONSUME／LOAD／UNLOAD；每步後 check_conservation.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const GOODS_FIXTURE_ROOT := "user://prop_goods_conservation_goods/"
const PORTS_FIXTURE_ROOT := "user://prop_goods_conservation_ports/"

## 種子＝具名常數（C-08；禁用 randi／randf／randomize）.
const PROP_SEED_GOODS_CONSERVATION := 20261120
## 測試預算，非規格值.
const PROP_SEQ_LEN_GOODS := 200
const PROP_HOLD_CAP := 500
const PROP_MAX_QTY := 20

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"

const REASON_POOL: Array[StringName] = [
	GoodsLedger.REASON_GENESIS,
	GoodsLedger.REASON_PRODUCE,
	GoodsLedger.REASON_CONSUME,
	GoodsLedger.REASON_LOAD,
	GoodsLedger.REASON_UNLOAD,
]


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
	assert_eq(params_errors.size(), 0, "params fixture must load")
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	## D-32b 重置輔助：unload ShipRegistry 私有欄，使 HOLD transfer 不受靠泊閘門影響.
	ShipRegistry._loaded = false
	ShipRegistry._sailor_pool = null
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_valid_ports(Params.get_int("PRM-SYS02-PORT_COUNT_MIN"), PORTS_FIXTURE_ROOT + "base/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)


func test_PROP_FRM_SYS03_01_conservation_after_mixed_transfers() -> void:
	# FRM-SYS03-01／TST-SYS03-01 相關：混合 transfer 每步後 Σ 容器 = expected_net.
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-PROP-1", "ACTOR-PROP")
	var provider := TestCapacityProvider.new()
	provider.set_cap(hold, PROP_HOLD_CAP)
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider),
		GoodsLedger.CODE_OK
	)

	var stream := PropStream.new()
	var seed_state: int = Rng.derive_seed(
		PROP_SEED_GOODS_CONSERVATION, 0, "PT-01", String(good), "PROP_GOODS"
	)
	stream.reset(seed_state)

	for _i in PROP_SEQ_LEN_GOODS:
		var reason: StringName = REASON_POOL[stream.next_index(REASON_POOL.size())]
		var qty: int = stream.next_qty(PROP_MAX_QTY)
		_apply_reason_transfer(reason, market, hold, good, qty)
		assert_eq(
			GoodsLedger.check_conservation(),
			GoodsLedger.CODE_OK,
			"FRM-SYS03-01 conservation after step reason=%s qty=%s" % [String(reason), qty]
		)

	_consume_expected_push_errors()


func _consume_expected_push_errors() -> void:
	## Expected ERR-SYS03-* push_error from intentional failing transfers in the random mix.
	for e in get_errors():
		e.handled = true


func _apply_reason_transfer(
	reason: StringName, market: Dictionary, hold: Dictionary, good: StringName, qty: int
) -> void:
	match reason:
		GoodsLedger.REASON_GENESIS, GoodsLedger.REASON_PRODUCE:
			GoodsLedger.transfer(
				GoodsLedger.make_external(), market, good, qty, reason, &"TEST"
			)
		GoodsLedger.REASON_CONSUME:
			GoodsLedger.transfer(
				market, GoodsLedger.make_external(), good, qty, reason, &"TEST"
			)
		GoodsLedger.REASON_LOAD:
			GoodsLedger.transfer(market, hold, good, qty, reason, &"TEST")
		GoodsLedger.REASON_UNLOAD:
			GoodsLedger.transfer(hold, market, good, qty, reason, &"TEST")
		_:
			pass


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
