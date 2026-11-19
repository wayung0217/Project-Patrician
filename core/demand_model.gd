extends Node
## Autoload DemandModel — SYS-06 resident consumption (TechSpec §16 / D-09a／D-09b).
## Formal ConsumptionProvider + SatisfactionInputProvider. Residents only (not SYS-08 inputs).
## _ready() field init only; load_and_validate() from SimLoop.boot (2.2-01).
## Data: exported tables (16-04); tests use res://tests/fixtures/demand/ only. No weekly_consumption.

const SYS_ID := &"SYS-06"
const SCRIPT_PATH := "res://core/demand_model.gd"
const TABLES_PATH := "res://data/demand/demand_tables.json"

const CLASS_POOR := &"POOR"
const CLASS_CITIZEN := &"CITIZEN"
const CLASS_RICH := &"RICH"
const CLASS_BEGGAR := &"BEGGAR"

const ERR_SYS06_01 := &"ERR-SYS06-01"
const ERR_SYS06_02 := &"ERR-SYS06-02"
const ERR_SYS06_03 := &"ERR-SYS06-03"
const ERR_SYS06_04 := &"ERR-SYS06-04"

const PRM_DAYS_PER_WEEK := "PRM-SYS04-DAYS_PER_WEEK"

## Fixed-point scales (C-09 integer math).
const RATE_CJ_PER_JIN := 100 ## rate_cj = jin/person/week × 100
const JIN_PER_DAN := 100 ## 擔
const RATE_TO_DAN := RATE_CJ_PER_JIN * JIN_PER_DAN ## 10000 centi-jin → 1 擔
const WEIGHT_PPT_SUM := 1000 ## sat weights sum to 1000 ppt (= 100%)
const PPM_SCALE := 1000000
const FULFIL_SCALE := 1000000

signal demand_unmet(port_id: StringName, good_id: StringName, shortfall: int)

var _loaded: bool = false
var _tables_path: String = TABLES_PATH
var _rate_cj: Dictionary = {} ## class → {good_id: int centi-jin}
var _sat_ppt: Dictionary = {} ## class → {good_id: int ppt}
var _subst: Array = [] ## [{from,to,cap_ppm,util_ppm}, ...] sorted by from,to
var _beggar_goods: Array = [] ## good_id strings (necessities)
var _days_per_week: int = 7

## Last planned day consumes / fulfil (updated in consume_qty planning).
var _plan_day: int = -1
var _consume_plan: Dictionary = {} ## "port|good" → int
var _subst_applied: Dictionary = {} ## "port|good" → int (extra B taken as subst)
var _fulfil_ppm: Dictionary = {} ## "port|good" → int 0..FULFIL_SCALE
var _last_error: Dictionary = {}

var _cons_adapter: _ConsAdapter = null
var _sat_adapter: _SatAdapter = null


func _ready() -> void:
	_clear_state()


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func get_consumption_provider() -> ConsumptionProvider:
	if _cons_adapter == null:
		_cons_adapter = _ConsAdapter.new(self)
	return _cons_adapter


func get_satisfaction_input_provider() -> SatisfactionInputProvider:
	if _sat_adapter == null:
		_sat_adapter = _SatAdapter.new(self)
	return _sat_adapter


func load_and_validate(tables_path: String = TABLES_PATH) -> Array:
	var errors: Array = []
	_clear_state()
	_tables_path = tables_path
	if not Params.is_loaded():
		errors.append(_err(ERR_SYS06_01, "Params", null, "Params must load first"))
		_emit(errors)
		return errors
	_days_per_week = Params.get_int(PRM_DAYS_PER_WEEK)
	if _days_per_week <= 0:
		errors.append(_err(ERR_SYS06_01, PRM_DAYS_PER_WEEK, _days_per_week, "DAYS_PER_WEEK must be > 0"))
	errors.append_array(_load_tables(tables_path))
	errors.append_array(_validate_population_nonneg())
	if errors.is_empty():
		_loaded = true
	else:
		_loaded = false
		_emit(errors)
	return errors


func weekly_demand(port_id: StringName, good_id: StringName) -> int:
	assert(_loaded, "DemandModel.weekly_demand before load")
	return _citizen_week(String(port_id), String(good_id))


func daily_demand(port_id: StringName, good_id: StringName, day: int) -> int:
	assert(_loaded, "DemandModel.daily_demand before load")
	var w: int = _citizen_week(String(port_id), String(good_id))
	return _daily_share(w, day)


func substitution_applied(port_id: StringName, good_id: StringName) -> int:
	assert(_loaded, "DemandModel.substitution_applied before load")
	return int(_subst_applied.get("%s|%s" % [String(port_id), String(good_id)], 0))


func fulfilment(port_id: StringName, good_id: StringName) -> float:
	assert(_loaded, "DemandModel.fulfilment before load")
	var key := "%s|%s" % [String(port_id), String(good_id)]
	if not _fulfil_ppm.has(key):
		return 1.0
	return float(_fulfil_ppm[key]) / float(FULFIL_SCALE)


func satisfaction_input(port_id: StringName, clazz: StringName) -> float:
	assert(_loaded, "DemandModel.satisfaction_input before load")
	var port_s := String(port_id)
	var cls := _norm_class(clazz)
	if cls == CLASS_BEGGAR:
		return _sat_beggar(port_s)
	if cls != CLASS_POOR and cls != CLASS_CITIZEN and cls != CLASS_RICH:
		_record(ERR_SYS06_04, "class", clazz, "unknown class for sat input")
		return 0.0
	var weights: Dictionary = _sat_ppt.get(String(cls), {})
	var acc: int = 0
	var keys: Array = weights.keys()
	keys.sort()
	for g_variant in keys:
		var g: String = String(g_variant)
		var w_ppt: int = int(weights[g])
		if w_ppt <= 0:
			continue
		var f_ppm: int = int(_fulfil_ppm.get("%s|%s" % [port_s, g], FULFIL_SCALE))
		acc = acc + w_ppt * f_ppm
	# sat = Σ (w_ppt/1000) * (f_ppm/SCALE) → acc / (1000 * SCALE)
	return float(acc) / float(WEIGHT_PPT_SUM * FULFIL_SCALE)


func consume_qty(port_id: StringName, good_id: StringName, day: int) -> int:
	assert(_loaded, "DemandModel.consume_qty before load")
	_ensure_day_plan(day)
	var key := "%s|%s" % [String(port_id), String(good_id)]
	return int(_consume_plan.get(key, 0))


func _clear_state() -> void:
	_loaded = false
	_tables_path = TABLES_PATH
	_rate_cj = {}
	_sat_ppt = {}
	_subst = []
	_beggar_goods = []
	_days_per_week = 7
	_plan_day = -1
	_consume_plan = {}
	_subst_applied = {}
	_fulfil_ppm = {}
	_last_error = {}


func _load_tables(path: String) -> Array:
	var errors: Array = []
	if not FileAccess.file_exists(path):
		errors.append(_err(ERR_SYS06_01, path, null, "demand tables file missing (16-04)"))
		return errors
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append(_err(ERR_SYS06_01, path, null, "demand tables root must be Dictionary"))
		return errors
	var root: Dictionary = parsed
	errors.append_array(_parse_rates(root.get("rate_cj", null), path))
	errors.append_array(_parse_weights(root.get("sat_weight_ppt", null), path))
	errors.append_array(_parse_subst(root.get("subst", null), path))
	var beg: Variant = root.get("beggar_necessities", [])
	if typeof(beg) != TYPE_ARRAY:
		errors.append(_err(ERR_SYS06_01, "beggar_necessities", beg, "must be Array of good_id"))
	else:
		_beggar_goods = []
		for g in beg:
			_beggar_goods.append(String(g))
		_beggar_goods.sort()
	return errors


func _parse_rates(raw: Variant, path: String) -> Array:
	var errors: Array = []
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append(_err(ERR_SYS06_01, "rate_cj", raw, "rate_cj must be Dictionary"))
		return errors
	var root: Dictionary = raw
	for cls in [String(CLASS_POOR), String(CLASS_CITIZEN), String(CLASS_RICH)]:
		if not root.has(cls):
			errors.append(_err(ERR_SYS06_01, "rate_cj.%s" % cls, null, "missing class rates"))
			continue
		var block_v: Variant = root[cls]
		if typeof(block_v) != TYPE_DICTIONARY:
			errors.append(_err(ERR_SYS06_01, "rate_cj.%s" % cls, block_v, "class rates must be Dictionary"))
			continue
		var block: Dictionary = block_v
		var out: Dictionary = {}
		var keys: Array = block.keys()
		keys.sort()
		for g_variant in keys:
			var g: String = String(g_variant)
			var v: Variant = block[g]
			if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
				errors.append(_err(ERR_SYS06_01, "rate_cj.%s.%s" % [cls, g], v, "rate must be int"))
				continue
			var n: int = int(v)
			if n < 0:
				errors.append(_err(ERR_SYS06_01, "rate_cj.%s.%s" % [cls, g], n, "consumption rate negative"))
				continue
			out[g] = n
		_rate_cj[cls] = out
	return errors


func _parse_weights(raw: Variant, path: String) -> Array:
	var errors: Array = []
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append(_err(ERR_SYS06_02, "sat_weight_ppt", raw, "sat_weight_ppt must be Dictionary"))
		return errors
	var root: Dictionary = raw
	for cls in [String(CLASS_POOR), String(CLASS_CITIZEN), String(CLASS_RICH)]:
		if not root.has(cls):
			errors.append(_err(ERR_SYS06_02, "sat_weight_ppt.%s" % cls, null, "missing class weights"))
			continue
		var block_v: Variant = root[cls]
		if typeof(block_v) != TYPE_DICTIONARY:
			errors.append(_err(ERR_SYS06_02, "sat_weight_ppt.%s" % cls, block_v, "weights must be Dictionary"))
			continue
		var block: Dictionary = block_v
		var out: Dictionary = {}
		var sum_ppt: int = 0
		var keys: Array = block.keys()
		keys.sort()
		for g_variant in keys:
			var g: String = String(g_variant)
			var v: Variant = block[g]
			if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
				errors.append(_err(ERR_SYS06_02, "sat_weight_ppt.%s.%s" % [cls, g], v, "weight must be int ppt"))
				continue
			var n: int = int(v)
			if n < 0:
				errors.append(_err(ERR_SYS06_02, "sat_weight_ppt.%s.%s" % [cls, g], n, "weight negative"))
				continue
			out[g] = n
			sum_ppt = sum_ppt + n
		if sum_ppt != WEIGHT_PPT_SUM:
			errors.append(
				_err(
					ERR_SYS06_02,
					"sat_weight_ppt.%s" % cls,
					sum_ppt,
					"class sat weights must sum to 1000 ppt (100%%)"
				)
			)
		_sat_ppt[cls] = out
	return errors


func _parse_subst(raw: Variant, path: String) -> Array:
	var errors: Array = []
	if raw == null:
		_subst = []
		return errors
	if typeof(raw) != TYPE_ARRAY:
		errors.append(_err(ERR_SYS06_03, "subst", raw, "subst must be Array"))
		return errors
	var out: Array = []
	for row_v in raw:
		if typeof(row_v) != TYPE_DICTIONARY:
			errors.append(_err(ERR_SYS06_03, "subst", row_v, "subst row must be Dictionary"))
			continue
		var row: Dictionary = row_v
		var fr: String = String(row.get("from", ""))
		var to: String = String(row.get("to", ""))
		var cap: int = int(row.get("cap_ppm", -1))
		var util: int = int(row.get("util_ppm", -1))
		if fr.is_empty() or to.is_empty():
			errors.append(_err(ERR_SYS06_03, "subst", row, "subst from/to required"))
			continue
		# Cap in (0, PPM_SCALE]; util in (0, PPM_SCALE]
		if cap <= 0 or cap > PPM_SCALE:
			errors.append(_err(ERR_SYS06_03, "subst.cap_ppm", cap, "substitution cap out of bounds"))
			continue
		if util <= 0 or util > PPM_SCALE:
			errors.append(_err(ERR_SYS06_03, "subst.util_ppm", util, "substitution util out of bounds"))
			continue
		out.append({"from": fr, "to": to, "cap_ppm": cap, "util_ppm": util})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a["from"]) == String(b["from"]):
			return String(a["to"]) < String(b["to"])
		return String(a["from"]) < String(b["from"])
	)
	_subst = out
	return errors


func _validate_population_nonneg() -> Array:
	var errors: Array = []
	if not PopulationModel.is_loaded():
		return errors
	for pid_v in PortRegistry.all_ids() if PortRegistry.is_loaded() else []:
		var pid: String = String(pid_v)
		for cls in [CLASS_POOR, CLASS_CITIZEN, CLASS_RICH, CLASS_BEGGAR]:
			var n: int = PopulationModel.population(StringName(pid), cls)
			if n < 0:
				errors.append(
					_err(ERR_SYS06_04, "%s.%s" % [pid, String(cls)], n, "class population negative")
				)
	return errors


func _citizen_week(port_s: String, good_s: String) -> int:
	## FRM-SYS06-01: Σ pop×rate (斤) → 擔 via RATE_TO_DAN. Beggars: necessities only at poor rate.
	if _has_neg_pop(port_s):
		return 0
	var poor: int = PopulationModel.population(StringName(port_s), CLASS_POOR)
	var cit: int = PopulationModel.population(StringName(port_s), CLASS_CITIZEN)
	var rich: int = PopulationModel.population(StringName(port_s), CLASS_RICH)
	var beg: int = PopulationModel.population(StringName(port_s), CLASS_BEGGAR)
	var acc: int = 0
	acc = acc + poor * int(_rate_cj.get(String(CLASS_POOR), {}).get(good_s, 0))
	acc = acc + cit * int(_rate_cj.get(String(CLASS_CITIZEN), {}).get(good_s, 0))
	acc = acc + rich * int(_rate_cj.get(String(CLASS_RICH), {}).get(good_s, 0))
	if _beggar_goods.has(good_s):
		acc = acc + beg * int(_rate_cj.get(String(CLASS_POOR), {}).get(good_s, 0))
	return int(acc / RATE_TO_DAN)


func _has_neg_pop(port_s: String) -> bool:
	for cls in [CLASS_POOR, CLASS_CITIZEN, CLASS_RICH, CLASS_BEGGAR]:
		var n: int = PopulationModel.population(StringName(port_s), cls)
		if n < 0:
			_record(ERR_SYS06_04, "%s.%s" % [port_s, String(cls)], n, "class population negative")
			return true
	return false


func _daily_share(week_w: int, day: int) -> int:
	## FRM-SYS06-02: k = (day−1) mod 7 for day≥1; day≤0 → k=0.
	if week_w <= 0:
		return 0
	var dpw: int = _days_per_week
	if dpw <= 0:
		dpw = 7
	var k: int = 0
	if day >= 1:
		k = (day - 1) % dpw
	return int(week_w * (k + 1) / dpw) - int(week_w * k / dpw)


func _ensure_day_plan(day: int) -> void:
	if _plan_day == day and not _consume_plan.is_empty():
		return
	_plan_day = day
	_consume_plan = {}
	_subst_applied = {}
	_fulfil_ppm = {}
	if not PortRegistry.is_loaded() or not GoodCatalog.is_loaded():
		return
	var ports: Array = []
	for p in PortRegistry.all_ids():
		ports.append(String(p))
	ports.sort()
	var goods: Array = []
	for g in GoodCatalog.all_ids():
		goods.append(String(g))
	goods.sort()
	for port_s in ports:
		_plan_port_day(port_s, goods, day)


func _plan_port_day(port_s: String, goods: Array, day: int) -> void:
	var base: Dictionary = {}
	for g in goods:
		base[g] = _daily_share(_citizen_week(port_s, g), day)
	var stock: Dictionary = {}
	for g in goods:
		stock[g] = GoodsLedger.get_qty(GoodsLedger.make_market(port_s), StringName(g))
	var plan: Dictionary = {}
	for g in goods:
		plan[g] = 0
	var subst_extra: Dictionary = {}
	for g in goods:
		subst_extra[g] = 0
	var fulfil: Dictionary = {}

	for g_a in goods:
		var need: int = int(base[g_a])
		var take: int = need
		if take > int(stock[g_a]):
			take = int(stock[g_a])
		plan[g_a] = int(plan[g_a]) + take
		stock[g_a] = int(stock[g_a]) - take
		var utility: int = take ## 擔 utility toward A at 1:1 for own stock
		var shortfall: int = need - take
		if shortfall > 0 and need > 0:
			var max_u: int = int(need * _max_cap_ppm(g_a) / PPM_SCALE)
			var want_u: int = shortfall
			if want_u > max_u:
				want_u = max_u
			for row_v in _subst_for(g_a):
				if want_u <= 0:
					break
				var row: Dictionary = row_v
				var g_b: String = String(row["to"])
				var util_ppm: int = int(row["util_ppm"])
				if util_ppm <= 0:
					continue
				# B_qty such that B * util_ppm / SCALE ≈ want_u → ceil
				var b_need: int = int((want_u * PPM_SCALE + util_ppm - 1) / util_ppm)
				var b_take: int = b_need
				if b_take > int(stock.get(g_b, 0)):
					b_take = int(stock.get(g_b, 0))
				if b_take <= 0:
					continue
				plan[g_b] = int(plan.get(g_b, 0)) + b_take
				subst_extra[g_b] = int(subst_extra.get(g_b, 0)) + b_take
				stock[g_b] = int(stock.get(g_b, 0)) - b_take
				var gained: int = int(b_take * util_ppm / PPM_SCALE)
				utility = utility + gained
				want_u = want_u - gained
		if need <= 0:
			fulfil[g_a] = FULFIL_SCALE
		else:
			var f: int = int(utility * FULFIL_SCALE / need)
			if f > FULFIL_SCALE:
				f = FULFIL_SCALE
			fulfil[g_a] = f
			if f < FULFIL_SCALE:
				demand_unmet.emit(StringName(port_s), StringName(g_a), need - utility)

	for g in goods:
		var key := "%s|%s" % [port_s, g]
		_consume_plan[key] = int(plan[g])
		_subst_applied[key] = int(subst_extra[g])
		_fulfil_ppm[key] = int(fulfil.get(g, FULFIL_SCALE))


func _max_cap_ppm(good_s: String) -> int:
	## Shared cap across all substitute rows for A (max of listed caps).
	var m: int = 0
	for row_v in _subst_for(good_s):
		var c: int = int((row_v as Dictionary)["cap_ppm"])
		if c > m:
			m = c
	return m


func _subst_for(good_s: String) -> Array:
	var out: Array = []
	for row_v in _subst:
		var row: Dictionary = row_v
		if String(row["from"]) == good_s:
			out.append(row)
	return out


func _sat_beggar(port_s: String) -> float:
	## U-15: only poor necessities; renormalize those poor weights to 100%.
	var poor_w: Dictionary = _sat_ppt.get(String(CLASS_POOR), {})
	var sum_ppt: int = 0
	for g in _beggar_goods:
		sum_ppt = sum_ppt + int(poor_w.get(g, 0))
	if sum_ppt <= 0:
		return 0.0
	var acc: int = 0
	for g in _beggar_goods:
		var w_ppt: int = int(poor_w.get(g, 0))
		if w_ppt <= 0:
			continue
		var f_ppm: int = int(_fulfil_ppm.get("%s|%s" % [port_s, g], FULFIL_SCALE))
		acc = acc + w_ppt * f_ppm
	return float(acc) / float(sum_ppt * FULFIL_SCALE)


func _norm_class(clazz: StringName) -> StringName:
	var s := String(clazz).to_upper()
	if s == "POOR":
		return CLASS_POOR
	if s == "CITIZEN":
		return CLASS_CITIZEN
	if s == "RICH":
		return CLASS_RICH
	if s == "BEGGAR":
		return CLASS_BEGGAR
	return clazz


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _record(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = _err(code, field, value, message)
	push_error("DemandModel: %s" % str(_last_error))


func _emit(errors: Array) -> void:
	for e in errors:
		push_error("DemandModel: %s" % str(e))


class _ConsAdapter extends ConsumptionProvider:
	var _host: Node

	func _init(host: Node) -> void:
		_host = host

	func consume_qty(port_id: StringName, good_id: StringName, day: int) -> int:
		return _host.consume_qty(port_id, good_id, day)


class _SatAdapter extends SatisfactionInputProvider:
	var _host: Node

	func _init(host: Node) -> void:
		_host = host

	func satisfaction_input(port_id: StringName, clazz: StringName) -> float:
		return _host.satisfaction_input(port_id, clazz)
