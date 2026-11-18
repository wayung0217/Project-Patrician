extends Node
## Autoload: MarketPricer — SYS-04 pure pricing (TechSpec 3.5 / WP-06).
## _ready() only clears fields; load_and_validate() loads curve + FRM checks (2.2-01).
## No signals; does not write ST-GOOD／ST-CASH. weekly_consumption via ConsumptionProvider (3.7／B2).
## D-01: money float→int only via AmountQuantize.quantize_amount then ceili／floori.
## D-04: ErrorInfo {code,sys,detail} for validate Arrays／last_error(); no ERR→int.

const CURVE_PATH := "res://data/market/price_curve.tres"
const SCRIPT_PATH := "res://autoload/market_pricer.gd"
const SYS_ID := &"SYS-04"

const PRM_HALF_SPREAD := "PRM-SYS04-HALF_SPREAD"
const PRM_IND_HI2 := "PRM-SYS04-IND_HI2"
const PRM_IND_HI1 := "PRM-SYS04-IND_HI1"
const PRM_IND_LO1 := "PRM-SYS04-IND_LO1"
const PRM_IND_LO2 := "PRM-SYS04-IND_LO2"
const PRM_MIN_CASH_UNIT := "PRM-SYS05-MIN_CASH_UNIT"

## TechSpec 3.5 H: side BUY=0, SELL=1 (allowed 0／1 literals per C-03).
const SIDE_BUY := 0
const SIDE_SELL := 1

## FRM-SYS04-10／D-08g: named band enum — 0 過低／1 偏低／2 均衡／3 偏高／4 過高（數字越大越貴）.
## Call sites must use BAND_* names; never compare bare 0..4 (D-08g).
enum Band {
	VERY_LOW,
	LOW,
	EQUILIBRIUM,
	HIGH,
	VERY_HIGH,
}

const BAND_VERY_LOW := Band.VERY_LOW
const BAND_LOW := Band.LOW
const BAND_EQUILIBRIUM := Band.EQUILIBRIUM
const BAND_HIGH := Band.HIGH
const BAND_VERY_HIGH := Band.VERY_HIGH

## FRM-SYS04-07: 斷點數 ≥ 2 (built from 0／1 only).
const MIN_BREAKPOINTS := 1 + 1

const ERR_SYS04_01 := &"ERR-SYS04-01"
const ERR_SYS04_02 := &"ERR-SYS04-02"
const ERR_SYS04_03 := &"ERR-SYS04-03"
const ERR_SYS04_04 := &"ERR-SYS04-04"
const ERR_SYS04_05 := &"ERR-SYS04-05"
const ERR_SYS04_06 := &"ERR-SYS04-06"
const ERR_SYS04_07 := &"ERR-SYS04-07"
const ERR_SYS04_08 := &"ERR-SYS04-08"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_CURVE_MISSING := &"CURVE_MISSING"
const CODE_CURVE_TYPE := &"CURVE_TYPE"
const CODE_CONSUMPTION := &"ConsumptionProvider"
const CODE_GOODS_LEDGER := &"GoodsLedger"

const KEY_TOTAL_LI := "total_li"
const KEY_AVG_LI := "avg_li"
const KEY_MID_AFTER := "mid_after"
const KEY_BAND_AFTER := "band_after"
const KEY_ERROR := "error"

const FIELD_PARAMS := "Params"
const FIELD_CURVE := "price_curve"
const FIELD_WEEKS := "weeks"
const FIELD_MULTS := "mults"
const FIELD_ANCHOR := "anchor_price_li"
const FIELD_IND := "IND_*"
const FIELD_QTY := "qty"
const FIELD_SIDE := "side"
const FIELD_CONSUMPTION := "ConsumptionProvider"
const FIELD_GOODS_LEDGER := "GoodsLedger"

const EQ_MULT := 1.0 ## FRM-SYS04-10／r475: IND_LO1 ≤ 1 ≤ IND_HI1 (結構 1.0)

var _curve: PriceCurve = null
var _consumption: ConsumptionProvider = null
## D-08h: optional TransitAnchorProvider (SYS-15). Phase 0 null → TRANSIT always ERR-SYS04-07.
var _transit_anchor: TransitAnchorProvider = null
var _loaded: bool = false
## D-04: last single-call ErrorInfo {code,sys,detail}; empty Dictionary when none.
var _last_error: Dictionary = {}


func _ready() -> void:
	_clear_state()


func load_and_validate(curve_path: String = CURVE_PATH) -> Array:
	# 2.2-01／2.2-02: load curve + FRM-SYS04-07／08／10; no quotes; no writes.
	# ConsumptionProvider is injected separately (like CapacityProvider); not cleared here.
	var errors: Array = []
	_curve = null
	_loaded = false
	_clear_last_error()

	if not Params.is_loaded():
		errors.append(_err(CODE_PARAMS_NOT_LOADED, SCRIPT_PATH, FIELD_PARAMS, null, "Params must load_and_validate before MarketPricer"))
		_emit_errors(errors)
		return errors

	if not FileAccess.file_exists(curve_path):
		errors.append(_err(CODE_CURVE_MISSING, curve_path, FIELD_CURVE, null, "price_curve.tres not found"))
		_emit_errors(errors)
		return errors

	var res: Resource = ResourceLoader.load(curve_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null or not (res is PriceCurve):
		errors.append(_err(CODE_CURVE_TYPE, curve_path, FIELD_CURVE, res, "expected PriceCurve Resource"))
		_emit_errors(errors)
		return errors

	_curve = res as PriceCurve
	errors.append_array(_validate_curve(_curve, curve_path))
	errors.append_array(_validate_indicator_order())
	errors.append_array(_validate_floor_anchors())

	# D-08h／ERR-SYS04-07：validate 不掃 TRANSIT（Phase 0 無 TransitAnchorProvider，掃則無法啟動）。
	# quote／mid_price 經 TransitAnchorProvider；無提供者或回 0 → ERR-SYS04-07（不得自填運費／比例）。

	if errors.is_empty():
		_loaded = true
	else:
		_loaded = false
		_curve = null
		_emit_errors(errors)
	return errors


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	# D-04: single-call failures (quote／mid_price) expose ErrorInfo here.
	return _last_error.duplicate(true)


func set_consumption_provider(provider: ConsumptionProvider) -> void:
	## 缺口：TechSpec H 未列登錄 API；比照 GoodsLedger.register_capacity_provider（測試／未來 SYS-06）。
	_consumption = provider


func set_transit_anchor_provider(provider: TransitAnchorProvider) -> void:
	## D-08h：中轉格錨定價由 SYS-15 實作；Phase 0 不注入 → TRANSIT 一律 ERR-SYS04-07。
	_transit_anchor = provider


func validate() -> Array:
	# H: validate() -> Array — re-run FRM checks on current curve／params／anchors.
	assert(_curve != null or not _loaded, "validate without curve")
	var errors: Array = []
	if not Params.is_loaded():
		errors.append(_err(CODE_PARAMS_NOT_LOADED, SCRIPT_PATH, FIELD_PARAMS, null, "Params not loaded"))
		return errors
	if _curve == null:
		errors.append(_err(CODE_CURVE_MISSING, CURVE_PATH, FIELD_CURVE, null, "no curve loaded"))
		return errors
	errors.append_array(_validate_curve(_curve, CURVE_PATH))
	errors.append_array(_validate_indicator_order())
	errors.append_array(_validate_floor_anchors())
	return errors


func mid_price(port_id: StringName, good_id: StringName) -> float:
	# FRM-SYS04-03: mid = anchor × m(w)
	assert(_loaded, "MarketPricer.mid_price before load_and_validate")
	_clear_last_error()
	var ctx: Dictionary = _resolve_context(port_id, good_id)
	if ctx.has(KEY_ERROR):
		_fail_from_ctx(ctx)
		return 0.0
	var anchor: int = int(ctx[FIELD_ANCHOR])
	var stock: int = int(ctx["stock"])
	var c_i: int = int(ctx["weekly_consumption"])
	var m: float = _multiplier_for_stock(stock, c_i)
	return float(anchor) * m


func quote(port_id: StringName, good_id: StringName, side: int, qty: int) -> Dictionary:
	# FRM-SYS04-04／05 + D-01: batch area; quantize_amount then CEIL buy／FLOOR sell.
	assert(_loaded, "MarketPricer.quote before load_and_validate")
	_clear_last_error()
	var out: Dictionary = {
		KEY_TOTAL_LI: 0,
		KEY_AVG_LI: 0.0,
		KEY_MID_AFTER: 0.0,
		KEY_BAND_AFTER: BAND_EQUILIBRIUM,
	}

	if side != SIDE_BUY and side != SIDE_SELL:
		out[KEY_ERROR] = ERR_SYS04_06
		_record_error(ERR_SYS04_06, FIELD_SIDE, side, "invalid side")
		return out

	# ERR-SYS04-06 — q ≤ 0 or buy qty > stock
	if qty <= 0:
		out[KEY_ERROR] = ERR_SYS04_06
		_record_error(ERR_SYS04_06, FIELD_QTY, qty, "qty<=0")
		return out

	var ctx: Dictionary = _resolve_context(port_id, good_id)
	if ctx.has(KEY_ERROR):
		out[KEY_ERROR] = ctx[KEY_ERROR]
		_fail_from_ctx(ctx)
		return out

	var anchor: int = int(ctx[FIELD_ANCHOR])
	var stock: int = int(ctx["stock"])
	var c_i: int = int(ctx["weekly_consumption"])

	if side == SIDE_BUY and qty > stock:
		out[KEY_ERROR] = ERR_SYS04_06
		_record_error(ERR_SYS04_06, FIELD_QTY, qty, "buy qty>%s stock" % stock)
		return out

	var stock_after: int = stock - qty if side == SIDE_BUY else stock + qty
	var area: float = _batch_area(anchor, c_i, stock, stock_after)
	var half: float = Params.get_float(PRM_HALF_SPREAD)
	var total: int = 0
	if side == SIDE_BUY:
		# FRM-SYS04-05 + D-01: CEIL(quantize(Area × (1 + HALF_SPREAD)))
		total = ceili(AmountQuantize.quantize_amount(area * (EQ_MULT + half)))
	else:
		# FRM-SYS04-05 + D-01: FLOOR(quantize(Area × (1 − HALF_SPREAD)))
		total = floori(AmountQuantize.quantize_amount(area * (EQ_MULT - half)))

	var mid_after: float = float(anchor) * _multiplier_for_stock(stock_after, c_i)
	var ratio: float = mid_after / float(anchor) if anchor > 0 else 0.0
	out[KEY_TOTAL_LI] = total
	out[KEY_AVG_LI] = float(total) / float(qty)
	out[KEY_MID_AFTER] = mid_after
	out[KEY_BAND_AFTER] = indicator_band(ratio)
	return out


func indicator_band(ratio: float) -> int:
	# FRM-SYS04-10／xlsx B457: r≥HI2 過高；r>HI1 偏高；r≥LO1 均衡；r>LO2 偏低；else 過低.
	assert(_loaded or Params.is_loaded(), "MarketPricer.indicator_band without Params")
	var hi2: float = Params.get_float(PRM_IND_HI2)
	var hi1: float = Params.get_float(PRM_IND_HI1)
	var lo1: float = Params.get_float(PRM_IND_LO1)
	var lo2: float = Params.get_float(PRM_IND_LO2)
	if ratio >= hi2:
		return BAND_VERY_HIGH
	if ratio > hi1:
		return BAND_HIGH
	if ratio >= lo1:
		return BAND_EQUILIBRIUM
	if ratio > lo2:
		return BAND_LOW
	return BAND_VERY_LOW


func multiplier_at_weeks(w: float) -> float:
	## Test／內部輔助：FRM-SYS04-02 m(w). Not in H; used by TST-SYS04-02／03 via mid_price path preferred.
	assert(_loaded, "MarketPricer.multiplier_at_weeks before load")
	return _m_of_w(w)


func _resolve_context(port_id: StringName, good_id: StringName) -> Dictionary:
	var port_s: String = String(port_id)
	var good_s: String = String(good_id)

	if not GoodCatalog.is_loaded():
		return {KEY_ERROR: ERR_SYS04_07, "field": "good_id", "value": good_s, "message": "GoodCatalog not loaded"}
	var good_found := false
	for id_variant in GoodCatalog.all_ids():
		if String(id_variant) == good_s:
			good_found = true
			break
	if not good_found:
		return {KEY_ERROR: ERR_SYS04_07, "field": "good_id", "value": good_s, "message": "unknown good_id"}

	var good: GoodDef = GoodCatalog.get_good(good_s)
	var anchor: int = good.base_price_li

	# D-08h: PRODUCER／TERMINAL = GoodDef.base_price_li；TRANSIT via TransitAnchorProvider.
	if PortRegistry.is_loaded():
		var port_found := false
		for pid_variant in PortRegistry.all_ids():
			if String(pid_variant) == port_s:
				port_found = true
				break
		if port_found:
			var port: PortDef = PortRegistry.get_port(port_s)
			if port.role_cells.has(good_s):
				var cell: RoleCell = port.role_cells[good_s]
				if cell.role == PortRegistry.ROLE_TRANSIT:
					var transit_anchor: int = _transit_anchor_price(port_id, good_id)
					if transit_anchor <= TransitAnchorProvider.ANCHOR_FAILURE:
						return {
							KEY_ERROR: ERR_SYS04_07,
							"field": FIELD_ANCHOR,
							"value": good_s,
							"message": "TRANSIT anchor missing (TransitAnchorProvider unset or failed)",
						}
					anchor = transit_anchor

	if _consumption == null:
		return {
			KEY_ERROR: CODE_CONSUMPTION,
			"field": FIELD_CONSUMPTION,
			"value": null,
			"message": "ConsumptionProvider not set",
		}

	var c_i: int = _consumption.weekly_consumption(port_id, good_id)
	if c_i < 0:
		return {
			KEY_ERROR: CODE_CONSUMPTION,
			"field": FIELD_CONSUMPTION,
			"value": c_i,
			"message": "weekly_consumption failure",
		}

	if not GoodsLedger.is_loaded():
		return {
			KEY_ERROR: CODE_GOODS_LEDGER,
			"field": FIELD_GOODS_LEDGER,
			"value": null,
			"message": "GoodsLedger not loaded",
		}

	var market: Dictionary = GoodsLedger.make_market(port_s)
	var stock: int = GoodsLedger.get_qty(market, good_id)
	return {
		FIELD_ANCHOR: anchor,
		"stock": stock,
		"weekly_consumption": c_i,
	}


func _multiplier_for_stock(stock: int, weekly_consumption_i: int) -> float:
	# FRM-SYS04-01／09: w = stock ÷ C；C=0 → m = M_n
	if weekly_consumption_i == 0:
		return _floor_mult()
	# B2: cast int → float only when computing w
	var w: float = float(stock) / float(weekly_consumption_i)
	return _m_of_w(w)


func _m_of_w(w: float) -> float:
	# FRM-SYS04-02: linear interpolation on breakpoints; w ≥ W_n → M_n
	var n: int = _curve.point_count()
	var last_i: int = n - 1
	if w >= _curve.weeks[last_i]:
		return _curve.mults[last_i]
	var i: int = 0
	while i < last_i:
		var w_i: float = _curve.weeks[i]
		var w_j: float = _curve.weeks[i + 1]
		if w_i <= w and w < w_j:
			var m_i: float = _curve.mults[i]
			var m_j: float = _curve.mults[i + 1]
			return m_i + (m_j - m_i) * (w - w_i) / (w_j - w_i)
		i = i + 1
	return _curve.mults[0]


func _floor_mult() -> float:
	var last_i: int = _curve.point_count() - 1
	return _curve.mults[last_i]


func _batch_area(anchor: int, weekly_consumption_i: int, stock_before: int, stock_after: int) -> float:
	# FRM-SYS04-04／09: Area = |anchor × C × (G(w_after) − G(w_before))|；C=0 → anchor × M_n × q
	var q: int = stock_after - stock_before
	if q < 0:
		q = 0 - q
	if weekly_consumption_i == 0:
		# FRM-SYS04-09
		return float(anchor) * _floor_mult() * float(q)
	var c_f: float = float(weekly_consumption_i)
	var w_before: float = float(stock_before) / c_f
	var w_after: float = float(stock_after) / c_f
	var delta_g: float = _G(w_after) - _G(w_before)
	if delta_g < 0.0:
		delta_g = 0.0 - delta_g
	return float(anchor) * c_f * delta_g


func _G(x: float) -> float:
	# FRM-SYS04-04: G(x) = ∫₀ˣ m(w) dw — piecewise trapezoid; beyond W_n = (x − W_n) × M_n
	# Matches 03_Systems xlsx B460 array formula.
	if x <= 0.0:
		return 0.0
	var n: int = _curve.point_count()
	var last_i: int = n - 1
	var total: float = 0.0
	var i: int = 0
	while i < last_i:
		var w_a: float = _curve.weeks[i]
		var w_b: float = _curve.weeks[i + 1]
		var m_a: float = _curve.mults[i]
		var m_b: float = _curve.mults[i + 1]
		# Clamp integration end into [w_a, w_b]
		var e: float = x
		if e < w_a:
			e = w_a
		if e > w_b:
			e = w_b
		var m_e: float = m_a + (m_b - m_a) * (e - w_a) / (w_b - w_a)
		total = total + (e - w_a) * (m_a + m_e) / (1.0 + 1.0)
		i = i + 1
	var w_n: float = _curve.weeks[last_i]
	if x > w_n:
		total = total + (x - w_n) * _curve.mults[last_i]
	return total


func _validate_curve(curve: PriceCurve, curve_path: String) -> Array:
	# FRM-SYS04-07 → ERR-SYS04-01..04
	var errors: Array = []
	var n: int = curve.point_count()
	if curve.weeks.size() != curve.mults.size():
		errors.append(_err(ERR_SYS04_02, curve_path, FIELD_CURVE, null, "weeks/mults length mismatch"))
		return errors
	if n < MIN_BREAKPOINTS:
		errors.append(_err(ERR_SYS04_02, curve_path, FIELD_CURVE, n, "breakpoint count below FRM-SYS04-07 minimum"))
		return errors

	# ERR-SYS04-01 — first weeks ≠ 0
	if curve.weeks[0] != 0.0:
		errors.append(_err(ERR_SYS04_01, curve_path, FIELD_WEEKS, curve.weeks[0], "W_1 must be 0"))

	# ERR-SYS04-02 — weeks not strictly increasing
	var i: int = 0
	while i < n - 1:
		if not (curve.weeks[i + 1] > curve.weeks[i]):
			errors.append(_err(ERR_SYS04_02, curve_path, FIELD_WEEKS, curve.weeks[i + 1], "weeks not strictly increasing"))
			break
		i = i + 1

	# ERR-SYS04-03 — mult increasing; ERR-SYS04-04 — mult ≤ 0
	i = 0
	while i < n:
		if curve.mults[i] <= 0.0:
			errors.append(_err(ERR_SYS04_04, curve_path, FIELD_MULTS, curve.mults[i], "mult <= 0"))
		if i < n - 1 and curve.mults[i + 1] > curve.mults[i]:
			errors.append(_err(ERR_SYS04_03, curve_path, FIELD_MULTS, curve.mults[i + 1], "mult increasing"))
		i = i + 1
	return errors


func _validate_indicator_order() -> Array:
	# FRM-SYS04-10: IND_LO2 < IND_LO1 ≤ 1 ≤ IND_HI1 < IND_HI2 → else ERR-SYS04-08
	var errors: Array = []
	var hi2: float = Params.get_float(PRM_IND_HI2)
	var hi1: float = Params.get_float(PRM_IND_HI1)
	var lo1: float = Params.get_float(PRM_IND_LO1)
	var lo2: float = Params.get_float(PRM_IND_LO2)
	var ok: bool = (lo2 < lo1) and (lo1 <= EQ_MULT) and (EQ_MULT <= hi1) and (hi1 < hi2)
	if not ok:
		errors.append(_err(ERR_SYS04_08, "res://data/params/params.json", FIELD_IND, {
			"LO2": lo2, "LO1": lo1, "HI1": hi1, "HI2": hi2
		}, "indicator cut points out of order"))
	return errors


func _validate_floor_anchors() -> Array:
	# FRM-SYS04-08 + D-01: FLOOR(quantize(anchor × M_n × (1 − HALF_SPREAD))) ≥ MIN_CASH_UNIT
	var errors: Array = []
	if not GoodCatalog.is_loaded():
		# Boot without catalog: skip goods scan (SimLoop order loads catalog first).
		return errors
	var half: float = Params.get_float(PRM_HALF_SPREAD)
	var m_n: float = _floor_mult()
	var min_li: int = Params.get_int(PRM_MIN_CASH_UNIT)
	for id_variant in GoodCatalog.all_ids():
		var gid: StringName = StringName(String(id_variant))
		var def: GoodDef = GoodCatalog.get_good(gid)
		var raw: float = float(def.base_price_li) * m_n * (EQ_MULT - half)
		var floor_sell: int = floori(AmountQuantize.quantize_amount(raw))
		if floor_sell < min_li:
			errors.append(_err(ERR_SYS04_05, "res://data/goods/", FIELD_ANCHOR, def.base_price_li, "floor sell < 1 li"))
	return errors


func _transit_anchor_price(port_id: StringName, good_id: StringName) -> int:
	# D-08h: Phase 0 no provider → failure；provider fail (≤0) → failure. Never invent freight／ratios.
	if _transit_anchor == null:
		return TransitAnchorProvider.ANCHOR_FAILURE
	return _transit_anchor.anchor_price_li(port_id, good_id)


func _clear_state() -> void:
	_curve = null
	_consumption = null
	_transit_anchor = null
	_loaded = false
	_clear_last_error()


func _clear_last_error() -> void:
	_last_error = {}


func _fail_from_ctx(ctx: Dictionary) -> void:
	var code: StringName = StringName(ctx[KEY_ERROR])
	var field: String = String(ctx.get("field", KEY_ERROR))
	var value: Variant = ctx.get("value", null)
	var message: String = String(ctx.get("message", str(code)))
	_record_error(code, field, value, message)


func _record_error(code: StringName, field: String, value: Variant, message: String) -> void:
	var info: Dictionary = _err(code, SCRIPT_PATH, field, value, message)
	_last_error = info
	push_error("MarketPricer: %s" % str(info))


func _err(code: StringName, file_path: String, field: String, value: Variant, message: String) -> Dictionary:
	# D-04 ErrorInfo = {code, sys, detail}; C-06 file/field/value live in detail.
	return ErrorInfoUtil.make_validation(code, SYS_ID, file_path, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("MarketPricer: %s" % str(e))
