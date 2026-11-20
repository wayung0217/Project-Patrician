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
const ERR_SYS06_06 := &"ERR-SYS06-06"

const PRM_DAYS_PER_WEEK := "PRM-SYS04-DAYS_PER_WEEK"
const PRM_JIN_PER_DAN := "PRM-SYS06-JIN_PER_DAN"
const PRM_RATE_SCALE := "PRM-SYS06-RATE_SCALE"
const PRM_PPM_SCALE := "PRM-SYS06-PPM_SCALE"
const PRM_WEIGHT_SUM := "PRM-SYS06-WEIGHT_SUM"

signal demand_unmet(port_id: StringName, good_id: StringName, shortfall: int)

var _loaded: bool = false
var _tables_path: String = TABLES_PATH
var _rate_cj: Dictionary = {} ## class → {good_id: int rate_scaled}
var _sat_ppt: Dictionary = {} ## class → {good_id: int weight units}
var _subst: Array = [] ## [{from,to,cap_ppm,util_ppm}, ...] sorted by from,to
var _beggar_goods: Array = [] ## good_id strings (necessities)

## PRM-backed scales (C-03／N-01); set only from Params in load_and_validate.
var _days_per_week: int = 0
var _jin_per_dan: int = 0
var _rate_scale: int = 0
var _ppm_scale: int = 0
var _weight_sum: int = 0
## FRM-SYS06-10: S = RATE_SCALE × JIN_PER_DAN; D = S × DAYS_PER_WEEK
var _period_S: int = 0
var _period_D: int = 0

## Remainder accumulators (port|good → int); DemandModel-owned only (FRM-SYS06-10).
var _acc: Dictionary = {}
var _last_advanced_day: int = 0
var _day_base: Dictionary = {} ## port|good → q dan for last advanced day

var _has_plan: bool = false
var _plan_day: int = 0
var _consume_plan: Dictionary = {} ## "port|good" → int
var _subst_applied: Dictionary = {} ## "port|good" → int (extra B taken as subst)
var _fulfil_ppm: Dictionary = {} ## "port|good" → int 0..ppm_scale
var _pending_unmet: Array = [] ## [{port, good, shortfall}, ...] accumulated for flush_signals
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
	errors.append_array(_load_required_prms())
	if not errors.is_empty():
		_loaded = false
		_emit(errors)
		return errors
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
	## FRM-SYS06-10 display: floori(W_num / S)
	var w_num: int = _w_num(String(port_id), String(good_id))
	return floori(float(w_num) / float(_period_S))


func daily_demand(port_id: StringName, good_id: StringName, day: int) -> int:
	assert(_loaded, "DemandModel.daily_demand before load")
	_ensure_day_plan(day)
	return _to_int(_day_base.get("%s|%s" % [String(port_id), String(good_id)], 0))


func substitution_applied(port_id: StringName, good_id: StringName) -> int:
	assert(_loaded, "DemandModel.substitution_applied before load")
	return _to_int(_subst_applied.get("%s|%s" % [String(port_id), String(good_id)], 0))


func fulfilment(port_id: StringName, good_id: StringName) -> float:
	assert(_loaded, "DemandModel.fulfilment before load")
	## FRM-SYS06-08: fulfil = utility / need in [0, 1]
	var key := "%s|%s" % [String(port_id), String(good_id)]
	if not _fulfil_ppm.has(key):
		return 1.0
	return float(_fulfil_ppm[key]) / float(_ppm_scale)


func satisfaction_input(port_id: StringName, clazz: StringName) -> float:
	assert(_loaded, "DemandModel.satisfaction_input before load")
	## FRM-SYS06-09: class sat = Σ (w/WEIGHT_SUM) × fulfil
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
		var w_ppt: int = _to_int(weights[g])
		if w_ppt <= 0:
			continue
		var f_ppm: int = _to_int(_fulfil_ppm.get("%s|%s" % [port_s, g], _ppm_scale))
		acc = acc + w_ppt * f_ppm
	return float(acc) / float(_weight_sum * _ppm_scale)


func consume_qty(port_id: StringName, good_id: StringName, day: int) -> int:
	assert(_loaded, "DemandModel.consume_qty before load")
	_ensure_day_plan(day)
	var key := "%s|%s" % [String(port_id), String(good_id)]
	return _to_int(_consume_plan.get(key, 0))


func flush_signals() -> void:
	## D-05: emit demand_unmet only after SimLoop step-6 call; once each, sorted.
	_pending_unmet.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a["port"]) == String(b["port"]):
			return String(a["good"]) < String(b["good"])
		return String(a["port"]) < String(b["port"])
	)
	for row_v in _pending_unmet:
		var row: Dictionary = row_v
		demand_unmet.emit(StringName(String(row["port"])), StringName(String(row["good"])), _to_int(row["shortfall"]))
	_pending_unmet.clear()


func _clear_state() -> void:
	_loaded = false
	_tables_path = TABLES_PATH
	_rate_cj = {}
	_sat_ppt = {}
	_subst = []
	_beggar_goods = []
	_days_per_week = 0
	_jin_per_dan = 0
	_rate_scale = 0
	_ppm_scale = 0
	_weight_sum = 0
	_period_S = 0
	_period_D = 0
	_acc = {}
	_last_advanced_day = 0
	_day_base = {}
	_has_plan = false
	_plan_day = 0
	_consume_plan = {}
	_subst_applied = {}
	_fulfil_ppm = {}
	_pending_unmet = []
	_last_error = {}


func _load_required_prms() -> Array:
	## ERR-SYS06-06: missing PRM-SYS04-DAYS_PER_WEEK or any PRM-SYS06-* → refuse; no defaults.
	var errors: Array = []
	if not Params.is_loaded():
		errors.append(_err(ERR_SYS06_06, "Params", null, "Params must load first (required PRMs)"))
		# Still list each required key for C-06 collect-all.
		for key in _required_prm_ids():
			errors.append(_err(ERR_SYS06_06, key, null, "required PRM missing"))
		return errors
	for key in _required_prm_ids():
		## PRM ID at each param read (C-12)
		if not Params.has_prm(key):
			errors.append(_err(ERR_SYS06_06, key, null, "required PRM missing"))
			continue
	if not errors.is_empty():
		return errors
	_days_per_week = Params.get_int(PRM_DAYS_PER_WEEK) ## PRM-SYS04-DAYS_PER_WEEK
	_jin_per_dan = Params.get_int(PRM_JIN_PER_DAN) ## PRM-SYS06-JIN_PER_DAN
	_rate_scale = Params.get_int(PRM_RATE_SCALE) ## PRM-SYS06-RATE_SCALE
	_ppm_scale = Params.get_int(PRM_PPM_SCALE) ## PRM-SYS06-PPM_SCALE
	_weight_sum = Params.get_int(PRM_WEIGHT_SUM) ## PRM-SYS06-WEIGHT_SUM
	if _days_per_week <= 0:
		errors.append(_err(ERR_SYS06_06, PRM_DAYS_PER_WEEK, _days_per_week, "DAYS_PER_WEEK must be > 0"))
	if _jin_per_dan <= 0:
		errors.append(_err(ERR_SYS06_06, PRM_JIN_PER_DAN, _jin_per_dan, "JIN_PER_DAN must be > 0"))
	if _rate_scale <= 0:
		errors.append(_err(ERR_SYS06_06, PRM_RATE_SCALE, _rate_scale, "RATE_SCALE must be > 0"))
	if _ppm_scale <= 0:
		errors.append(_err(ERR_SYS06_06, PRM_PPM_SCALE, _ppm_scale, "PPM_SCALE must be > 0"))
	if _weight_sum <= 0:
		errors.append(_err(ERR_SYS06_06, PRM_WEIGHT_SUM, _weight_sum, "WEIGHT_SUM must be > 0"))
	if errors.is_empty():
		## FRM-SYS06-10: S = RATE_SCALE × JIN_PER_DAN; D = S × DAYS_PER_WEEK
		_period_S = _rate_scale * _jin_per_dan
		_period_D = _period_S * _days_per_week
	return errors


func _required_prm_ids() -> Array:
	return [
		PRM_DAYS_PER_WEEK,
		PRM_JIN_PER_DAN,
		PRM_RATE_SCALE,
		PRM_PPM_SCALE,
		PRM_WEIGHT_SUM,
	]


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
	for cls in ["POOR", "CITIZEN", "RICH"]:
		if not root.has(cls):
			errors.append(_err(ERR_SYS06_01, "rate_cj.%s" % cls, null, "missing class rates"))
			continue
		var block_v: Variant = root[cls]
		if typeof(block_v) != TYPE_DICTIONARY:
			errors.append(_err(ERR_SYS06_01, "rate_cj.%s" % cls, block_v, "class rates must be Dictionary"))
			continue
		var block: Dictionary = block_v
		var out: Dictionary = {}
		var gkeys: Array = block.keys()
		gkeys.sort()
		for g_variant in gkeys:
			var g: String = String(g_variant)
			var v: Variant = block[g]
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
				errors.append(_err(ERR_SYS06_01, "rate_cj.%s.%s" % [cls, g], v, "rate must be int"))
				continue
			var n: int = _to_int(v)
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
	for cls in ["POOR", "CITIZEN", "RICH"]:
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
		var gkeys: Array = block.keys()
		gkeys.sort()
		for g_variant in gkeys:
			var g: String = String(g_variant)
			var v: Variant = block[g]
			if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
				errors.append(_err(ERR_SYS06_02, "sat_weight_ppt.%s.%s" % [cls, g], v, "weight must be int"))
				continue
			var n: int = _to_int(v)
			if n < 0:
				errors.append(_err(ERR_SYS06_02, "sat_weight_ppt.%s.%s" % [cls, g], n, "weight negative"))
				continue
			out[g] = n
			sum_ppt = sum_ppt + n
		if sum_ppt != _weight_sum:
			errors.append(
				_err(
					ERR_SYS06_02,
					"sat_weight_ppt.%s" % cls,
					sum_ppt,
					"class sat weights must sum to PRM-SYS06-WEIGHT_SUM"
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
		if not row.has("from") or not row.has("to") or not row.has("cap_ppm") or not row.has("util_ppm"):
			errors.append(_err(ERR_SYS06_03, "subst", row, "subst from/to/cap_ppm/util_ppm required"))
			continue
		var fr: String = String(row["from"])
		var to: String = String(row["to"])
		var cap: int = _to_int(row["cap_ppm"])
		var util: int = _to_int(row["util_ppm"])
		if fr.is_empty() or to.is_empty():
			errors.append(_err(ERR_SYS06_03, "subst", row, "subst from/to required"))
			continue
		# Cap／util in (0, PPM_SCALE]
		if cap <= 0 or cap > _ppm_scale:
			errors.append(_err(ERR_SYS06_03, "subst.cap_ppm", cap, "substitution cap out of bounds"))
			continue
		if util <= 0 or util > _ppm_scale:
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


func _w_num(port_s: String, good_s: String) -> int:
	## FRM-SYS06-01／10: W_num = Σ_class pop × rate_scaled (centi-jin units).
	if _has_neg_pop(port_s):
		return 0
	var poor: int = PopulationModel.population(StringName(port_s), CLASS_POOR)
	var cit: int = PopulationModel.population(StringName(port_s), CLASS_CITIZEN)
	var rich: int = PopulationModel.population(StringName(port_s), CLASS_RICH)
	var beg: int = PopulationModel.population(StringName(port_s), CLASS_BEGGAR)
	var acc: int = 0
	acc = acc + poor * _to_int(_rate_cj.get(String(CLASS_POOR), {}).get(good_s, 0))
	acc = acc + cit * _to_int(_rate_cj.get(String(CLASS_CITIZEN), {}).get(good_s, 0))
	acc = acc + rich * _to_int(_rate_cj.get(String(CLASS_RICH), {}).get(good_s, 0))
	if _beggar_goods.has(good_s):
		acc = acc + beg * _to_int(_rate_cj.get(String(CLASS_POOR), {}).get(good_s, 0))
	return acc


func _has_neg_pop(port_s: String) -> bool:
	for cls in [CLASS_POOR, CLASS_CITIZEN, CLASS_RICH, CLASS_BEGGAR]:
		var n: int = PopulationModel.population(StringName(port_s), cls)
		if n < 0:
			_record(ERR_SYS06_04, "%s.%s" % [port_s, String(cls)], n, "class population negative")
			return true
	return false


func _ensure_day_plan(day: int) -> void:
	if _has_plan and _plan_day == day:
		return
	if day <= 0:
		_has_plan = false
		_consume_plan = {}
		_subst_applied = {}
		_fulfil_ppm = {}
		_day_base = {}
		return
	if day < _last_advanced_day:
		_record(ERR_SYS06_01, "day", day, "DemandModel day must advance chronologically (FRM-SYS06-10)")
		return
	# Advance accumulators chronologically to `day` (FRM-SYS06-10); then build consume plan.
	while _last_advanced_day < day:
		_last_advanced_day = _last_advanced_day + 1
		_advance_accumulators_one_day()
	_plan_day = day
	_has_plan = true
	_build_consume_plan()


func _advance_accumulators_one_day() -> void:
	## FRM-SYS06-10: per (port_id, good_id) ascending — acc += W_num; q = floori(acc/D); acc -= q×D
	_day_base = {}
	if not PortRegistry.is_loaded() or not GoodCatalog.is_loaded():
		return
	if _period_D <= 0:
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
		for good_s in goods:
			var key := "%s|%s" % [port_s, good_s]
			var w_num: int = _w_num(port_s, good_s)
			var acc: int = _to_int(_acc.get(key, 0))
			acc = acc + w_num
			var q: int = floori(float(acc) / float(_period_D))
			acc = acc - q * _period_D
			_acc[key] = acc
			_day_base[key] = q


func _build_consume_plan() -> void:
	_consume_plan = {}
	_subst_applied = {}
	_fulfil_ppm = {}
	# Unmet for this plan day only (replace pending for current plan rebuild).
	_pending_unmet = []
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
		_plan_port_day(port_s, goods)


func _plan_port_day(port_s: String, goods: Array) -> void:
	var base: Dictionary = {}
	for g in goods:
		base[g] = _to_int(_day_base.get("%s|%s" % [port_s, g], 0))
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
		var need: int = _to_int(base[g_a])
		var take: int = need
		if take > _to_int(stock[g_a]):
			take = _to_int(stock[g_a])
		plan[g_a] = _to_int(plan[g_a]) + take
		stock[g_a] = _to_int(stock[g_a]) - take
		var utility: int = take ## 擔 utility toward A at 1:1 for own stock
		var shortfall: int = need - take
		if shortfall > 0 and need > 0:
			## FRM-SYS06-07: substitute B→A up to cap_ppm of need, util_ppm efficiency
			var max_u: int = floori(float(need * _max_cap_ppm(g_a)) / float(_ppm_scale))
			var want_u: int = shortfall
			if want_u > max_u:
				want_u = max_u
			for row_v in _subst_for(g_a):
				if want_u <= 0:
					break
				var row: Dictionary = row_v
				var g_b: String = String(row["to"])
				var util_ppm: int = _to_int(row["util_ppm"])
				if util_ppm <= 0:
					continue
				# B_qty such that B * util_ppm / SCALE ≥ want_u → ceili via floori + remainder bump
				var num: int = want_u * _ppm_scale
				var b_need: int = floori(float(num) / float(util_ppm))
				if b_need * util_ppm < num:
					b_need = b_need + 1
				var b_take: int = b_need
				if b_take > _to_int(stock.get(g_b, 0)):
					b_take = _to_int(stock.get(g_b, 0))
				if b_take <= 0:
					continue
				plan[g_b] = _to_int(plan.get(g_b, 0)) + b_take
				subst_extra[g_b] = _to_int(subst_extra.get(g_b, 0)) + b_take
				stock[g_b] = _to_int(stock.get(g_b, 0)) - b_take
				var gained: int = floori(float(b_take * util_ppm) / float(_ppm_scale))
				utility = utility + gained
				want_u = want_u - gained
		## FRM-SYS06-08: fulfil_ppm = utility/need × PPM_SCALE
		if need <= 0:
			fulfil[g_a] = _ppm_scale
		else:
			var f: int = floori(float(utility * _ppm_scale) / float(need))
			if f > _ppm_scale:
				f = _ppm_scale
			fulfil[g_a] = f
			if f < _ppm_scale:
				_pending_unmet.append({
					"port": port_s,
					"good": g_a,
					"shortfall": need - utility,
				})

	for g in goods:
		var key := "%s|%s" % [port_s, g]
		_consume_plan[key] = _to_int(plan[g])
		_subst_applied[key] = _to_int(subst_extra[g])
		_fulfil_ppm[key] = _to_int(fulfil.get(g, _ppm_scale))


func _max_cap_ppm(good_s: String) -> int:
	## Shared cap across all substitute rows for A (max of listed caps).
	var m: int = 0
	for row_v in _subst_for(good_s):
		var c: int = _to_int((row_v as Dictionary)["cap_ppm"])
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
	## U-15／FRM-SYS06-09: only poor necessities; renormalize those poor weights to 100%.
	var poor_w: Dictionary = _sat_ppt.get(String(CLASS_POOR), {})
	var sum_ppt: int = 0
	for g in _beggar_goods:
		sum_ppt = sum_ppt + _to_int(poor_w.get(g, 0))
	if sum_ppt <= 0:
		return 0.0
	var acc: int = 0
	for g in _beggar_goods:
		var w_ppt: int = _to_int(poor_w.get(g, 0))
		if w_ppt <= 0:
			continue
		var f_ppm: int = _to_int(_fulfil_ppm.get("%s|%s" % [port_s, g], _ppm_scale))
		acc = acc + w_ppt * f_ppm
	return float(acc) / float(sum_ppt * _ppm_scale)


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



func _to_int(v: Variant) -> int:
	## Coerce Variant→int via floori only (no int()/round/roundi).
	return floori(float(v))


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
