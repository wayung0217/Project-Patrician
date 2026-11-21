extends Node
## Autoload PopulationModel — SYS-07 (TechSpec §14 WP-21 / D-17d).
## _ready() field init only; load_and_validate() from SimLoop.boot.

const SYS_ID := &"SYS-07"
const SCRIPT_PATH := "res://autoload/population_model.gd"

const CLASS_POOR := &"POOR"
const CLASS_CITIZEN := &"CITIZEN"
const CLASS_RICH := &"RICH"
const CLASS_BEGGAR := &"BEGGAR"

const ERR_SYS07_01 := &"ERR-SYS07-01"
const ERR_SYS07_02 := &"ERR-SYS07-02"
const ERR_SYS07_03 := &"ERR-SYS07-03"
const ERR_SYS07_04 := &"ERR-SYS07-04"
const ERR_SYS07_05 := &"ERR-SYS07-05"
const ERR_SYS07_06 := &"ERR-SYS07-06"
const ERR_SYS07_07 := &"ERR-SYS07-07"
const ERR_SYS07_08 := &"ERR-SYS07-08"
const ERR_SYS07_09 := &"ERR-SYS07-09"

const CODE_SAT_PROVIDER_MISSING := &"SATISFACTION_INPUT_PROVIDER_MISSING"

const PRM_SAT_SCALE := "PRM-SYS07-SAT_SCALE"
const PRM_SAT_MAX_STEP := "PRM-SYS07-SAT_MAX_STEP"
const PRM_SAT_IN_MIN := "PRM-SYS07-SAT_IN_MIN"
const PRM_SAT_UP1_MIN := "PRM-SYS07-SAT_UP1_MIN"
const PRM_SAT_UP2_MIN := "PRM-SYS07-SAT_UP2_MIN"
const PRM_SAT_DOWN_MAX := "PRM-SYS07-SAT_DOWN_MAX"
const PRM_SAT_OUT_MAX := "PRM-SYS07-SAT_OUT_MAX"
const PRM_UP1_STREAK := "PRM-SYS07-UP1_STREAK_DAYS"
const PRM_UP2_STREAK := "PRM-SYS07-UP2_STREAK_DAYS"
const PRM_RATE_SCALE := "PRM-SYS07-RATE_SCALE"
const PRM_PF1 := "PRM-SYS07-PF1_RATE_WK"
const PRM_PF2 := "PRM-SYS07-PF2_RATE_WK"
const PRM_PF3 := "PRM-SYS07-PF3_RATE_WK"
const PRM_PF4 := "PRM-SYS07-PF4_RATE_WK"
const PRM_PF5 := "PRM-SYS07-PF5_RATE_WK"
const PRM_PF6 := "PRM-SYS07-PF6_RATE_WK"
const PRM_PF6_BEGGAR := "PRM-SYS07-PF6_BEGGAR_RATE_WK"
const PRM_UNEMP_CAP := "PRM-SYS07-UNEMPLOYED_CAP_PPM"
const PRM_HH := "PRM-SYS07-HOUSEHOLD_SIZE"
const PRM_HOUSE_CAP := "PRM-SYS07-HOUSE_CAPACITY"
const PRM_TIER2 := "PRM-SYS07-TIER2_MIN_ACTIVE"
const PRM_TIER3 := "PRM-SYS07-TIER3_MIN_ACTIVE"
const PRM_LAMBDA := "PRM-SYS07-LAMBDA_RING"
const PRM_TEMPLE := "PRM-SYS07-TEMPLE_BONUS"
const PRM_ALMS := "PRM-SYS07-ALMS_FLOOR"
const PRM_ACADEMY := "PRM-SYS07-ACADEMY_MULT"
const PRM_LOOK_MANSION := "PRM-SYS07-LOOK_MANSION_RICH"
const PRM_LOOK_TILE := "PRM-SYS07-LOOK_TILE_MID"
const PRM_DAYS_PER_WEEK := "PRM-SYS04-DAYS_PER_WEEK"

const CB_TEMPLE := &"CB-04"
const CB_ALMS := &"CB-15"
const CB_ACADEMY := &"CB-12"
const CB_GUILD := &"CB-13"

signal population_changed(port_id: StringName)
signal satisfaction_changed(port_id: StringName)

var _sat_input: SatisfactionInputProvider = null
var _ports: Dictionary = {} ## port_id → PortPop
var _workers: Dictionary = {} ## ws_id:String → int
var _residents: Dictionary = {} ## res_id:String → {poor,citizen,rich,ring,cap,port}
var _port_res_ids: Dictionary = {} ## port_id → Array[String] sorted local res_ids
var _opening_placed: Dictionary = {} ## port_id → bool (FRM-SYS07-14 once)
var _seed: int = 0
var _loaded: bool = false
var _last_error: Dictionary = {}
var _pop_adapter: _PopAdapter = null
var _work_adapter: _WorkAdapter = null
var _sailor_adapter: _SailorAdapter = null
var _pending_pop_ports: Array = []
var _pending_sat_ports: Array = []
## Test／WP-51: count Rng.derive_seed calls during placement (movers only after opening).
var _wp51_rng_calls: int = 0


func _ready() -> void:
	_clear_state()


func set_satisfaction_input_provider(provider: SatisfactionInputProvider) -> void:
	if _loaded:
		push_error("PopulationModel.set_satisfaction_input_provider after load (D-17c); ignored")
		return
	_sat_input = provider


func has_satisfaction_input_provider() -> bool:
	## D-17c／WP-22: public readonly — SimLoop must not read `_sat_input` (C-07).
	return _sat_input != null


func set_master_seed(seed: int) -> void:
	_seed = seed


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func get_population_provider() -> PopulationProvider:
	if _pop_adapter == null:
		_pop_adapter = _PopAdapter.new(self)
	return _pop_adapter


func get_workforce_provider() -> WorkforceProvider:
	if _work_adapter == null:
		_work_adapter = _WorkAdapter.new(self)
	return _work_adapter


func get_sailor_pool_provider() -> SailorPoolProvider:
	## D-19f (c)／D-14b: WP-30 adapter only — does not change hire／release logic.
	if _sailor_adapter == null:
		_sailor_adapter = _SailorAdapter.new(self)
	return _sailor_adapter


func load_and_validate() -> Array:
	var errors: Array = []
	_clear_state()
	if not Params.is_loaded():
		errors.append(_err(ERR_SYS07_06, "Params", null, "Params must load first"))
		_emit(errors)
		return errors
	if _sat_input == null:
		errors.append(
			_err(
				CODE_SAT_PROVIDER_MISSING,
				"SatisfactionInputProvider",
				null,
				"SatisfactionInputProvider must be injected before load (D-17c)"
			)
		)
		_emit(errors)
		return errors
	errors.append_array(_validate_params())
	if not errors.is_empty():
		_emit(errors)
		return errors
	if PortRegistry.is_loaded():
		for pid_v in PortRegistry.all_ids():
			_ensure_port(String(pid_v))
	_loaded = true
	return errors


## Test／WP-24 helper: set class counts and sats for a port (FRM-14 style init).
func set_port_state(
	port_id: String,
	poor: int,
	citizen: int,
	rich: int,
	beggar: int,
	sat_poor: int = -1,
	sat_citizen: int = -1,
	sat_rich: int = -1
) -> void:
	assert(_loaded, "PopulationModel.set_port_state before load")
	var p: PortPop = _ensure_port(port_id)
	p.poor = poor
	p.citizen = citizen
	p.rich = rich
	p.beggar = beggar
	if sat_poor >= 0:
		p.sat_poor = sat_poor
	if sat_citizen >= 0:
		p.sat_citizen = sat_citizen
	if sat_rich >= 0:
		p.sat_rich = sat_rich


func set_workers(ws_id: StringName, n: int) -> void:
	assert(_loaded, "PopulationModel.set_workers before load")
	if n < 0:
		_record(ERR_SYS07_01, "workers", n, "negative workers")
		return
	_workers[String(ws_id)] = n


func population(port_id: StringName, clazz: StringName = &"") -> int:
	assert(_loaded, "PopulationModel.population before load")
	var p: PortPop = _ports.get(String(port_id), null) as PortPop
	if p == null:
		_record(ERR_SYS07_08, "port_id", port_id, "unknown port")
		return 0
	if clazz == CLASS_POOR or clazz == &"poor":
		return p.poor
	if clazz == CLASS_CITIZEN or clazz == &"citizen":
		return p.citizen
	if clazz == CLASS_RICH or clazz == &"rich":
		return p.rich
	if clazz == CLASS_BEGGAR or clazz == &"beggar":
		return p.beggar
	if clazz == &"":
		return p.poor + p.citizen + p.rich + p.beggar
	_record(ERR_SYS07_08, "class", clazz, "unknown class")
	return 0


func beggars(port_id: StringName) -> int:
	return population(port_id, CLASS_BEGGAR)


func workers(ws_id: StringName) -> int:
	assert(_loaded, "PopulationModel.workers before load")
	return int(_workers.get(String(ws_id), 0))


func satisfaction(port_id: StringName, clazz: StringName) -> int:
	assert(_loaded, "PopulationModel.satisfaction before load")
	var p: PortPop = _ports.get(String(port_id), null) as PortPop
	if p == null:
		_record(ERR_SYS07_08, "port_id", port_id, "unknown port")
		return 0
	if clazz == CLASS_POOR or clazz == &"poor":
		return p.sat_poor
	if clazz == CLASS_CITIZEN or clazz == &"citizen":
		return p.sat_citizen
	if clazz == CLASS_RICH or clazz == &"rich":
		return p.sat_rich
	_record(ERR_SYS07_08, "class", clazz, "unknown class")
	return 0


const OPENING_POP_DIR := "res://data/opening_population/"


func apply_opening_init(opening_pop_dir: String = OPENING_POP_DIR) -> Array:
	## FRM-SYS07-14／D-19e: load opening population; empty／missing／duplicate → ERR-SYS07-09.
	assert(_loaded, "PopulationModel.apply_opening_init before load")
	var errors: Array = []
	var rows: Array = _load_opening_population(opening_pop_dir)
	var seen: Dictionary = {} ## port_id → true
	if rows.is_empty():
		errors.append(
			_err(ERR_SYS07_09, "opening_population", opening_pop_dir, "opening population dir empty or missing")
		)
	for row_v in rows:
		var row: OpeningPopulation = row_v
		var pid: String = String(row.port_id)
		if seen.has(pid):
			errors.append(_err(ERR_SYS07_09, "port_id", pid, "duplicate opening population port"))
			continue
		seen[pid] = true
		if row.poor < 0 or row.citizen < 0 or row.rich < 0:
			errors.append(_err(ERR_SYS07_01, "opening_pop", pid, "negative opening population"))
			continue
		set_port_state(pid, row.poor, row.citizen, row.rich, 0)
		var p: PortPop = _ensure_port(pid)
		p.streak_up1 = 0
		p.streak_up2 = 0
		p.acc = {}
		p.pending_release_workers = 0
	if PortRegistry.is_loaded():
		for pid_v in PortRegistry.all_ids():
			var want: String = String(pid_v)
			if not seen.has(want):
				errors.append(_err(ERR_SYS07_09, "port_id", want, "missing opening population for port"))
	if not errors.is_empty():
		_emit(errors)
	return errors


func _load_opening_population(dir: String) -> Array:
	var out: Array = []
	var abs_dir: String = ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return out
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var fname: String = d.get_next()
		if fname == "":
			break
		if d.current_is_dir() or not fname.ends_with(".tres"):
			continue
		var res: Resource = load(dir.path_join(fname))
		if res is OpeningPopulation:
			out.append(res)
	d.list_dir_end()
	return out


func residence_occupants(res_id: StringName) -> Dictionary:
	## {poor, citizen, rich} for FRM-13 rent; empty dict if unknown.
	assert(_loaded, "PopulationModel.residence_occupants before load")
	var raw: Variant = _residents.get(String(res_id), null)
	if raw == null:
		return {"poor": 0, "citizen": 0, "rich": 0}
	var r: Dictionary = raw
	return {
		"poor": int(r.get("poor", 0)),
		"citizen": int(r.get("citizen", 0)),
		"rich": int(r.get("rich", 0)),
	}


## Test helper: set residence occupants for rent accrual tests.
func set_residence_occupants(
	res_id: StringName, poor: int, citizen: int, rich: int, ring: int = 1
) -> void:
	assert(_loaded, "PopulationModel.set_residence_occupants before load")
	var rid: String = String(res_id)
	_residents[rid] = {
		"poor": poor,
		"citizen": citizen,
		"rich": rich,
		"ring": ring,
		"cap": 100,
		"port": "",
	}


func housing_capacity(port_id: StringName) -> int:
	assert(_loaded, "PopulationModel.housing_capacity before load")
	if not BuildingEconomy.is_loaded():
		return 0
	var n: int = BuildingEconomy.residences(port_id).size()
	return n * Params.get_int(PRM_HOUSE_CAP)


func job_capacity(port_id: StringName) -> int:
	assert(_loaded, "PopulationModel.job_capacity before load")
	if not BuildingEconomy.is_loaded():
		return 0
	var hh: int = Params.get_int(PRM_HH)
	var sum := 0
	for bld_v in BuildingEconomy.workplaces(port_id):
		var bld: Building = bld_v
		var def: BuildingDef = BuildingEconomy._building_defs.get(String(bld.type), null) as BuildingDef
		if def == null:
			continue
		sum = sum + def.max_workers * hh
	return sum


func hire_sailors(port_id: StringName, n: int) -> int:
	assert(_loaded, "PopulationModel.hire_sailors before load")
	_clear_last()
	var p: PortPop = _ports.get(String(port_id), null) as PortPop
	if p == null:
		_record(ERR_SYS07_08, "port_id", port_id, "unknown port")
		return 0
	if n <= 0:
		return 0
	if p.beggar < n:
		_record(ERR_SYS07_07, "beggar", p.beggar, "insufficient beggars for hire_sailors")
		return 0
	p.beggar = p.beggar - n
	return n


func release_sailors(port_id: StringName, n: int) -> int:
	assert(_loaded, "PopulationModel.release_sailors before load")
	_clear_last()
	var p: PortPop = _ports.get(String(port_id), null) as PortPop
	if p == null:
		_record(ERR_SYS07_08, "port_id", port_id, "unknown port")
		return 0
	if n <= 0:
		return 0
	p.beggar = p.beggar + n
	return n


func weighted_avg_sat(port_id: String) -> int:
	var p: PortPop = _ensure_port(port_id)
	var res: int = p.poor + p.citizen + p.rich
	if res <= 0:
		return 0
	return int(
		(p.poor * p.sat_poor + p.citizen * p.sat_citizen + p.rich * p.sat_rich) / res
	)


func daily_step(day: int) -> Array:
	## 14-03: after workshop produce; ports ascending; S0 → flows → apply once.
	assert(_loaded, "PopulationModel.daily_step before load")
	var errors: Array = []
	var ports: Array = _ports.keys()
	ports.sort()
	for pid_v in ports:
		_daily_port(String(pid_v), day, errors)
	return errors


func flush_signals() -> void:
	for pid in _pending_pop_ports:
		population_changed.emit(StringName(String(pid)))
	for pid2 in _pending_sat_ports:
		satisfaction_changed.emit(StringName(String(pid2)))
	_pending_pop_ports = []
	_pending_sat_ports = []


func _daily_port(port_id: String, day: int, errors: Array) -> void:
	var p: PortPop = _ensure_port(port_id)
	# ① S0
	var s0_poor: int = p.poor
	var s0_cit: int = p.citizen
	var s0_rich: int = p.rich
	var s0_beg: int = p.beggar
	var s0_sat_p: int = p.sat_poor
	var s0_sat_c: int = p.sat_citizen
	var s0_sat_r: int = p.sat_rich
	# FRM-SYS07-14／D-63e: one full local placement before first movers (S0 counts).
	_sync_port_residences(port_id, day)
	if not bool(_opening_placed.get(port_id, false)):
		_opening_place_full(port_id, p, day)
		_opening_placed[port_id] = true
	# ② sat targets + inertia
	_update_satisfaction(p, port_id)
	_pending_sat_ports.append(port_id)
	# ③ streaks (use updated sat)
	_update_streaks(p)
	# ④ flows from S0
	var flows: Dictionary = _compute_flows(
		port_id, p, s0_poor, s0_cit, s0_rich, s0_beg, s0_sat_p, s0_sat_c, s0_sat_r
	)
	# ⑤ apply once
	p.beggar = p.beggar + int(flows["in"]) - int(flows["out_beg"])
	p.poor = (
		p.poor
		- int(flows["up1"])
		+ int(flows["dn1"])
		- int(flows["out_poor"])
	)
	p.citizen = (
		p.citizen
		+ int(flows["up1"])
		- int(flows["up2"])
		+ int(flows["dn2"])
		- int(flows["dn1"])
	)
	p.rich = p.rich + int(flows["up2"]) - int(flows["dn2"])
	_clamp_nonneg(p)
	# FRM-03／OQ-13w: release workers whose workshops vanished (e.g. demolish).
	var lost_poor: int = _apply_lost_workshop_workers(port_id, p)
	# FRM-03／Q-07a: residents over job_cap → citizen via PF-5 → beggar (gradual).
	var overflow_cit: int = _apply_job_cap_overflow(port_id, p, s0_cit)
	# ⑥ hire
	var hired_poor: int = _hire_workers(port_id, p)
	# ⑦ incremental placement — movers only (FRM-SYS07-12／OQ-13j／D-63e)
	_place_movers(
		port_id,
		day,
		int(flows["out_poor"]) + lost_poor,
		overflow_cit,
		int(flows["dn2"]),
		int(flows["dn1"]),
		int(flows["up1"]),
		int(flows["up2"]),
		hired_poor
	)
	_pending_pop_ports.append(port_id)
	var _e: Array = errors # reserved


func _update_satisfaction(p: PortPop, port_id: String) -> void:
	var scale: int = Params.get_int(PRM_SAT_SCALE)
	var step: int = Params.get_int(PRM_SAT_MAX_STEP)
	p.sat_poor = _step_sat(p.sat_poor, _target_sat(port_id, CLASS_POOR, true), step, scale)
	p.sat_citizen = _step_sat(
		p.sat_citizen, _target_sat(port_id, CLASS_CITIZEN, false), step, scale
	)
	p.sat_rich = _step_sat(p.sat_rich, _target_sat(port_id, CLASS_RICH, false), step, scale)


func _target_sat(port_id: String, clazz: StringName, is_poor: bool) -> int:
	var scale: int = Params.get_int(PRM_SAT_SCALE)
	var inp: float = _sat_input.satisfaction_input(StringName(port_id), clazz)
	if inp < 0.0:
		inp = 0.0
	if inp > 1.0:
		inp = 1.0
	var temple_lv: int = 0
	var alms_lv: int = 0
	if BuildingEconomy.is_loaded():
		temple_lv = BuildingEconomy.public_level(StringName(port_id), CB_TEMPLE)
		alms_lv = BuildingEconomy.public_level(StringName(port_id), CB_ALMS)
	var bonus := 0
	var temple: Array = Params.get_value(PRM_TEMPLE)
	if temple_lv >= 1 and temple_lv <= temple.size():
		bonus = int(temple[temple_lv - 1])
	var t: int = mini(
		scale, floori(AmountQuantize.quantize_amount(inp * float(scale))) + bonus
	)
	if is_poor:
		var alms: Array = Params.get_value(PRM_ALMS)
		var floor_v := 0
		if alms_lv >= 1 and alms_lv <= alms.size():
			floor_v = int(alms[alms_lv - 1])
		if t < floor_v:
			t = floor_v
	return t


func _step_sat(sat: int, target: int, step: int, scale: int) -> int:
	if sat < 0:
		sat = target # OQ-13l first day
	var delta: int = target - sat
	if delta == 0:
		return sat
	var move: int = mini(absi(delta), step)
	if delta < 0:
		move = 0 - move
	var out: int = sat + move
	if out < 0:
		out = 0
	if out > scale:
		out = scale
	return out


func _update_streaks(p: PortPop) -> void:
	if p.sat_poor >= Params.get_int(PRM_SAT_UP1_MIN):
		p.streak_up1 = p.streak_up1 + 1
	else:
		p.streak_up1 = 0
	if p.sat_citizen >= Params.get_int(PRM_SAT_UP2_MIN):
		p.streak_up2 = p.streak_up2 + 1
	else:
		p.streak_up2 = 0


func _compute_flows(
	port_id: String,
	p: PortPop,
	s0_poor: int,
	s0_cit: int,
	s0_rich: int,
	s0_beg: int,
	s0_sat_p: int,
	s0_sat_c: int,
	s0_sat_r: int
) -> Dictionary:
	var days_pw: int = Params.get_int(PRM_DAYS_PER_WEEK)
	var rate_scale: int = Params.get_int(PRM_RATE_SCALE)
	var denom: int = rate_scale * days_pw
	var beds: int = housing_capacity(StringName(port_id))
	var residents0: int = s0_poor + s0_cit + s0_rich
	var free_beds: int = beds - residents0
	if free_beds < 0:
		free_beds = 0
	var cap: int = int(residents0 * Params.get_int(PRM_UNEMP_CAP) / rate_scale)
	# weighted avg from S0 sats
	var wavg := 0
	if residents0 > 0:
		wavg = int((s0_poor * s0_sat_p + s0_cit * s0_sat_c + s0_rich * s0_sat_r) / residents0)
	# PF-1
	var flow_in := 0
	if wavg >= Params.get_int(PRM_SAT_IN_MIN) and free_beds > 0 and s0_beg < cap:
		var base_in: int = mini(free_beds, cap - s0_beg)
		flow_in = _moved(p, "acc_in", base_in, Params.get_int(PRM_PF1), denom)
	# PF-2
	var flow_up1 := 0
	if (
		p.streak_up1 >= Params.get_int(PRM_UP1_STREAK)
		and _active_tier_workshops(port_id, 2) >= Params.get_int(PRM_TIER2)
	):
		flow_up1 = _moved(p, "acc_up1", s0_poor, Params.get_int(PRM_PF2), denom)
	# PF-3
	var flow_up2 := 0
	var academy_ok: bool = (
		BuildingEconomy.is_loaded()
		and BuildingEconomy.public_level(StringName(port_id), CB_ACADEMY) > 0
		and BuildingEconomy.public_level(StringName(port_id), CB_GUILD) > 0
	)
	if p.streak_up2 >= Params.get_int(PRM_UP2_STREAK) and (
		_active_tier_workshops(port_id, 3) >= Params.get_int(PRM_TIER3) or academy_ok
	):
		var amult: Array = Params.get_value(PRM_ACADEMY)
		var lv: int = 1
		if BuildingEconomy.is_loaded():
			lv = maxi(1, BuildingEconomy.public_level(StringName(port_id), CB_ACADEMY))
		var mult: int = int(amult[mini(lv, amult.size()) - 1])
		var rate3: int = int(Params.get_int(PRM_PF3) * mult / 1000)
		flow_up2 = _moved(p, "acc_up2", s0_cit, rate3, denom)
	# PF-4 / PF-5
	var flow_dn2 := 0
	if s0_sat_r < Params.get_int(PRM_SAT_DOWN_MAX):
		flow_dn2 = _moved(p, "acc_dn2", s0_rich, Params.get_int(PRM_PF4), denom)
	var flow_dn1 := 0
	if s0_sat_c < Params.get_int(PRM_SAT_DOWN_MAX):
		flow_dn1 = _moved(p, "acc_dn1", s0_cit, Params.get_int(PRM_PF5), denom)
	# PF-6
	var flow_out_beg := 0
	var flow_out_poor := 0
	var out_max: int = Params.get_int(PRM_SAT_OUT_MAX)
	if s0_sat_p < out_max or s0_beg > cap:
		var base_beg: int = 0
		if s0_sat_p < out_max:
			base_beg = s0_beg
		base_beg = maxi(base_beg, s0_beg - cap)
		flow_out_beg = _moved(p, "acc_out_beg", base_beg, Params.get_int(PRM_PF6_BEGGAR), denom)
	if s0_beg == 0:
		var base_poor := 0
		if s0_sat_p < out_max:
			base_poor = s0_poor
		var overflow: int = maxi(0, residents0 - beds)
		base_poor = maxi(base_poor, overflow)
		flow_out_poor = _moved(p, "acc_out_poor", base_poor, Params.get_int(PRM_PF6), denom)
	return {
		"in": flow_in,
		"up1": flow_up1,
		"up2": flow_up2,
		"dn1": flow_dn1,
		"dn2": flow_dn2,
		"out_beg": flow_out_beg,
		"out_poor": flow_out_poor,
	}


func _moved(p: PortPop, acc_key: String, base: int, rate_wk: int, denom: int) -> int:
	if base <= 0 or rate_wk <= 0 or denom <= 0:
		return 0
	var acc: int = int(p.acc.get(acc_key, 0)) + base * rate_wk
	var moved: int = int(acc / denom)
	if moved > base:
		moved = base
	acc = acc - moved * denom
	p.acc[acc_key] = acc
	return moved


func _active_tier_workshops(port_id: String, tier: int) -> int:
	if not BuildingEconomy.is_loaded():
		return 0
	var n := 0
	for bld_v in BuildingEconomy.workplaces(StringName(port_id)):
		var bld: Building = bld_v
		var def: BuildingDef = BuildingEconomy._building_defs.get(String(bld.type), null) as BuildingDef
		if def == null:
			continue
		if def.tier != tier:
			continue
		if workers(bld.building_id) >= 1:
			n = n + 1
	return n


func release_workshop_workers(port_id: StringName, ws_id: StringName) -> void:
	## Called from BuildingEconomy.demolish (OQ-13w); applied on next daily_step via queue.
	assert(_loaded, "PopulationModel.release_workshop_workers before load")
	var n: int = workers(ws_id)
	if n <= 0:
		_workers.erase(String(ws_id))
		return
	_workers[String(ws_id)] = 0
	var p: PortPop = _ensure_port(String(port_id))
	p.pending_release_workers = p.pending_release_workers + n


func _apply_lost_workshop_workers(port_id: String, p: PortPop) -> int:
	## OQ-13w／TST-SYS07-08: queued demolish releases → poor become beggars.
	## Citizen shortfall is gradual via PF-5 (FRM-03／Q-07a), not instant.
	var hh: int = Params.get_int(PRM_HH)
	if hh <= 0 or p.pending_release_workers <= 0:
		return 0
	var people: int = p.pending_release_workers * hh
	p.pending_release_workers = 0
	var take: int = mini(people, p.poor)
	p.poor = p.poor - take
	p.beggar = p.beggar + take
	return take


func _apply_job_cap_overflow(port_id: String, p: PortPop, s0_cit: int) -> int:
	## FRM-03／Q-07a／TST-SYS07-18: residents > job_cap → citizen @ PF-5 → beggar.
	var job_cap: int = job_capacity(StringName(port_id))
	var residents: int = p.poor + p.citizen + p.rich
	var excess: int = residents - job_cap
	if excess <= 0 or p.citizen <= 0:
		return 0
	var days_pw: int = Params.get_int(PRM_DAYS_PER_WEEK)
	var rate_scale: int = Params.get_int(PRM_RATE_SCALE)
	var denom: int = rate_scale * days_pw
	var base_cit: int = mini(s0_cit, p.citizen)
	var flow: int = _moved(p, "acc_job_overflow", base_cit, Params.get_int(PRM_PF5), denom)
	flow = mini(flow, excess)
	flow = mini(flow, p.citizen)
	if flow <= 0:
		return 0
	p.citizen = p.citizen - flow
	p.beggar = p.beggar + flow
	return flow


func _hire_workers(port_id: String, p: PortPop) -> int:
	if not BuildingEconomy.is_loaded():
		return 0
	var hh: int = Params.get_int(PRM_HH)
	if hh <= 0:
		return 0
	var beds: int = housing_capacity(StringName(port_id))
	var residents: int = p.poor + p.citizen + p.rich
	var free_beds: int = beds - residents
	if free_beds < 0:
		free_beds = 0
	var slots: Array = [] ## {id, need}
	var total_need := 0
	for bld_v in BuildingEconomy.workplaces(StringName(port_id)):
		var bld: Building = bld_v
		var def: BuildingDef = BuildingEconomy._building_defs.get(String(bld.type), null) as BuildingDef
		if def == null:
			continue
		var have: int = workers(bld.building_id)
		var need: int = def.max_workers - have
		if need > 0:
			slots.append({"id": bld.building_id, "need": need})
			total_need = total_need + need
	var h: int = mini(int(p.beggar / hh), int(free_beds / hh))
	h = mini(h, total_need)
	if h <= 0:
		return 0
	# Largest remainder allocation across slots
	var assigned: Dictionary = {}
	var sum_need: int = maxi(1, total_need)
	var allocated := 0
	var fracs: Array = []
	for s in slots:
		var raw: float = float(h) * float(s["need"]) / float(sum_need)
		var base_a: int = int(raw)
		assigned[s["id"]] = base_a
		allocated = allocated + base_a
		fracs.append({"id": s["id"], "frac": raw - float(base_a)})
	var rem: int = h - allocated
	fracs.sort_custom(func(a, b): return float(a["frac"]) > float(b["frac"]))
	for i in range(rem):
		if i >= fracs.size():
			break
		var idv: StringName = fracs[i]["id"]
		assigned[idv] = int(assigned.get(idv, 0)) + 1
	var hired_people := 0
	for id_k in assigned.keys():
		var add: int = int(assigned[id_k])
		if add <= 0:
			continue
		_workers[String(id_k)] = workers(StringName(String(id_k))) + add
		p.beggar = p.beggar - add * hh
		p.poor = p.poor + add * hh
		hired_people = hired_people + add * hh
	return hired_people


## FRM-SYS07-12 purposes (D-63e／WP-51): place_in / place_up / place_dn
## (replaced legacy place_poor／place_citizen／place_rich full re-place).
const PURPOSE_IN := "place_in"
const PURPOSE_UP := "place_up"
const PURPOSE_DN := "place_dn"


func _sync_port_residences(port_id: String, day: int) -> void:
	## Keep persistent local occupants; add new residences; demolish → rehouse (OQ-13p／res_id asc).
	if not BuildingEconomy.is_loaded():
		return
	var house_cap: int = Params.get_int(PRM_HOUSE_CAP)
	var res_list: Array = BuildingEconomy.residences(StringName(port_id))
	var live: Dictionary = {} ## res_id → true
	var ids: Array = []
	for bld_v in res_list:
		var bld: Building = bld_v
		var rid: String = String(bld.building_id)
		live[rid] = true
		ids.append(rid)
		if not _residents.has(rid):
			var ring := 1
			var slot: Slot = BuildingEconomy.get_slot(bld.slot_id)
			if slot != null:
				ring = maxi(1, slot.ring)
			_residents[rid] = {
				"poor": 0,
				"citizen": 0,
				"rich": 0,
				"ring": ring,
				"cap": house_cap,
				"port": port_id,
			}
		else:
			var r0: Dictionary = _residents[rid]
			r0["port"] = port_id
			r0["cap"] = house_cap
	ids.sort()
	# Demolished / gone residences previously tracked for this port (res_id asc).
	var old_ids: Array = _port_res_ids.get(port_id, [])
	var displaced_poor := 0
	var displaced_cit := 0
	var displaced_rich := 0
	for oid_v in old_ids:
		var oid: String = String(oid_v)
		if live.has(oid):
			continue
		if not _residents.has(oid):
			continue
		var gone: Dictionary = _residents[oid]
		displaced_poor = displaced_poor + int(gone.get("poor", 0))
		displaced_cit = displaced_cit + int(gone.get("citizen", 0))
		displaced_rich = displaced_rich + int(gone.get("rich", 0))
		_residents.erase(oid)
	_port_res_ids[port_id] = ids
	# Rehouse displaced via 移入 lottery (same building class); leftover stay unplaced.
	for _i in range(displaced_rich):
		_place_one_in(port_id, day, "rich")
	for _j in range(displaced_cit):
		_place_one_in(port_id, day, "citizen")
	for _k in range(displaced_poor):
		_place_one_in(port_id, day, "poor")


func _opening_place_full(port_id: String, p: PortPop, day: int) -> void:
	## FRM-SYS07-14 once: place all housed classes with FRM-SYS07-12 移入 keys (local only).
	_clear_port_occupants(port_id)
	for _i in range(p.poor):
		_place_one_in(port_id, day, "poor")
	for _j in range(p.citizen):
		_place_one_in(port_id, day, "citizen")
	for _k in range(p.rich):
		_place_one_in(port_id, day, "rich")


func _clear_port_occupants(port_id: String) -> void:
	var ids: Array = _port_res_ids.get(port_id, [])
	for rid_v in ids:
		var rid: String = String(rid_v)
		if not _residents.has(rid):
			continue
		var r: Dictionary = _residents[rid]
		r["poor"] = 0
		r["citizen"] = 0
		r["rich"] = 0


func _place_movers(
	port_id: String,
	day: int,
	out_poor: int,
	out_citizen: int,
	dn2: int,
	dn1: int,
	up1: int,
	up2: int,
	in_poor: int
) -> void:
	## FRM-SYS07-12／OQ-13j: one lottery per mover; local residences only; res_id asc.
	for _a in range(maxi(0, out_poor)):
		_remove_one(port_id, day, "poor", PURPOSE_DN)
	for _b in range(maxi(0, out_citizen)):
		_remove_one(port_id, day, "citizen", PURPOSE_DN)
	for _c in range(maxi(0, dn2)):
		_class_shift(port_id, day, "rich", "citizen", PURPOSE_DN)
	for _d in range(maxi(0, dn1)):
		_class_shift(port_id, day, "citizen", "poor", PURPOSE_DN)
	for _e in range(maxi(0, up1)):
		_class_shift(port_id, day, "poor", "citizen", PURPOSE_UP)
	for _f in range(maxi(0, up2)):
		_class_shift(port_id, day, "citizen", "rich", PURPOSE_UP)
	for _g in range(maxi(0, in_poor)):
		_place_one_in(port_id, day, "poor")


func _local_res_ids(port_id: String) -> Array:
	var ids: Array = _port_res_ids.get(port_id, [])
	# Defensive copy＋sort (ids already sorted at sync; keep deterministic).
	var out: Array = ids.duplicate()
	out.sort()
	return out


func _ring_weight(ring: int, lambda: float) -> float:
	var w: float = exp(0.0 - lambda * float(ring - 1))
	if w <= 0.0:
		w = 1.0e-9
	return w


func _draw_u(port_id: String, day: int, res_id: String, purpose: String) -> float:
	_wp51_rng_calls = _wp51_rng_calls + 1
	var u_seed: int = Rng.derive_seed(_seed, day, port_id, res_id, purpose)
	var u_pair: Array = Rng.next(u_seed)
	var u: float = float(abs(int(u_pair[1]) % 1000000)) / 1000000.0
	if u <= 0.0:
		u = 1.0e-9
	return u


func _place_one_in(port_id: String, day: int, clazz: String) -> bool:
	## 移入：weight 1/w → score = u^(1/(1/w)) = u^w among residences with free beds.
	var lambda: float = Params.get_float(PRM_LAMBDA)
	var best_id := ""
	var best_score := -1.0e30
	for rid_v in _local_res_ids(port_id):
		var rid: String = String(rid_v)
		var r: Dictionary = _residents[rid]
		var used: int = int(r["poor"]) + int(r["citizen"]) + int(r["rich"])
		if used >= int(r["cap"]):
			continue
		var w: float = _ring_weight(int(r["ring"]), lambda)
		var u: float = _draw_u(port_id, day, rid, PURPOSE_IN)
		var score: float = pow(u, w)
		if score > best_score:
			best_score = score
			best_id = rid
	if best_id == "":
		return false
	var bucket: Dictionary = _residents[best_id]
	bucket[clazz] = int(bucket[clazz]) + 1
	return true


func _pick_residence_with_class(
	port_id: String, day: int, clazz: String, purpose: String
) -> String:
	## Upgrade: u^(1/w); downgrade／leave: u^w (FRM-SYS07-12).
	var lambda: float = Params.get_float(PRM_LAMBDA)
	var best_id := ""
	var best_score := -1.0e30
	var is_up: bool = purpose == PURPOSE_UP
	for rid_v in _local_res_ids(port_id):
		var rid: String = String(rid_v)
		var r: Dictionary = _residents[rid]
		if int(r.get(clazz, 0)) <= 0:
			continue
		var w: float = _ring_weight(int(r["ring"]), lambda)
		var u: float = _draw_u(port_id, day, rid, purpose)
		var score: float
		if is_up:
			score = pow(u, 1.0 / w)
		else:
			score = pow(u, w)
		if score > best_score:
			best_score = score
			best_id = rid
	return best_id


func _remove_one(port_id: String, day: int, clazz: String, purpose: String) -> bool:
	var rid: String = _pick_residence_with_class(port_id, day, clazz, purpose)
	if rid == "":
		return false
	var r: Dictionary = _residents[rid]
	r[clazz] = int(r[clazz]) - 1
	return true


func _class_shift(
	port_id: String, day: int, from_c: String, to_c: String, purpose: String
) -> bool:
	var rid: String = _pick_residence_with_class(port_id, day, from_c, purpose)
	if rid == "":
		return false
	var r: Dictionary = _residents[rid]
	r[from_c] = int(r[from_c]) - 1
	r[to_c] = int(r[to_c]) + 1
	return true


func _clamp_nonneg(p: PortPop) -> void:
	if p.poor < 0:
		p.poor = 0
	if p.citizen < 0:
		p.citizen = 0
	if p.rich < 0:
		p.rich = 0
	if p.beggar < 0:
		p.beggar = 0


func _validate_params() -> Array:
	var errors: Array = []
	var required: Array = [
		PRM_SAT_SCALE,
		PRM_SAT_MAX_STEP,
		PRM_SAT_IN_MIN,
		PRM_SAT_UP1_MIN,
		PRM_SAT_UP2_MIN,
		PRM_SAT_DOWN_MAX,
		PRM_SAT_OUT_MAX,
		PRM_UP1_STREAK,
		PRM_UP2_STREAK,
		PRM_RATE_SCALE,
		PRM_PF1,
		PRM_PF2,
		PRM_PF3,
		PRM_PF4,
		PRM_PF5,
		PRM_PF6,
		PRM_PF6_BEGGAR,
		PRM_UNEMP_CAP,
		PRM_HH,
		PRM_HOUSE_CAP,
		PRM_TIER2,
		PRM_TIER3,
		PRM_LAMBDA,
		PRM_TEMPLE,
		PRM_ALMS,
		PRM_ACADEMY,
		PRM_LOOK_MANSION,
		PRM_LOOK_TILE,
	]
	for key in required:
		if not Params.has_prm(StringName(key)):
			errors.append(_err(ERR_SYS07_06, key, null, "required PRM missing"))
	# C-06／TST-SYS07-13: keep collecting threshold／λ errors even when keys are missing.
	var can_check_thresholds: bool = (
		Params.has_prm(StringName(PRM_SAT_OUT_MAX))
		and Params.has_prm(StringName(PRM_SAT_DOWN_MAX))
		and Params.has_prm(StringName(PRM_SAT_IN_MIN))
		and Params.has_prm(StringName(PRM_SAT_UP1_MIN))
		and Params.has_prm(StringName(PRM_SAT_UP2_MIN))
	)
	if can_check_thresholds:
		var out_v: int = Params.get_int(PRM_SAT_OUT_MAX)
		var down_v: int = Params.get_int(PRM_SAT_DOWN_MAX)
		var in_v: int = Params.get_int(PRM_SAT_IN_MIN)
		var up1: int = Params.get_int(PRM_SAT_UP1_MIN)
		var up2: int = Params.get_int(PRM_SAT_UP2_MIN)
		# OUT < DOWN ≤ IN ≤ UP1 ≤ UP2
		if not (out_v < down_v and down_v <= in_v and in_v <= up1 and up1 <= up2):
			errors.append(
				_err(ERR_SYS07_02, "thresholds", [out_v, down_v, in_v, up1, up2], "threshold order")
			)
	if (
		Params.has_prm(StringName(PRM_PF6_BEGGAR))
		and Params.has_prm(StringName(PRM_PF6))
		and Params.get_int(PRM_PF6_BEGGAR) <= Params.get_int(PRM_PF6)
	):
		errors.append(
			_err(
				ERR_SYS07_02,
				PRM_PF6_BEGGAR,
				Params.get_int(PRM_PF6_BEGGAR),
				"PF6_BEGGAR must be > PF6_RATE"
			)
		)
	if Params.has_prm(StringName(PRM_LAMBDA)) and Params.get_float(PRM_LAMBDA) <= 0.0:
		errors.append(_err(ERR_SYS07_05, PRM_LAMBDA, Params.get_float(PRM_LAMBDA), "lambda <= 0"))
	return errors


func _ensure_port(port_id: String) -> PortPop:
	if not _ports.has(port_id):
		_ports[port_id] = PortPop.new()
	return _ports[port_id] as PortPop


func _clear_state() -> void:
	_ports = {}
	_workers = {}
	_residents = {}
	_port_res_ids = {}
	_opening_placed = {}
	_wp51_rng_calls = 0
	_loaded = false
	_pending_pop_ports = []
	_pending_sat_ports = []
	_clear_last()


func _clear_last() -> void:
	_last_error = {}


func _record(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = _err(code, field, value, message)
	push_error("PopulationModel: %s" % str(_last_error))


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _emit(errors: Array) -> void:
	for e in errors:
		push_error("PopulationModel: %s" % str(e))


class PortPop:
	var poor: int = 0
	var citizen: int = 0
	var rich: int = 0
	var beggar: int = 0
	var sat_poor: int = -1
	var sat_citizen: int = -1
	var sat_rich: int = -1
	var streak_up1: int = 0
	var streak_up2: int = 0
	var acc: Dictionary = {}
	var pending_release_workers: int = 0


class _PopAdapter extends PopulationProvider:
	var _model: Node

	func _init(model: Node) -> void:
		_model = model

	func population(port_id: StringName) -> int:
		## SYS-08 land_price uses total residents (poor+citizen+rich); beggars excluded from housing.
		if _model == null or not _model.is_loaded():
			return POPULATION_FAILURE
		var poor: int = _model.population(port_id, &"POOR")
		var cit: int = _model.population(port_id, &"CITIZEN")
		var rich: int = _model.population(port_id, &"RICH")
		return poor + cit + rich


class _WorkAdapter extends WorkforceProvider:
	var _model: Node

	func _init(model: Node) -> void:
		_model = model

	func workers(ws_id: StringName) -> int:
		if _model == null or not _model.is_loaded():
			return WORKERS_FAILURE
		return _model.workers(ws_id)


class _SailorAdapter extends SailorPoolProvider:
	## D-19f (c): thin wrap; hire_sailors／release_sailors logic unchanged.
	var _model: Node

	func _init(model: Node) -> void:
		_model = model

	func beggars(port_id: StringName) -> int:
		if _model == null or not _model.is_loaded():
			return BEGGARS_FAILURE
		return _model.beggars(port_id)

	func hire_sailors(port_id: StringName, n: int) -> int:
		if _model == null or not _model.is_loaded():
			return 0
		return _model.hire_sailors(port_id, n)

	func release_sailors(port_id: StringName, n: int) -> int:
		if _model == null or not _model.is_loaded():
			return 0
		return _model.release_sailors(port_id, n)
