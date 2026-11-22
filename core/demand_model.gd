extends Node
## Autoload DemandModel — SYS-06 resident consumption (TechSpec §16 / D-09a／D-09b／WP-34).
## Formal ConsumptionProvider + SatisfactionInputProvider. Residents only (not SYS-08 inputs).
## _ready() field init only; load_and_validate() from SimLoop.boot (2.2-01).
## Data: csv_import → res://data/demand/{rates,weights,substitutions}/ (D-25／D-36c; N-04 single path).
## D-36a: beggars are hire-pool only — no goods consumption, no satisfaction.

const SYS_ID := &"SYS-06"
const SCRIPT_PATH := "res://core/demand_model.gd"
## Directory root produced by csv_import run_batch_demand (keep TABLES_PATH alias for boot param).
const DEMAND_DIR := "res://data/demand/"
const TABLES_PATH := DEMAND_DIR
const RATES_SUBDIR := "rates"
const WEIGHTS_SUBDIR := "weights"
const SUBST_SUBDIR := "substitutions"

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
var _sat_pct: Dictionary = {} ## class → {good_id: int weight pct points} (D-36c)
var _subst: Array = [] ## [{from,to,cap_ppm,util_ppm}, ...] sorted by from,to

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


func weekly_potential_demand(port_id: StringName, good_id: StringName) -> int:
	## D-96f／FRM-SYS23-04／FRM-SYS04-01（改）：週潛在需求（擔／週，FLOOR）。
	## Exact public name (D-96f)；口径同 weekly_demand。
	## Test-only override：meta `wp64_test_potential` Dictionary keyed "port|good" → int
	## （允許在 DemandModel 未 load 時供 EX-04-09 固定示範值）。
	if has_meta("wp64_test_potential"):
		var ov: Variant = get_meta("wp64_test_potential")
		if typeof(ov) == TYPE_DICTIONARY:
			var key := "%s|%s" % [String(port_id), String(good_id)]
			var d: Dictionary = ov
			if d.has(key):
				return int(d[key])
	assert(_loaded, "DemandModel.weekly_potential_demand before load")
	return weekly_demand(port_id, good_id)


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
	## FRM-SYS06-09／D-36a: class sat = Σ (w/WEIGHT_SUM) × fulfil; POOR／CITIZEN／RICH only.
	var port_s := String(port_id)
	var cls := _norm_class(clazz)
	if cls != CLASS_POOR and cls != CLASS_CITIZEN and cls != CLASS_RICH:
		_record(ERR_SYS06_04, "class", clazz, "unknown class for sat input (beggar has no sat)")
		return 0.0
	var weights: Dictionary = _sat_pct.get(String(cls), {})
	var acc: int = 0
	var keys: Array = weights.keys()
	keys.sort()
	for g_variant in keys:
		var g: String = String(g_variant)
		var w_pct: int = _to_int(weights[g])
		if w_pct <= 0:
			continue
		var f_ppm: int = _to_int(_fulfil_ppm.get("%s|%s" % [port_s, g], _ppm_scale))
		acc = acc + w_pct * f_ppm
	return float(acc) / float(_weight_sum * _ppm_scale)


func consume_qty(port_id: StringName, good_id: StringName, day: int) -> int:
	assert(_loaded, "DemandModel.consume_qty before load")
	_ensure_day_plan(day)
	var key := "%s|%s" % [String(port_id), String(good_id)]
	return _to_int(_consume_plan.get(key, 0))


func rate_scaled(clazz: StringName, good_id: StringName) -> int:
	## Loaded per-class rate (RATE_SCALE × jin／week); 0 if missing.
	assert(_loaded, "DemandModel.rate_scaled before load")
	var cls: String = String(_norm_class(clazz))
	var by_good: Dictionary = _rate_cj.get(cls, {})
	return _to_int(by_good.get(String(good_id), 0))


func sat_weight_pct(clazz: StringName, good_id: StringName) -> int:
	## Loaded satisfaction weight pct points for class×good; 0 if missing.
	assert(_loaded, "DemandModel.sat_weight_pct before load")
	var cls: String = String(_norm_class(clazz))
	var by_good: Dictionary = _sat_pct.get(cls, {})
	return _to_int(by_good.get(String(good_id), 0))


func sat_weight_sum(clazz: StringName) -> int:
	## Sum of loaded sat weights for a class (FRM-SYS06-09／TST-SYS06-04).
	assert(_loaded, "DemandModel.sat_weight_sum before load")
	var cls: String = String(_norm_class(clazz))
	var by_good: Dictionary = _sat_pct.get(cls, {})
	var s := 0
	for g in by_good.keys():
		s = s + _to_int(by_good[g])
	return s


func substitution_cap_ppm(from_good: StringName, to_good: StringName) -> int:
	## Cap ppm for from→to substitution rule; 0 if none.
	assert(_loaded, "DemandModel.substitution_cap_ppm before load")
	for row_v in _subst:
		var row: Dictionary = row_v
		if String(row.get("from", "")) == String(from_good) and String(row.get("to", "")) == String(to_good):
			return _to_int(row.get("cap_ppm", 0))
	return 0


func substitution_util_ppm(from_good: StringName, to_good: StringName) -> int:
	## Utility ppm for from→to substitution rule; 0 if none.
	assert(_loaded, "DemandModel.substitution_util_ppm before load")
	for row_v in _subst:
		var row: Dictionary = row_v
		if String(row.get("from", "")) == String(from_good) and String(row.get("to", "")) == String(to_good):
			return _to_int(row.get("util_ppm", 0))
	return 0


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
	_sat_pct = {}
	_subst = []
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


func _load_tables(demand_dir: String) -> Array:
	## N-04／D-36c／D-40c: single path — csv_import .tres under demand/{rates,weights,substitutions}/.
	var errors: Array = []
	var rates_dir: String = demand_dir.path_join(RATES_SUBDIR)
	var weights_dir: String = demand_dir.path_join(WEIGHTS_SUBDIR)
	var subst_dir: String = demand_dir.path_join(SUBST_SUBDIR)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(demand_dir)):
		errors.append(_err(ERR_SYS06_01, demand_dir, null, "demand tables dir missing (D-25b／D-30a)"))
		return errors
	## D-40c: all three subdirs must exist (empty substitutions OK).
	var rates_abs: String = ProjectSettings.globalize_path(rates_dir)
	var weights_abs: String = ProjectSettings.globalize_path(weights_dir)
	var subst_abs: String = ProjectSettings.globalize_path(subst_dir)
	if not DirAccess.dir_exists_absolute(rates_abs):
		errors.append(_err(ERR_SYS06_01, rates_dir, null, "rates subdir missing (D-40c)"))
	if not DirAccess.dir_exists_absolute(weights_abs):
		errors.append(_err(ERR_SYS06_02, weights_dir, null, "weights subdir missing (D-40c)"))
	if not DirAccess.dir_exists_absolute(subst_abs):
		errors.append(_err(ERR_SYS06_03, subst_dir, null, "substitutions subdir missing (D-40c)"))
	if not errors.is_empty():
		return errors
	var rate_res: Array = _load_tres_dir(rates_dir, ERR_SYS06_01, errors)
	var weight_res: Array = _load_tres_dir(weights_dir, ERR_SYS06_02, errors)
	var subst_res: Array = _load_tres_dir(subst_dir, ERR_SYS06_03, errors)
	if rate_res.is_empty():
		errors.append(
			_err(ERR_SYS06_01, rates_dir, null, "demand rates missing or empty (D-25b／D-30a)")
		)
	if weight_res.is_empty():
		errors.append(
			_err(ERR_SYS06_02, weights_dir, null, "demand weights missing or empty (D-25b／D-30a)")
		)
		## Still attempt parse so C-06 can collect further shape errors when partial.
	errors.append_array(_parse_rates_from_tres(rate_res))
	errors.append_array(_parse_weights_from_tres(weight_res))
	errors.append_array(_parse_subst_from_tres(subst_res))
	return errors


## D-40c: load failures collect errors with filename (ERR-SYS06-01／02／03).
func _load_tres_dir(dir_path: String, err_code: StringName, errors: Array) -> Array:
	var out: Array = []
	var abs_path: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_path):
		errors.append(_err(err_code, dir_path, null, "subdir missing (D-40c)"))
		return out
	var d := DirAccess.open(dir_path)
	if d == null:
		errors.append(_err(err_code, dir_path, null, "subdir open failed (D-40c)"))
		return out
	var names: Array = []
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".tres"):
			names.append(fn)
		fn = d.get_next()
	d.list_dir_end()
	names.sort()
	for name_v in names:
		var fname: String = String(name_v)
		var full: String = dir_path.path_join(fname)
		var res: Resource = load(full) as Resource
		if res == null:
			errors.append(
				_err(err_code, fname, null, "failed to load .tres (D-40c)")
			)
			continue
		out.append(res)
	return out


func _parse_rates_from_tres(resources: Array) -> Array:
	var errors: Array = []
	_rate_cj = {"POOR": {}, "CITIZEN": {}, "RICH": {}}
	if resources.is_empty():
		errors.append(_err(ERR_SYS06_01, "rate_cj", null, "no DemandRate resources"))
		return errors
	for res_v in resources:
		if not (res_v is DemandRate):
			errors.append(_err(ERR_SYS06_01, "rate_cj", res_v, "resource must be DemandRate"))
			continue
		var def: DemandRate = res_v
		var g: String = String(def.good_id)
		if g.is_empty():
			errors.append(_err(ERR_SYS06_01, "rate_cj.good_id", g, "empty good_id"))
			continue
		for pair in [
			["POOR", def.poor_rate_cj],
			["CITIZEN", def.citizen_rate_cj],
			["RICH", def.rich_rate_cj],
		]:
			var cls: String = String(pair[0])
			var n: int = _to_int(pair[1])
			if n < 0:
				errors.append(
					_err(ERR_SYS06_01, "rate_cj.%s.%s" % [cls, g], n, "consumption rate negative")
				)
				continue
			(_rate_cj[cls] as Dictionary)[g] = n
	return errors


func _parse_weights_from_tres(resources: Array) -> Array:
	var errors: Array = []
	_sat_pct = {"POOR": {}, "CITIZEN": {}, "RICH": {}}
	if resources.is_empty():
		errors.append(_err(ERR_SYS06_02, "sat_weight_pct", null, "no SatisfactionWeight resources"))
		return errors
	for res_v in resources:
		if not (res_v is SatisfactionWeight):
			errors.append(
				_err(ERR_SYS06_02, "sat_weight_pct", res_v, "resource must be SatisfactionWeight")
			)
			continue
		var def: SatisfactionWeight = res_v
		var g: String = String(def.good_id)
		if g.is_empty():
			errors.append(_err(ERR_SYS06_02, "sat_weight_pct.good_id", g, "empty good_id"))
			continue
		for pair in [
			["POOR", def.poor_weight_pct],
			["CITIZEN", def.citizen_weight_pct],
			["RICH", def.rich_weight_pct],
		]:
			var cls: String = String(pair[0])
			var n: int = _to_int(pair[1])
			if n < 0:
				errors.append(
					_err(ERR_SYS06_02, "sat_weight_pct.%s.%s" % [cls, g], n, "weight negative")
				)
				continue
			(_sat_pct[cls] as Dictionary)[g] = n
	for cls2 in ["POOR", "CITIZEN", "RICH"]:
		var sum_pct: int = 0
		var block: Dictionary = _sat_pct[cls2]
		var gkeys: Array = block.keys()
		gkeys.sort()
		for g_variant in gkeys:
			sum_pct = sum_pct + _to_int(block[g_variant])
		if sum_pct != _weight_sum:
			errors.append(
				_err(
					ERR_SYS06_02,
					"sat_weight_pct.%s" % cls2,
					sum_pct,
					"class sat weights must sum to PRM-SYS06-WEIGHT_SUM"
				)
			)
	return errors


func _parse_subst_from_tres(resources: Array) -> Array:
	var errors: Array = []
	var out: Array = []
	for res_v in resources:
		if not (res_v is SubstitutionRule):
			errors.append(_err(ERR_SYS06_03, "subst", res_v, "resource must be SubstitutionRule"))
			continue
		var def: SubstitutionRule = res_v
		var fr: String = String(def.good_id)
		var to: String = String(def.substitute_id)
		var cap: int = _to_int(def.cap_ppm)
		var util: int = _to_int(def.util_ppm)
		if fr.is_empty() or to.is_empty():
			errors.append(_err(ERR_SYS06_03, "subst", def, "subst from/to required"))
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
	## FRM-SYS06-01／10／D-36a: W_num = Σ_class pop × rate_scaled; POOR／CITIZEN／RICH only.
	if _has_neg_pop(port_s):
		return 0
	var poor: int = PopulationModel.population(StringName(port_s), CLASS_POOR)
	var cit: int = PopulationModel.population(StringName(port_s), CLASS_CITIZEN)
	var rich: int = PopulationModel.population(StringName(port_s), CLASS_RICH)
	var acc: int = 0
	acc = acc + poor * _to_int(_rate_cj.get(String(CLASS_POOR), {}).get(good_s, 0))
	acc = acc + cit * _to_int(_rate_cj.get(String(CLASS_CITIZEN), {}).get(good_s, 0))
	acc = acc + rich * _to_int(_rate_cj.get(String(CLASS_RICH), {}).get(good_s, 0))
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
