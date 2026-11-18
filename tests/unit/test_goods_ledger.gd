extends GutTest
## WP-05 GoodsLedger tests. Fixture values from TechSpec §4 / TST-SYS03-01..06 / 3.4.
## D-04: transfer fail→0 + ErrorInfo last_error(); no ERR→int (−1..−5 withdrawn).
## D-08d／e／f: container_id; register_capacity_provider; signal params.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const GOODS_FIXTURE_ROOT := "user://goods_ledger_goods/"
const PORTS_FIXTURE_ROOT := "user://goods_ledger_ports/"

const SYS_ID := &"SYS-03"

const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"

## TST-SYS03-02 given: hold has 5；transfer 6 → ERR-SYS03-02
const TST_SYS03_02_HOLD_QTY := 5
const TST_SYS03_02_TRANSFER_QTY := 6
## TST-SYS03-03 given: remaining capacity 3；transfer 4 → ERR-SYS03-03
const TST_SYS03_03_REMAINING_CAP := 3
const TST_SYS03_03_TRANSFER_QTY := 4
## TST-SYS03-04 given: Q=1000, D=DAYS_PER_SEASON → Σ PRODUCE = 1000
const TST_SYS03_04_Q := 1000
## TST-SYS03-04／3.1: single-day produce difference ≤ 1
const TST_SYS03_04_MAX_DAY_DELTA := 1
## TST-SYS03-06: 10 seasons of produce, MARKET grows unboundedly
const TST_SYS03_06_SEASONS := 10
## D-05(d): CONSUME shortage fixture
const TST_CONSUME_HAVE := 2
const TST_CONSUME_WANT := 3


class TestCapacityProvider extends CapacityProvider:
	## Test double for WAREHOUSE／HOLD capacity (SYS-08／13 out of scope).
	var _caps: Dictionary = {} ## container_key -> int

	func set_cap(container: Dictionary, cap: int) -> void:
		_caps[_key(container)] = cap

	func capacity(container: Variant) -> int:
		var k: String = _key(container)
		if not _caps.has(k):
			push_error("TestCapacityProvider: no cap for %s" % k)
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
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/")
	var goods_errors: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(goods_errors.size(), 0, "goods fixture must load")
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var ports_dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "base/")
	var port_errors: Array = PortRegistry.load_and_validate(ports_dir)
	assert_eq(port_errors.size(), 0, "ports fixture must load")
	var gl_errors: Array = GoodsLedger.load_and_validate()
	assert_eq(gl_errors.size(), 0, "GoodsLedger must load")


func test_next_seq_starts_at_1_and_increments() -> void:
	# D101 / WP-05 acceptance: next_seq() 從 1 起每次 +1
	assert_eq(GoodsLedger.next_seq(), 1)
	assert_eq(GoodsLedger.next_seq(), 2)
	assert_eq(GoodsLedger.next_seq(), 3)


func test_capacity_provider_base_push_error() -> void:
	# 2.1-03: 基底方法一律 push_error 並回失敗值
	var base := CapacityProvider.new()
	var cap: int = base.capacity(GoodsLedger.make_hold("SHIP-1"))
	assert_eq(cap, CapacityProvider.CAPACITY_FAILURE)
	assert_push_error_count(1)


func test_TST_SYS03_01_conservation_violated_on_manual_mutate() -> void:
	# TST-SYS03-01: debug 模式、人為改動某容器數量而不經 transfer → conservation_violated
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, 1, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	assert_gt(seq, 0)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)
	assert_true(GoodsLedger.last_error().is_empty(), "success clears last_error")

	watch_signals(GoodsLedger)
	# 人為改動：繞過 transfer 直接改 _stock（紅隊-03／TST-SYS03-01 Given）
	var key: String = String(GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), "PT-01"))
	var bucket: Dictionary = GoodsLedger._stock[key]
	bucket[String(good)] = int(bucket[String(good)]) + 1
	GoodsLedger._stock[key] = bucket

	var result: int = GoodsLedger.check_conservation()
	assert_eq(result, GoodsLedger.CODE_FAIL)
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_05), "conservation → ERR-SYS03-05 in last_error")
	assert_push_error_count(1)
	assert_signal_emitted(GoodsLedger, "conservation_violated")


func test_TST_SYS03_02_insufficient_balance_unchanged() -> void:
	# TST-SYS03-02: 船艙餘 5 擔，transfer 卸 6 擔 → ERR-SYS03-02，雙方數量不變
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-A")
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var provider := TestCapacityProvider.new()
	# Cap large enough to accept the GENESIS load into HOLD.
	provider.set_cap(hold, TST_SYS03_02_HOLD_QTY + TST_SYS03_02_HOLD_QTY)
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider),
		GoodsLedger.CODE_OK
	)

	var load_seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(), hold, good, TST_SYS03_02_HOLD_QTY, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	assert_gt(load_seq, 0)
	assert_eq(GoodsLedger.get_qty(hold, good), TST_SYS03_02_HOLD_QTY)
	assert_eq(GoodsLedger.get_qty(market, good), 0)

	var err: int = GoodsLedger.transfer(
		hold, market, good, TST_SYS03_02_TRANSFER_QTY, GoodsLedger.REASON_UNLOAD, &"TEST"
	)
	assert_eq(err, 0, "D-04: transfer fail → 0")
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_02), "expected ERR-SYS03-02 in last_error")
	assert_push_error_count(1)
	assert_eq(GoodsLedger.get_qty(hold, good), TST_SYS03_02_HOLD_QTY)
	assert_eq(GoodsLedger.get_qty(market, good), 0)


func test_TST_SYS03_03_insufficient_capacity_all_or_nothing() -> void:
	# TST-SYS03-03: 目的容器剩餘容量 3，transfer 4 → ERR-SYS03-03，全無
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-B")
	var provider := TestCapacityProvider.new()
	provider.set_cap(hold, TST_SYS03_03_REMAINING_CAP)
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider),
		GoodsLedger.CODE_OK
	)

	var src_seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, TST_SYS03_03_TRANSFER_QTY, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	assert_gt(src_seq, 0)
	assert_eq(GoodsLedger.get_qty(market, good), TST_SYS03_03_TRANSFER_QTY)
	assert_eq(GoodsLedger.get_qty(hold, good), 0)

	var err: int = GoodsLedger.transfer(
		market, hold, good, TST_SYS03_03_TRANSFER_QTY, GoodsLedger.REASON_LOAD, &"TEST"
	)
	assert_eq(err, 0, "D-04: transfer fail → 0")
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_03), "expected ERR-SYS03-03 in last_error")
	assert_push_error_count(1)
	assert_eq(GoodsLedger.get_qty(market, good), TST_SYS03_03_TRANSFER_QTY)
	assert_eq(GoodsLedger.get_qty(hold, good), 0)


func test_TST_SYS03_03_no_provider_is_capacity_error() -> void:
	# TechSpec 3.4 D: 無 CapacityProvider → ERR-SYS03-03，不得視為無限
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-C")
	GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, 1, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	var err: int = GoodsLedger.transfer(market, hold, good, 1, GoodsLedger.REASON_LOAD, &"TEST")
	assert_eq(err, 0, "D-04: transfer fail → 0")
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_03), "expected ERR-SYS03-03 in last_error")
	assert_push_error_count(1)


func test_D05_consume_shortage_err_sys03_02_all_or_nothing() -> void:
	# D-05(d): CONSUME 庫存不足 = ERR-SYS03-02、全有或全無、收進 last_error（不得只 push_error／clamp）
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, TST_CONSUME_HAVE, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	assert_gt(seq, 0)
	assert_eq(GoodsLedger.get_qty(market, good), TST_CONSUME_HAVE)

	var err: int = GoodsLedger.transfer(
		market,
		GoodsLedger.make_external(),
		good,
		TST_CONSUME_WANT,
		GoodsLedger.REASON_CONSUME,
		&"SYS-06"
	)
	assert_eq(err, 0, "D-04: CONSUME shortage → transfer fail 0")
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_02), "D-05(d): CONSUME shortage → ERR-SYS03-02")
	assert_push_error_count(1)
	assert_eq(GoodsLedger.get_qty(market, good), TST_CONSUME_HAVE, "all-or-nothing: qty unchanged")
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_TST_SYS03_04_season_produce_sums_to_q() -> void:
	# TST-SYS03-04: Q=1000、D=DAYS_PER_SEASON，跑完一商季 → Σ PRODUCE = 1000；單日差 ≤ 1
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var sum: int = 0
	var prev: int = 0
	for k in range(days_d):
		var out_k: int = GoodsLedger.daily_produce_qty(TST_SYS03_04_Q, k)
		sum += out_k
		if k > 0:
			var delta: int = absi(out_k - prev)
			assert_lte(delta, TST_SYS03_04_MAX_DAY_DELTA, "single-day produce delta ≤ 1 (3.1／TST-SYS03-04)")
		prev = out_k
	assert_eq(sum, TST_SYS03_04_Q, "Σ out(k) must equal Q exactly (FRM-SYS03-03)")

	# Also apply PRODUCE via run_daily_produce for one producer cell with Q=1000.
	_set_producer_output("PT-01", GoodCatalog.all_ids()[0], TST_SYS03_04_Q)
	# Reload PortRegistry so GoodsLedger sees updated Q — role_cells already mutated in memory.
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var before: int = GoodsLedger.get_qty(market, good)
	for k in range(days_d):
		GoodsLedger.run_daily_produce(k)
	var after: int = GoodsLedger.get_qty(market, good)
	assert_eq(after - before, TST_SYS03_04_Q)


func test_TST_SYS03_05_sea_loss_rejected() -> void:
	# TST-SYS03-05: reason = SEA_LOSS → ERR-SYS03-04
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, 1, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	var before: int = GoodsLedger.get_qty(market, good)
	var err: int = GoodsLedger.transfer(
		market, GoodsLedger.make_external(), good, 1, GoodsLedger.REASON_SEA_LOSS, &"TEST"
	)
	assert_eq(err, 0, "D-04: transfer fail → 0")
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_04), "expected ERR-SYS03-04 in last_error")
	assert_push_error_count(1)
	assert_eq(GoodsLedger.get_qty(market, good), before)


func test_TST_SYS03_06_market_unbounded_over_ten_seasons() -> void:
	# TST-SYS03-06: 產地無人買、10 商季 → MARKET 庫存持續增加、不被截斷、無溢位（9b）
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var good_id: String = GoodCatalog.all_ids()[0]
	var q_per_season: int = 1
	_set_producer_output("PT-01", good_id, q_per_season)
	# Zero other producers' output so only PT-01×good contributes.
	_zero_other_producers("PT-01", good_id)

	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var good: StringName = StringName(good_id)
	var prev: int = GoodsLedger.get_qty(market, good)
	var seasons: int = TST_SYS03_06_SEASONS
	for _s in range(seasons):
		for k in range(days_d):
			GoodsLedger.run_daily_produce(k)
		var now: int = GoodsLedger.get_qty(market, good)
		assert_gt(now, prev, "MARKET must keep growing each season (no cap)")
		prev = now
	var expected: int = q_per_season * seasons
	assert_eq(GoodsLedger.get_qty(market, good), expected)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_transfer_seq_and_timestamp_match() -> void:
	# D101: timestamp 欄位填與 seq 相同
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	watch_signals(GoodsLedger)
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		GoodsLedger.make_market("PT-01"),
		good,
		1,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_gt(seq, 0)
	assert_true(GoodsLedger.last_error().is_empty(), "success clears last_error")
	assert_signal_emitted(GoodsLedger, "goods_transferred")
	var event: TransferEvent = get_signal_parameters(GoodsLedger, "goods_transferred", 0)[0]
	assert_eq(event.seq, seq)
	assert_eq(event.timestamp, seq)


func test_transfer_event_day_uses_injected_set_day() -> void:
	# 缺口：無 Clock；set_day 可測注入（D-05／D-07：不發明子日公開 API）
	var inject_day: int = 1
	GoodsLedger.set_day(inject_day)
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	watch_signals(GoodsLedger)
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		GoodsLedger.make_market("PT-01"),
		good,
		1,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_gt(seq, 0)
	var event: TransferEvent = get_signal_parameters(GoodsLedger, "goods_transferred", 0)[0]
	assert_eq(event.day, inject_day)


func test_qty_zero_is_err_01() -> void:
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var err: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		GoodsLedger.make_market("PT-01"),
		good,
		0,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_eq(err, 0, "D-04: transfer fail → 0")
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_01), "expected ERR-SYS03-01 in last_error")
	assert_push_error_count(1)


func test_D08d_container_id_unique_formats() -> void:
	# D-08d／TST: sole address producer; MARKET／WAREHOUSE／HOLD／CONFISCATED formats
	var m1: StringName = GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), "PT-01")
	var m2: StringName = GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), "PT-01")
	assert_eq(m1, m2, "same args → identical container_id")
	assert_eq(String(m1), GoodsLedger.CONTAINER_ID_FMT_MARKET % "PT-01")
	assert_eq(
		String(GoodsLedger.container_id(StringName(GoodsLedger.KIND_WAREHOUSE), "AC-1", "PT-02")),
		GoodsLedger.CONTAINER_ID_FMT_WAREHOUSE % ["AC-1", "PT-02"]
	)
	assert_eq(
		String(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-1")),
		GoodsLedger.CONTAINER_ID_FMT_HOLD % "SHIP-1"
	)
	assert_eq(
		String(GoodsLedger.container_id(StringName(GoodsLedger.KIND_CONFISCATED))),
		GoodsLedger.CONTAINER_ID_CONFISCATED
	)
	# Dictionary kind field drives address; stock key matches container_id
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, 1, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	assert_gt(seq, 0)
	assert_true(GoodsLedger._stock.has(String(m1)), "stock keyed by container_id")
	assert_eq(String(GoodsLedger._kind_by_id[String(m1)]), GoodsLedger.KIND_MARKET)


func test_D08e_duplicate_provider_err_sys03_06() -> void:
	# D-08e／TST: same kind registered twice → ERR-SYS03-06
	var provider_a := TestCapacityProvider.new()
	var provider_b := TestCapacityProvider.new()
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider_a),
		GoodsLedger.CODE_OK
	)
	assert_true(GoodsLedger.last_error().is_empty())
	var rc: int = GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider_b)
	assert_eq(rc, GoodsLedger.CODE_FAIL)
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_06), "duplicate kind → ERR-SYS03-06")
	assert_push_error_count(1)
	# WAREHOUSE is a separate kind slot
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_WAREHOUSE), provider_b),
		GoodsLedger.CODE_OK
	)


func test_D08e_unregistered_kind_err_sys03_03() -> void:
	# D-08e／TST: WAREHOUSE／HOLD without provider → ERR-SYS03-03 (not infinite)
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var warehouse: Dictionary = GoodsLedger.make_warehouse("AC-1", "PT-01")
	GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, 1, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	var err: int = GoodsLedger.transfer(market, warehouse, good, 1, GoodsLedger.REASON_LOAD, &"TEST")
	assert_eq(err, 0, "D-04: transfer fail → 0")
	assert_true(_last_error_is(GoodsLedger.ERR_SYS03_03), "unregistered kind → ERR-SYS03-03")
	assert_push_error_count(1)


func test_D08f_conservation_violated_signal_params() -> void:
	# D-08f／TST: conservation_violated(good_id, expected, actual)
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var market: Dictionary = GoodsLedger.make_market("PT-01")
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(), market, good, 1, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	assert_gt(seq, 0)
	var key: String = String(GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), "PT-01"))
	var bucket: Dictionary = GoodsLedger._stock[key]
	var expected_before: int = 1
	bucket[String(good)] = expected_before + 1
	GoodsLedger._stock[key] = bucket
	watch_signals(GoodsLedger)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_FAIL)
	assert_push_error_count(1)
	assert_signal_emitted(GoodsLedger, "conservation_violated")
	var params: Array = get_signal_parameters(GoodsLedger, "conservation_violated", 0)
	assert_eq(params.size(), 3, "D-08f: three params")
	assert_eq(params[0], good)
	assert_eq(params[1], expected_before)
	assert_eq(params[2], expected_before + 1)


func test_D08f_goods_transferred_event_param() -> void:
	# D-08f／TST: goods_transferred(event: TransferEvent)
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	watch_signals(GoodsLedger)
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		GoodsLedger.make_market("PT-01"),
		good,
		1,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_gt(seq, 0)
	assert_signal_emitted(GoodsLedger, "goods_transferred")
	var params: Array = get_signal_parameters(GoodsLedger, "goods_transferred", 0)
	assert_eq(params.size(), 1, "D-08f: single event param")
	var event: TransferEvent = params[0]
	assert_eq(event.seq, seq)
	assert_eq(event.good_id, good)
	assert_eq(event.qty, 1)


# --- helpers ---

func _last_error_is(code: StringName) -> bool:
	var e: Dictionary = GoodsLedger.last_error()
	if not _is_error_info(e):
		return false
	if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) != code:
		return false
	assert_eq(StringName(e.get(ErrorInfoUtil.KEY_SYS, &"")), SYS_ID, "ErrorInfo.sys must be SYS-03")
	var detail: Variant = e.get(ErrorInfoUtil.KEY_DETAIL, null)
	assert_eq(typeof(detail), TYPE_DICTIONARY, "ErrorInfo.detail must be Dictionary")
	return true


func _is_error_info(e: Variant) -> bool:
	# D-04 carrier: {code: StringName, sys: StringName, detail: Dictionary}.
	if typeof(e) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = e
	if d.is_empty():
		return false
	if not d.has(ErrorInfoUtil.KEY_CODE):
		return false
	if not d.has(ErrorInfoUtil.KEY_SYS):
		return false
	if not d.has(ErrorInfoUtil.KEY_DETAIL):
		return false
	# Reject legacy flat shape and any int-coded errors (D-04 withdraw −1..−5).
	if typeof(d[ErrorInfoUtil.KEY_CODE]) == TYPE_INT:
		return false
	return true


# --- fixtures ---

func _set_producer_output(port_id: String, good_id: String, q: int) -> void:
	var def: PortDef = PortRegistry.get_port(port_id)
	var cell: RoleCell = def.role_cells[good_id]
	cell.role = PortRegistry.ROLE_PRODUCER
	cell.base_output_per_season = q
	cell.downstream_terminals = PackedStringArray()


func _zero_other_producers(keep_port: String, keep_good: String) -> void:
	for port_variant in PortRegistry.all_ids():
		var port_id: String = String(port_variant)
		var def: PortDef = PortRegistry.get_port(port_id)
		for good_variant in def.role_cells.keys():
			var good_id: String = String(good_variant)
			if port_id == keep_port and good_id == keep_good:
				continue
			var cell: RoleCell = def.role_cells[good_id]
			if cell.role == PortRegistry.ROLE_PRODUCER:
				cell.base_output_per_season = 0


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
	# D-08a: year-full from PRM-SYS00-SEASONS_PER_YEAR (never literal 15).
	def.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
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
