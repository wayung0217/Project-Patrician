extends GutTest
## WP-49 property：MarketPricer 報價在曲線硬上下限內、quote 總額對數量不為負（SYS-04）（派工 17-41 D／D-59b）.
## 硬上下限＝價格曲線 ceiling（M1）與 floor（Mn）（10d-B 表即上下限）.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const GOODS_FIXTURE_ROOT := "user://prop_market_bounds_goods/"
const PORTS_FIXTURE_ROOT := "user://prop_market_bounds_ports/"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"

## 種子＝具名常數（C-08）.
const PROP_SEED_MARKET := 20261124
## 測試預算，非規格值.
const PROP_SEQ_LEN_MARKET := 200
const PROP_MAX_STOCK := 500
const PROP_MAX_OFFTAKE := 200
const PROP_MAX_QTY := 80
const PROP_WEEKS_PAST_FLOOR := 1000.0
## T7: named side-branch count (no 1+1 evasion)
const SIDE_BRANCHES := 2

const PORT_DEMO := "PT-01"
const GOOD_DEMO := "GD-001"
const ANCHOR_LI := 1000

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"


func before_each() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	## D-32b 重置輔助.
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
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)


func test_PROP_SYS04_quote_within_curve_hard_bounds_and_non_negative() -> void:
	# SYS-04／FRM-SYS04-02／05：mid_after ∈ [anchor×Mn, anchor×M1]；成功 quote 的 total_li ≥ 0.
	var ceiling_m: float = MarketPricer.multiplier_at_weeks(0.0)
	var floor_m: float = MarketPricer.multiplier_at_weeks(PROP_WEEKS_PAST_FLOOR)
	assert_gt(ceiling_m, floor_m, "curve ceiling must exceed floor")

	var stream := PropStream.new()
	stream.reset(Rng.derive_seed(PROP_SEED_MARKET, 0, PORT_DEMO, GOOD_DEMO, "PROP_MKT"))

	var ok_quotes: int = 0
	for _i in PROP_SEQ_LEN_MARKET:
		var stock: int = stream.next_index(PROP_MAX_STOCK + 1)
		var offtake: int = stream.next_index(PROP_MAX_OFFTAKE + 1)
		_reset_market_stock(stock)
		_inject_offtake_weekly(PORT_DEMO, GOOD_DEMO, offtake if offtake > 0 else 0)

		var side: int = (
			MarketPricer.SIDE_BUY if stream.next_index(SIDE_BRANCHES) == 0 else MarketPricer.SIDE_SELL
		)
		var qty: int = stream.next_qty(PROP_MAX_QTY)
		var q: Dictionary = MarketPricer.quote(
			StringName(PORT_DEMO), StringName(GOOD_DEMO), side, qty
		)
		if q.has(MarketPricer.KEY_ERROR):
			continue
		ok_quotes += 1
		var total_li: int = int(q[MarketPricer.KEY_TOTAL_LI])
		assert_gte(total_li, 0, "SYS-04 quote total_li must be non-negative for qty>0")
		var mid_after: float = float(q[MarketPricer.KEY_MID_AFTER])
		var floor_mid: float = float(ANCHOR_LI) * floor_m
		var ceiling_mid: float = float(ANCHOR_LI) * ceiling_m
		assert_true(
			mid_after >= floor_mid,
			"SYS-04 mid_after %s below curve floor %s" % [mid_after, floor_mid]
		)
		assert_true(
			mid_after <= ceiling_mid,
			"SYS-04 mid_after %s above curve ceiling %s" % [mid_after, ceiling_mid]
		)

	assert_gt(ok_quotes, 0, "budget must produce successful quotes")
	_consume_expected_push_errors()


func _consume_expected_push_errors() -> void:
	## Expected ERR-SYS04-06 push_error when buy qty > stock (skipped for bound asserts).
	for e in get_errors():
		e.handled = true


func _reset_market_stock(stock: int) -> void:
	## D-32b 重置輔助：直接寫 GoodsLedger._stock 以設定市集庫存（不經 transfer，僅 fixture）.
	var key: String = String(
		GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), PORT_DEMO)
	)
	if not GoodsLedger._stock.has(key):
		GoodsLedger._stock[key] = {}
		GoodsLedger._kind_by_id[key] = GoodsLedger.KIND_MARKET
	var bucket: Dictionary = GoodsLedger._stock[key]
	bucket[GOOD_DEMO] = stock
	GoodsLedger._stock[key] = bucket
	## Keep expected_net aligned so other systems stay consistent if checked.
	GoodsLedger._expected_net[GOOD_DEMO] = GoodsLedger.total(StringName(GOOD_DEMO))


func _inject_offtake_weekly(port_id: String, good_id: String, weekly_offtake: int) -> void:
	## D-32b／F11: public seed_offtake_snapshot（不再寫 _offtake_snapshot）.
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var window_days: int = days_pw if days_pw > 0 else 1
	GoodsLedger.seed_offtake_snapshot(
		StringName(port_id), StringName(good_id), weekly_offtake, weekly_offtake, window_days, 0
	)


func _build_valid_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int("PRM-SYS01-GOOD_COUNT_MIN")
	var staples: Array = [
		{"id": GOOD_DEMO, "name": STAPLE_RICE, "build": false},
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
			_make_good(s["id"], s["name"], 1, true, s["build"], false, ANCHOR_LI),
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
			_make_good(gid, "填料%d" % next_n, tier, false, false, false, ANCHOR_LI),
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
