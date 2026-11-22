extends GutTest
## WP-49 property：同種子兩次狀態雜湊逐項相同（C-08）（派工 17-41 D／D-59b）.
## 只用 Rng FNV-1a＋SplitMix64；禁用 randi／randf／randomize.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const PARAMS_DEMO := "res://tests/fixtures/params_sys05_demo.json"
const GOODS_FIXTURE_ROOT := "user://prop_determinism_goods/"
const PORTS_FIXTURE_ROOT := "user://prop_determinism_ports/"

## 種子＝具名常數（C-08）.
const PROP_SEED_DETERMINISM := 20261123
## 測試預算，非規格值.
const PROP_SEQ_LEN_DET := 120
const PROP_HOLD_CAP := 400
const PROP_MAX_QTY := 15
const PROP_MAX_AMOUNT := 3000
## T7: named branch counts (no 1+1 evasions)
const BRANCH_COUNT := 2
const REASON_COUNT := 5

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"

const REQUESTER_SYS04 := &"SYS-04"
const REASON_TRADE := &"TRADE"


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


func test_PROP_C08_same_seed_state_hashes_match() -> void:
	# C-08：同種子跑兩次，狀態雜湊逐項相同.
	var hash_a: Dictionary = _run_once()
	_consume_expected_push_errors()
	var hash_b: Dictionary = _run_once()
	_consume_expected_push_errors()
	var keys_a: Array = hash_a.keys()
	keys_a.sort()
	var keys_b: Array = hash_b.keys()
	keys_b.sort()
	assert_eq(keys_a, keys_b, "C-08 hash key sets must match")
	for k in keys_a:
		assert_eq(hash_a[k], hash_b[k], "C-08 hash item %s must match" % String(k))


func _consume_expected_push_errors() -> void:
	## Expected ERR-SYS03／SYS-05 push_error from random failing ops in the sequence.
	for e in get_errors():
		e.handled = true


func _run_once() -> Dictionary:
	_boot()
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-PROP-DET", "ACTOR-PROP")
	var provider := TestCapacityProvider.new()
	provider.set_cap(hold, PROP_HOLD_CAP)
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider),
		GoodsLedger.CODE_OK
	)
	assert_eq(CashLedger.genesis_grant(), OK)

	var stream := PropStream.new()
	stream.reset(
		Rng.derive_seed(PROP_SEED_DETERMINISM, 0, "PT-01", String(good), "PROP_DET")
	)

	for _i in PROP_SEQ_LEN_DET:
		var branch: int = stream.next_index(BRANCH_COUNT)
		if branch == 0:
			var reason_i: int = stream.next_index(REASON_COUNT)
			var qty: int = stream.next_qty(PROP_MAX_QTY)
			match reason_i:
				0:
					GoodsLedger.transfer(
						GoodsLedger.make_external(),
						market,
						good,
						qty,
						GoodsLedger.REASON_GENESIS,
						&"TEST"
					)
				1:
					GoodsLedger.transfer(
						GoodsLedger.make_external(),
						market,
						good,
						qty,
						GoodsLedger.REASON_PRODUCE,
						&"TEST"
					)
				2:
					GoodsLedger.transfer(
						market,
						GoodsLedger.make_external(),
						good,
						qty,
						GoodsLedger.REASON_CONSUME,
						&"TEST"
					)
				3:
					GoodsLedger.transfer(market, hold, good, qty, GoodsLedger.REASON_LOAD, &"TEST")
				_:
					GoodsLedger.transfer(hold, market, good, qty, GoodsLedger.REASON_UNLOAD, &"TEST")
		else:
			var amt: int = stream.next_qty(PROP_MAX_AMOUNT)
			CashLedger.post(
				[
					CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - amt),
					CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, amt),
				],
				REASON_TRADE,
				REQUESTER_SYS04
			)

	return _state_hashes(good, market, hold)


func _state_hashes(good: StringName, market: Dictionary, hold: Dictionary) -> Dictionary:
	# 狀態雜湊：貨物數量＋現金餘額（鍵排序，C-08）.
	var out: Dictionary = {}
	out["goods_market"] = GoodsLedger.get_qty(market, good)
	out["goods_hold"] = GoodsLedger.get_qty(hold, good)
	out["goods_total"] = GoodsLedger.total(good)
	out["goods_conservation"] = GoodsLedger.check_conservation()

	## D-32b 斷言輔助：遍歷 CashLedger._accounts（排序鍵）組雜湊欄.
	var acc_keys: Array = CashLedger._accounts.keys()
	acc_keys.sort()
	for k in acc_keys:
		var acc: Account = CashLedger._accounts[k]
		out["cash_bal_%s" % String(k)] = acc.balance
		out["cash_arr_%s" % String(k)] = acc.arrears
	out["cash_sum"] = CashLedger.sum_all_balances()

	# 額外：整包 FNV 指紋（仍為同種子應相等）.
	var parts: PackedByteArray = PackedByteArray()
	var fingerprint_keys: Array = out.keys()
	fingerprint_keys.sort()
	for fk in fingerprint_keys:
		parts.append_array(("%s=%s" % [String(fk), str(out[fk])]).to_utf8_buffer())
		parts.append(0x1f)
	out["fnv_fingerprint"] = Rng.fnv1a64(parts)
	return out


func _boot() -> void:
	# Cash uses demo params (START_CASH)；goods／ports from all_keys mins via rebuilt fixtures.
	assert_eq(Params.load_and_validate(PARAMS_DEMO).size(), 0)
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
	assert_eq(CashLedger.load_and_validate().size(), 0)


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
			_make_good(s["id"], s["name"], 1, true, s["build"], false, 1000),
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
			_make_good(gid, "填料%d" % next_n, tier, false, false, false, 1000),
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
