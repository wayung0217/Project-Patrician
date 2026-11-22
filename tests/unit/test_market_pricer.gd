extends GutTest
## WP-06 MarketPricer tests. Expectations cite TST-SYS04-01..10 / 03_Systems 4.1 (xlsx B463／B467／B470).
## D-01: B463=144000、B470=−13715 exact via AmountQuantize.quantize_amount.
## D-04: validate ErrorInfo {code,sys,detail}; quote fail → last_error().
## D-08g: named Band enum BAND_VERY_LOW…BAND_VERY_HIGH.
## WP-32: offtake snapshot fixture；TransitAnchorProvider／ERR-SYS04-07 removed (D-20b).


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const GOODS_FIXTURE_ROOT := "user://market_pricer_goods/"
const PORTS_FIXTURE_ROOT := "user://market_pricer_ports/"
const CURVE_FIXTURE_ROOT := "user://market_pricer_curves/"
## R2-13 / 2.1-04 ⑤: tests load curve from fixtures only (formal path after #11 via Owner csv_import).
## weeks: PRM-SYS04-CURVE_W1=0, W2=1, W3=3, W4=6, W5=10 (03_Systems §4)
## mults: PRM-SYS04-CURVE_M1=2, M2=1.4, M3=1, M4=1, M5=0.6 (03_Systems §4)
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const PARAMS_OVERRIDE_ROOT := "user://market_pricer_params/"

const SYS_ID := &"SYS-04"

const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_HALF_SPREAD := "PRM-SYS04-HALF_SPREAD"
const PRM_IND_HI2 := "PRM-SYS04-IND_HI2"
const PRM_IND_HI1 := "PRM-SYS04-IND_HI1"
const PRM_IND_LO1 := "PRM-SYS04-IND_LO1"
const PRM_IND_LO2 := "PRM-SYS04-IND_LO2"
const PRM_ROUND_EPS := "PRM-SYS04-ROUND_EPS"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"

const PORT_DEMO := "PT-01"
const PORT_TERMINAL := "PT-02"
const PORT_TRANSIT := "PT-03"
const GOOD_DEMO := "GD-001"
## 03_Systems 4.1 demo inputs (xlsx B447–B452)
const DEMO_ANCHOR_LI := 1000 ## B447
const DEMO_WEEKLY_C := 105 ## B449 = 15 × DAYS_PER_WEEK
const DEMO_STOCK := 300 ## B450
const DEMO_Q := 120 ## B451
const DEMO_Q1 := 50 ## B452
## TST-SYS04-04／xlsx B467
const DEMO_SPLIT_EXTRA_LI := 0
## TST-SYS04-05／xlsx B470
const DEMO_ROUNDTRIP_PNL_LI := -13715
const DEMO_BUY_TOTAL_LI := 144000 ## B463
const DEMO_SELL_TOTAL_LI := 130285 ## B469

## TST-SYS04-02
const TST02_W := 2.0
const TST02_M_AT_2 := 1.2
const TST02_W_PLAT_LO := 3.0
const TST02_W_PLAT_HI := 6.0
const TST02_M_PLAT := 1.0

## T7 named consts (no 1+1 / 1.0+1.0 / 0-1 evasions)
const TWO := 2
const THREE := 3
const HALF_F := 0.5
const PORT_COUNT_TRANSIT_MIN := 3

## TST-SYS04-03
const TST03_W_CEIL := 0.0
const TST03_M_CEIL := 2.0
const TST03_W_FLOOR := 50.0
const TST03_M_FLOOR := 0.6

## TST-SYS04-06：HALF_SPREAD 下限（PRM range min）
const TST06_HALF_SPREAD_MIN := 0.01

## TST-SYS04-07
const TST07_Q := 10
## CEIL(anchor × M_n × 10 × (1+h)) with defaults：CEIL(1000×0.6×10×1.05)=6300
const TST07_BUY_TOTAL := 6300

## TST-SYS04-08
const TST08_ANCHOR_LI := 1

## TST-SYS04-09 ratios／bands（TechSpec §5）
const TST09_R_TOO_HIGH := 1.5
const TST09_R_EQ_HI1 := 1.05
const TST09_R_EQ_LO1 := 0.95
const TST09_R_TOO_LOW := 0.75
const TST09_R_HIGH := 1.2

## TST-SYS04-10
const TST10_STOCK := 100
const TST10_Q_OVER := 101

## TST-SYS04-01 bad W1
const TST01_BAD_W1 := 0.5

## Split-extra allowed set {0,1} (TST-SYS04-04)
const SPLIT_EXTRA_MAX := 1


## WP-32: pricing tests inject previous-day offtake snapshot on GoodsLedger (fixture).


func before_each() -> void:
	var params_errors: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(params_errors.size(), 0, "params fixture must load")
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	_wipe_dir(CURVE_FIXTURE_ROOT)
	_wipe_dir(PARAMS_OVERRIDE_ROOT)
	## D-30a: unload ShipRegistry so HOLD transfer fixtures are not dock-gated.
	ShipRegistry._loaded = false
	ShipRegistry._sailor_pool = null


func test_WP59_consumption_provider_base_push_error() -> void:
	# 2.1-03／TechSpec 3.7: 基底方法一律 push_error 並回失敗值
	# WP-32／15-05: weekly_consumption removed from interface.
	var base := ConsumptionProvider.new()
	var c: int = base.consume_qty(&"PT-01", &"GD-001", 0)
	assert_eq(c, ConsumptionProvider.CONSUMPTION_FAILURE)
	assert_push_error_count(1)


func test_WP59_D08g_named_band_enum_order() -> void:
	# D-08g: BAND_VERY_LOW…BAND_VERY_HIGH named enum；0 過低→4 過高；不得裸用 0..4 比較。
	assert_eq(MarketPricer.BAND_VERY_LOW, MarketPricer.Band.VERY_LOW)
	assert_eq(MarketPricer.BAND_LOW, MarketPricer.Band.LOW)
	assert_eq(MarketPricer.BAND_EQUILIBRIUM, MarketPricer.Band.EQUILIBRIUM)
	assert_eq(MarketPricer.BAND_HIGH, MarketPricer.Band.HIGH)
	assert_eq(MarketPricer.BAND_VERY_HIGH, MarketPricer.Band.VERY_HIGH)
	assert_lt(MarketPricer.BAND_VERY_LOW, MarketPricer.BAND_LOW)
	assert_lt(MarketPricer.BAND_LOW, MarketPricer.BAND_EQUILIBRIUM)
	assert_lt(MarketPricer.BAND_EQUILIBRIUM, MarketPricer.BAND_HIGH)
	assert_lt(MarketPricer.BAND_HIGH, MarketPricer.BAND_VERY_HIGH)
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, DEMO_STOCK)
	assert_eq(MarketPricer.indicator_band(TST09_R_TOO_LOW), MarketPricer.BAND_VERY_LOW)
	assert_eq(MarketPricer.indicator_band(TST09_R_TOO_HIGH), MarketPricer.BAND_VERY_HIGH)


# DELETED (D-20b): test_D08h_transit_anchor_provider_base_fails
# DELETED (D-20b): test_D08h_transit_without_provider_returns_err_sys04_07
# DELETED (D-20b): test_D08h_transit_with_provider_uses_anchor


func test_TST_SYS04_01_curve_validation_errors() -> void:
	# TST-SYS04-01: W1≠0／W 非嚴格遞增／M 遞增／M≤0 → ERR-SYS04-01..04；不自動修正
	_boot_catalog_ports_ledger(DEMO_ANCHOR_LI)
	var push_total: int = 0

	var path_w1 := CURVE_FIXTURE_ROOT + "bad_w1.tres"
	_save_curve(path_w1, [TST01_BAD_W1, 1.0, 3.0, 6.0, 10.0], [2.0, 1.4, 1.0, 1.0, 0.6])
	var e1: Array = MarketPricer.load_and_validate(path_w1)
	assert_true(_has_code(e1, MarketPricer.ERR_SYS04_01), "W1≠0 → ERR-SYS04-01")
	assert_false(MarketPricer.is_loaded())
	push_total += e1.size()

	var path_w_inc := CURVE_FIXTURE_ROOT + "bad_w_inc.tres"
	_save_curve(path_w_inc, [0.0, 3.0, 1.0, 6.0, 10.0], [2.0, 1.4, 1.0, 1.0, 0.6])
	var e2: Array = MarketPricer.load_and_validate(path_w_inc)
	assert_true(_has_code(e2, MarketPricer.ERR_SYS04_02), "weeks not strict ↑ → ERR-SYS04-02")
	push_total += e2.size()

	var path_m_inc := CURVE_FIXTURE_ROOT + "bad_m_inc.tres"
	_save_curve(path_m_inc, [0.0, 1.0, 3.0, 6.0, 10.0], [1.0, 1.4, 1.0, 1.0, 0.6])
	var e3: Array = MarketPricer.load_and_validate(path_m_inc)
	assert_true(_has_code(e3, MarketPricer.ERR_SYS04_03), "mult increasing → ERR-SYS04-03")
	push_total += e3.size()

	var path_m_le0 := CURVE_FIXTURE_ROOT + "bad_m_le0.tres"
	_save_curve(path_m_le0, [0.0, 1.0, 3.0, 6.0, 10.0], [2.0, 1.4, 1.0, 1.0, 0.0])
	var e4: Array = MarketPricer.load_and_validate(path_m_le0)
	assert_true(_has_code(e4, MarketPricer.ERR_SYS04_04), "mult≤0 → ERR-SYS04-04")
	push_total += e4.size()
	assert_push_error_count(push_total)


func test_TST_SYS04_02_mid_multiplier_platform() -> void:
	# TST-SYS04-02／AB3: w=2 → m=1.2；w=3..6 → m=1.0；mid_price asserts plateau path
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, DEMO_STOCK)
	assert_eq(MarketPricer.multiplier_at_weeks(TST02_W), TST02_M_AT_2)
	assert_eq(MarketPricer.multiplier_at_weeks(TST02_W_PLAT_LO), TST02_M_PLAT)
	assert_eq(MarketPricer.multiplier_at_weeks(TST02_W_PLAT_HI), TST02_M_PLAT)
	var mid2: float = MarketPricer.mid_price(StringName(PORT_DEMO), StringName(GOOD_DEMO))
	# stock/C = 300/105 ≈ 2.857 → interpolate between M2=1.4 and M3=1.0
	var weeks: float = float(DEMO_STOCK) / float(DEMO_WEEKLY_C)
	var expected_mid: float = float(DEMO_ANCHOR_LI) * MarketPricer.multiplier_at_weeks(weeks)
	assert_eq(mid2, expected_mid)
	assert_gt(weeks, TST02_W)
	assert_lt(weeks, TST02_W_PLAT_LO)


func test_TST_SYS04_03_ceiling_and_floor() -> void:
	# TST-SYS04-03: w=0 → m=2.0；w=50 → m=0.6
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, DEMO_STOCK)
	assert_eq(MarketPricer.multiplier_at_weeks(TST03_W_CEIL), TST03_M_CEIL)
	assert_eq(MarketPricer.multiplier_at_weeks(TST03_W_FLOOR), TST03_M_FLOOR)


func test_TST_SYS04_04_split_vs_batch_extra_in_0_1() -> void:
	# TST-SYS04-04／D-01: 拆單多付 ∈ {0,1}；B467 = 0；整批買 B463 = 144000
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, DEMO_STOCK)
	var buy_all: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, DEMO_Q
	)
	assert_false(buy_all.has(MarketPricer.KEY_ERROR))
	assert_true(MarketPricer.last_error().is_empty())
	var total_all: int = int(buy_all[MarketPricer.KEY_TOTAL_LI])
	assert_eq(total_all, DEMO_BUY_TOTAL_LI, "D-01／xlsx B463 exact buy total")

	var buy1: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, DEMO_Q1
	)
	assert_false(buy1.has(MarketPricer.KEY_ERROR))
	# Apply first fill to stock so second quote sees s−q1 (SYS-04 itself does not write).
	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-DEMO", "ACTOR-DEMO")
	var provider := _cap_provider_unlimited(hold)
	assert_eq(
		GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), provider),
		GoodsLedger.CODE_OK
	)
	var seq1: int = GoodsLedger.transfer(
		market, hold, StringName(GOOD_DEMO), DEMO_Q1, GoodsLedger.REASON_TRADE, &"TEST"
	)
	assert_gt(seq1, 0)

	var q2: int = DEMO_Q - DEMO_Q1
	var buy2: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, q2
	)
	assert_false(buy2.has(MarketPricer.KEY_ERROR))
	var extra: int = int(buy1[MarketPricer.KEY_TOTAL_LI]) + int(buy2[MarketPricer.KEY_TOTAL_LI]) - total_all
	assert_gte(extra, 0)
	assert_lte(extra, SPLIT_EXTRA_MAX)
	# 示範 4.1 B467 = 0（xlsx）；硬條件 ∈ {0,1}
	assert_eq(extra, DEMO_SPLIT_EXTRA_LI)


func test_TST_SYS04_05_roundtrip_loss() -> void:
	# TST-SYS04-05／D-01: 買 q 後立即原港賣回 → 損益 < 0；xlsx B470 = −13,715
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, DEMO_STOCK)
	var buy: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, DEMO_Q
	)
	assert_false(buy.has(MarketPricer.KEY_ERROR))
	var buy_total: int = int(buy[MarketPricer.KEY_TOTAL_LI])
	assert_eq(buy_total, DEMO_BUY_TOTAL_LI, "D-01／xlsx B463")

	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-RT", "ACTOR-RT")
	assert_eq(
		GoodsLedger.register_capacity_provider(
			StringName(GoodsLedger.KIND_HOLD), _cap_provider_unlimited(hold)
		),
		GoodsLedger.CODE_OK
	)
	var seq: int = GoodsLedger.transfer(
		market, hold, StringName(GOOD_DEMO), DEMO_Q, GoodsLedger.REASON_TRADE, &"TEST"
	)
	assert_gt(seq, 0)

	var sell: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_SELL, DEMO_Q
	)
	assert_false(sell.has(MarketPricer.KEY_ERROR))
	var sell_total: int = int(sell[MarketPricer.KEY_TOTAL_LI])
	var pnl: int = sell_total - buy_total
	assert_lt(pnl, 0)
	assert_eq(sell_total, DEMO_SELL_TOTAL_LI)
	assert_eq(pnl, DEMO_ROUNDTRIP_PNL_LI, "D-01／xlsx B470 exact roundtrip pnl")


func test_TST_SYS04_06_min_half_spread_still_loss() -> void:
	# TST-SYS04-06: HALF_SPREAD=0.01 同港來回仍虧
	_write_params_override({PRM_HALF_SPREAD: TST06_HALF_SPREAD_MIN})
	var perr: Array = Params.load_and_validate(PARAMS_OVERRIDE_ROOT + "params.json")
	assert_eq(perr.size(), 0)
	_boot_catalog_ports_ledger(DEMO_ANCHOR_LI)
	_seed_market(PORT_DEMO, DEMO_STOCK)
	var merr: Array = MarketPricer.load_and_validate(CURVE_FIXTURE)
	assert_eq(merr.size(), 0)
	_inject_offtake_weekly(PORT_DEMO, GOOD_DEMO, DEMO_WEEKLY_C)

	var buy: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, DEMO_Q
	)
	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-HS", "ACTOR-HS")
	assert_eq(
		GoodsLedger.register_capacity_provider(
			StringName(GoodsLedger.KIND_HOLD), _cap_provider_unlimited(hold)
		),
		GoodsLedger.CODE_OK
	)
	assert_gt(
		GoodsLedger.transfer(market, hold, StringName(GOOD_DEMO), DEMO_Q, GoodsLedger.REASON_TRADE, &"TEST"),
		0
	)
	var sell: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_SELL, DEMO_Q
	)
	var pnl: int = int(sell[MarketPricer.KEY_TOTAL_LI]) - int(buy[MarketPricer.KEY_TOTAL_LI])
	assert_lt(pnl, 0)


func test_TST_SYS04_07_zero_consumption_floor() -> void:
	# TST-SYS04-07: C=0 → m=M_n；買 10 總額 = CEIL(anchor×M_n×10×(1+h))
	_boot_full(DEMO_ANCHOR_LI, 0, DEMO_STOCK)
	var buy: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, TST07_Q
	)
	assert_false(buy.has(MarketPricer.KEY_ERROR))
	assert_eq(int(buy[MarketPricer.KEY_TOTAL_LI]), TST07_BUY_TOTAL)


func test_TST_SYS04_08_floor_anchor_rejects() -> void:
	# TST-SYS04-08: anchor=1 → ERR-SYS04-05
	_boot_catalog_ports_ledger(TST08_ANCHOR_LI)
	var errors: Array = MarketPricer.load_and_validate(CURVE_FIXTURE)
	assert_true(_has_code(errors, MarketPricer.ERR_SYS04_05))
	assert_false(MarketPricer.is_loaded())
	assert_push_error_count(errors.size())


func test_TST_SYS04_09_indicator_bands_and_order() -> void:
	# TST-SYS04-09／D-08g: r 切點 → 過高／均衡／均衡／過低／偏高；切點次序錯 → ERR-SYS04-08
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, DEMO_STOCK)
	assert_eq(MarketPricer.indicator_band(TST09_R_TOO_HIGH), MarketPricer.BAND_VERY_HIGH)
	assert_eq(MarketPricer.indicator_band(TST09_R_EQ_HI1), MarketPricer.BAND_EQUILIBRIUM)
	assert_eq(MarketPricer.indicator_band(TST09_R_EQ_LO1), MarketPricer.BAND_EQUILIBRIUM)
	assert_eq(MarketPricer.indicator_band(TST09_R_TOO_LOW), MarketPricer.BAND_VERY_LOW)
	assert_eq(MarketPricer.indicator_band(TST09_R_HIGH), MarketPricer.BAND_HIGH)

	_write_params_override({PRM_IND_HI1: 2.0, PRM_IND_HI2: 1.5}) # HI1 ≥ HI2 → bad order
	var perr: Array = Params.load_and_validate(PARAMS_OVERRIDE_ROOT + "params.json")
	assert_eq(perr.size(), 0)
	# Reload curve validation with bad IND order
	_boot_catalog_ports_ledger(DEMO_ANCHOR_LI)
	var errors: Array = MarketPricer.load_and_validate(CURVE_FIXTURE)
	assert_true(_has_code(errors, MarketPricer.ERR_SYS04_08))
	assert_push_error_count(errors.size())


func test_TST_SYS04_10_qty_rejects_no_state_change() -> void:
	# TST-SYS04-10: s=100；買 101 或 q=0 → ERR-SYS04-06；ST-GOOD 不變（SYS-04 不寫入）
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, TST10_STOCK)
	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var before: int = GoodsLedger.get_qty(market, StringName(GOOD_DEMO))
	assert_eq(before, TST10_STOCK)

	var over: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, TST10_Q_OVER
	)
	assert_eq(over[MarketPricer.KEY_ERROR], MarketPricer.ERR_SYS04_06)
	assert_true(_last_error_is(MarketPricer.ERR_SYS04_06), "D-04: quote fail → last_error ERR-SYS04-06")

	var zero: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, 0
	)
	assert_eq(zero[MarketPricer.KEY_ERROR], MarketPricer.ERR_SYS04_06)
	assert_true(_last_error_is(MarketPricer.ERR_SYS04_06))
	assert_push_error_count(TWO)

	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD_DEMO)), TST10_STOCK)


func test_WP59_D01_quantize_amount_snaps_near_integer() -> void:
	# D-01: |x−round(x)| <= ROUND_EPS×max(1,|x|) → snap；else leave; EPS from Params (no bare 1e-9).
	_boot_full(DEMO_ANCHOR_LI, DEMO_WEEKLY_C, DEMO_STOCK)
	var eps: float = Params.get_float(PRM_ROUND_EPS)
	assert_gt(eps, 0.0)
	var near: float = float(DEMO_BUY_TOTAL_LI) + eps * HALF_F
	assert_eq(AmountQuantize.quantize_amount(near), float(DEMO_BUY_TOTAL_LI))
	var far: float = float(DEMO_BUY_TOTAL_LI) + HALF_F
	assert_eq(AmountQuantize.quantize_amount(far), far)


func test_TST_SYS04_11_zero_window_qty_floor() -> void:
	# TST-SYS04-11／AB2: window_qty＝0 with normal window_days（≠ SYS04-07 C=0 via weekly inject）.
	_boot_catalog_ports_ledger(DEMO_ANCHOR_LI)
	_seed_market(PORT_DEMO, DEMO_STOCK)
	var errors: Array = MarketPricer.load_and_validate(CURVE_FIXTURE)
	assert_eq(errors.size(), 0, "MarketPricer must load: %s" % str(errors))
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	assert_gt(days_pw, 0)
	GoodsLedger.seed_offtake_snapshot(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), 0, 0, days_pw, 0
	)
	for gid_variant in GoodCatalog.all_ids():
		var gid: String = String(gid_variant)
		if gid != GOOD_DEMO:
			GoodsLedger.seed_offtake_snapshot(
				StringName(PORT_DEMO), StringName(gid), 0, 0, days_pw, 0
			)
	var snap: Dictionary = GoodsLedger.offtake_snapshot(
		StringName(PORT_DEMO), StringName(GOOD_DEMO)
	)
	assert_eq(int(snap.get(GoodsLedger.FIELD_WINDOW_QTY, -1)), 0)
	assert_eq(int(snap.get(GoodsLedger.FIELD_WINDOW_DAYS, -1)), days_pw)
	var buy: Dictionary = MarketPricer.quote(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), MarketPricer.SIDE_BUY, TST07_Q
	)
	assert_false(buy.has(MarketPricer.KEY_ERROR))
	assert_eq(int(buy[MarketPricer.KEY_TOTAL_LI]), TST07_BUY_TOTAL)


func test_TST_SYS04_12_transit_uses_base_price_li() -> void:
	# TST-SYS04-12: 原 TRANSIT 角色格 → anchor＝base_price_li；無 TransitAnchor／ERR-SYS04-07
	_boot_catalog_ports_ledger_transit(DEMO_ANCHOR_LI)
	_seed_market(PORT_TRANSIT, DEMO_STOCK)
	var errors: Array = MarketPricer.load_and_validate(CURVE_FIXTURE)
	assert_eq(errors.size(), 0)
	_inject_offtake_weekly(PORT_TRANSIT, GOOD_DEMO, DEMO_WEEKLY_C)
	var mid: float = MarketPricer.mid_price(StringName(PORT_TRANSIT), StringName(GOOD_DEMO))
	assert_gt(mid, 0.0)
	assert_true(MarketPricer.last_error().is_empty())
	# mid = anchor × m；anchor must be base_price_li (1000), not a transit-derived price.
	var stock: int = GoodsLedger.get_qty(GoodsLedger.make_market(PORT_TRANSIT), StringName(GOOD_DEMO))
	var w: float = float(stock) / float(DEMO_WEEKLY_C)
	var expected: float = float(DEMO_ANCHOR_LI) * MarketPricer.multiplier_at_weeks(w)
	assert_eq(mid, expected)


func test_TST_SYS04_13_offtake_weeks_fixture() -> void:
	# TST-SYS04-13: window_qty 70、window_days 7、DAYS_PER_WEEK 7、stock 210 → weekly_offtake＝70、w＝3、m＝M3
	_boot_catalog_ports_ledger(DEMO_ANCHOR_LI)
	_seed_market(PORT_DEMO, 210)
	var errors: Array = MarketPricer.load_and_validate(CURVE_FIXTURE)
	assert_eq(errors.size(), 0)
	GoodsLedger.seed_offtake_snapshot(
		StringName(PORT_DEMO), StringName(GOOD_DEMO), 70, 70, 7, 0
	)
	var mid: float = MarketPricer.mid_price(StringName(PORT_DEMO), StringName(GOOD_DEMO))
	# w=3 → m=M3=1.0 on fixture curve; mid = 1000 × 1.0
	assert_eq(mid, float(DEMO_ANCHOR_LI) * 1.0)


# --- boot helpers ---

func _boot_full(anchor_li: int, weekly_c: int, stock: int) -> void:
	# WP-32／15-08 ②: inject offtake snapshot fixture (weekly_offtake ≡ former weekly_c).
	_boot_catalog_ports_ledger(anchor_li)
	_seed_market(PORT_DEMO, stock)
	var errors: Array = MarketPricer.load_and_validate(CURVE_FIXTURE)
	assert_eq(errors.size(), 0, "MarketPricer must load: %s" % str(errors))
	_inject_offtake_weekly(PORT_DEMO, GOOD_DEMO, weekly_c)
	for gid_variant in GoodCatalog.all_ids():
		var gid: String = String(gid_variant)
		if gid != GOOD_DEMO:
			_inject_offtake_weekly(PORT_DEMO, gid, weekly_c)


func _inject_offtake_weekly(port_id: String, good_id: String, weekly_offtake: int) -> void:
	# weekly_offtake = window_qty × DAYS_PER_WEEK ÷ window_days; use window_days=DAYS_PER_WEEK.
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var window_days: int = days_pw if days_pw > 0 else 1
	GoodsLedger.seed_offtake_snapshot(
		StringName(port_id), StringName(good_id), weekly_offtake, weekly_offtake, window_days, 0
	)


func _boot_catalog_ports_ledger(anchor_li: int) -> void:
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/", anchor_li)
	var gerr: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(gerr.size(), 0, "goods must load")
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var ports_dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "base/")
	var perr: Array = PortRegistry.load_and_validate(ports_dir)
	assert_eq(perr.size(), 0, "ports must load")
	var lerr: Array = GoodsLedger.load_and_validate()
	assert_eq(lerr.size(), 0, "ledger must load")


func _boot_catalog_ports_ledger_transit(anchor_li: int) -> void:
	# WP-32: TRANSIT loads without downstream validation; used by TST-SYS04-12.
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "transit/", anchor_li)
	var gerr: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(gerr.size(), 0, "goods must load")
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	if port_count < PORT_COUNT_TRANSIT_MIN:
		port_count = PORT_COUNT_TRANSIT_MIN
	var ports_dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "transit/")
	_set_transit(ports_dir, PORT_TRANSIT, GOOD_DEMO, PackedStringArray([PORT_TERMINAL]))
	var perr: Array = PortRegistry.load_and_validate(ports_dir)
	assert_eq(perr.size(), 0, "ports with TRANSIT must load: %s" % str(perr))
	var lerr: Array = GoodsLedger.load_and_validate()
	assert_eq(lerr.size(), 0, "ledger must load")


func _set_transit(dir: String, port_id: String, good_id: String, downstream: PackedStringArray) -> void:
	var path := dir + "%s.tres" % port_id
	var port: PortDef = load(path) as PortDef
	assert_ne(port, null)
	var cell: RoleCell = port.role_cells[good_id]
	cell.role = PortRegistry.ROLE_TRANSIT
	cell.base_output_per_season = 0
	cell.downstream_terminals = downstream
	port.role_cells[good_id] = cell
	var err: int = ResourceSaver.save(port, path)
	assert_eq(err, OK)


func _seed_market(port_id: String, stock: int) -> void:
	if stock <= 0:
		return
	var market: Dictionary = GoodsLedger.make_market(port_id)
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		market,
		StringName(GOOD_DEMO),
		stock,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_gt(seq, 0)


func _cap_provider_unlimited(hold: Dictionary) -> CapacityProvider:
	var p := TestCap.new()
	p.set_cap(hold, DEMO_STOCK + DEMO_STOCK)
	return p


class TestCap extends CapacityProvider:
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
		if kind == "HOLD":
			return "HOLD|%s" % String(d.get("ship", ""))
		return kind


func _save_curve(path: String, weeks: Array, mults: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CURVE_FIXTURE_ROOT))
	var curve := PriceCurve.new()
	curve.weeks = PackedFloat64Array(weeks)
	curve.mults = PackedFloat64Array(mults)
	var err: int = ResourceSaver.save(curve, path)
	assert_eq(err, OK)


func _write_params_override(overrides: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARAMS_OVERRIDE_ROOT))
	var src := FileAccess.open(PARAMS_FIXTURE, FileAccess.READ)
	var data: Variant = JSON.parse_string(src.get_as_text())
	var d: Dictionary = data
	for k in overrides.keys():
		d[String(k)] = overrides[k]
	var out := FileAccess.open(PARAMS_OVERRIDE_ROOT + "params.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(d))


func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not _is_error_info(e):
			continue
		if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) == code:
			assert_eq(StringName(e.get(ErrorInfoUtil.KEY_SYS, &"")), SYS_ID, "ErrorInfo.sys must be SYS-04")
			var detail: Variant = e.get(ErrorInfoUtil.KEY_DETAIL, null)
			assert_eq(typeof(detail), TYPE_DICTIONARY, "ErrorInfo.detail must be Dictionary")
			return true
	return false


func _last_error_is(code: StringName) -> bool:
	var e: Dictionary = MarketPricer.last_error()
	if e.is_empty() or not _is_error_info(e):
		return false
	if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) != code:
		return false
	assert_eq(StringName(e.get(ErrorInfoUtil.KEY_SYS, &"")), SYS_ID, "ErrorInfo.sys must be SYS-04")
	var detail: Variant = e.get(ErrorInfoUtil.KEY_DETAIL, null)
	assert_eq(typeof(detail), TYPE_DICTIONARY, "ErrorInfo.detail must be Dictionary")
	return true


func _is_error_info(e: Variant) -> bool:
	# D-04 carrier: {code: StringName, sys: StringName, detail: Dictionary}.
	if typeof(e) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = e
	if not d.has(ErrorInfoUtil.KEY_CODE):
		return false
	if not d.has(ErrorInfoUtil.KEY_SYS):
		return false
	if not d.has(ErrorInfoUtil.KEY_DETAIL):
		return false
	if typeof(d[ErrorInfoUtil.KEY_CODE]) == TYPE_INT:
		return false
	return typeof(d[ErrorInfoUtil.KEY_DETAIL]) == TYPE_DICTIONARY


func _build_valid_goods(dir: String, anchor_li: int) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": GOOD_DEMO, "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
		{"id": "GD-004", "name": STAPLE_FISH, "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		var price: int = anchor_li if String(s["id"]) == GOOD_DEMO else anchor_li
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], false, price),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(
			_make_good(gid, "填料%d" % next_n, tier, false, false, false, anchor_li),
			dir + "%s.tres" % gid
		)
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
