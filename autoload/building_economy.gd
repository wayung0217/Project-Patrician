extends Node
## Autoload: BuildingEconomy — SYS-08 data + build + produce/wage (TechSpec §11–12 WP-18..20).
## _ready() field init only; load_and_validate() builds ST-SLOT (11-03).

signal land_bought(actor: StringName, slot_id: StringName, seq: int)
signal construction_started(bld_id: StringName)
signal construction_waiting(bld_id: StringName, missing: Dictionary)
signal construction_completed(bld_id: StringName)
signal production_shortfall(bld_id: StringName, reason: StringName)

const SYS_ID := &"SYS-08"
const SCRIPT_PATH := "res://autoload/building_economy.gd"

const ZONES_DIR := "res://data/zones/"
const CITY_CENTER_DIR := "res://data/city_center/"
const BUILDINGS_DIR := "res://data/buildings/"
const TRES_SUFFIX := ".tres"
const COMPOSITE_JOINER := "__"

const KIND_WAREHOUSE := GoodsLedger.KIND_WAREHOUSE

const ERR_SYS08_01 := &"ERR-SYS08-01"
const ERR_SYS08_02 := &"ERR-SYS08-02"
const ERR_SYS08_03 := &"ERR-SYS08-03"
const ERR_SYS08_04 := &"ERR-SYS08-04"
const ERR_SYS08_05 := &"ERR-SYS08-05"
const ERR_SYS08_07 := &"ERR-SYS08-07"
const ERR_SYS08_08 := &"ERR-SYS08-08"
const ERR_SYS08_09 := &"ERR-SYS08-09"
const ERR_SYS08_13 := &"ERR-SYS08-13"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_PORT_REGISTRY_NOT_LOADED := &"PORT_REGISTRY_NOT_LOADED"
const CODE_POPULATION_PROVIDER_MISSING := &"POPULATION_PROVIDER_MISSING"
const CODE_WORKFORCE_PROVIDER_MISSING := &"WORKFORCE_PROVIDER_MISSING"

const REASON_LAND_PURCHASE := &"LAND_PURCHASE"
const REASON_CONSTRUCTION := &"CONSTRUCTION"
const REASON_TRADE := &"TRADE"
const REQUESTER_SYS08 := &"SYS-08"
const SHORTFALL_INPUT := &"INPUT"
const SHORTFALL_CAPACITY := &"CAPACITY"

const PRM_BASE_LAND_LI := "PRM-SYS08-BASE_LAND_LI"
const PRM_POP_UNIT := "PRM-SYS08-POP_UNIT"
const PRM_SCARCITY_FLOOR := "PRM-SYS08-SCARCITY_FLOOR"
const PRM_RING_ALPHA := "PRM-SYS08-RING_ALPHA"
const PRM_KONTOR_PLOTS := "PRM-SYS08-KONTOR_PLOTS"
const PRM_KONTOR_CAP := "PRM-SYS08-KONTOR_CAP"
const PRM_WAREHOUSE_CAP := "PRM-SYS08-WAREHOUSE_CAP"
const PRM_BUILD_CASH_LI := "PRM-SYS08-BUILD_CASH_LI"
const PRM_BUILD_MAT := "PRM-SYS08-BUILD_MAT"
const PRM_BUILD_DAYS := "PRM-SYS08-BUILD_DAYS"
const PRM_UPGRADE_PER_CAPITA := "PRM-SYS08-UPGRADE_PER_CAPITA"
const PRM_KONTOR_UPGRADE := "PRM-SYS08-KONTOR_UPGRADE"
const PRM_ACC_SCALE := "PRM-SYS08-ACC_SCALE"
const PRM_OUTPUT_K := "PRM-SYS08-OUTPUT_PER_WORKER_K"
const PRM_RECIPE_N := "PRM-SYS08-RECIPE_KEEP_N"
const PRM_WAGE_SHARE_W := "PRM-SYS08-WAGE_SHARE_W"
const PRM_WAGE_BASE_LI := "PRM-SYS08-WAGE_BASE_LI"
const PRM_DAYS_PER_WEEK := "PRM-SYS04-DAYS_PER_WEEK"

const CLASS_RESIDENCE := &"RESIDENCE"
const CLASS_WAREHOUSE := &"WAREHOUSE"
const CLASS_IND1 := &"IND1"
const CLASS_IND2 := &"IND2"
const CLASS_IND3 := &"IND3"
const CLASS_PUBLIC := &"PUBLIC"
const CLASS_KONTOR := &"KONTOR"

const SLOT_PREFIX := "SLOT:"
const SLOT_ID_FMT := "SLOT:%s:%04d"
const BLD_ID_FMT := "BLD:%s:%04d"

var _slots: Dictionary = {} ## slot_id:String → Slot
var _slots_by_port: Dictionary = {} ## port_id:String → Array[Slot]
var _r_by_port: Dictionary = {} ## port_id:String → int open-zone ring sum
var _max_open_zone: Dictionary = {} ## port_id:String → int (no open → -1)
var _buildings: Dictionary = {} ## bld_id:String → Building
var _buildings_by_port: Dictionary = {} ## port_id:String → Array[Building]
var _building_defs: Dictionary = {} ## type:String → BuildingDef
var _bld_seq_by_port: Dictionary = {} ## port_id:String → int
var _population: PopulationProvider = null
var _workforce: WorkforceProvider = null
var _warehouse_provider: _WarehouseCapacityAdapter = null
var _loaded: bool = false
var _last_error: Dictionary = {}
var _last_errors: Array = []
var _pending_started: Array = []
var _pending_waiting: Array = [] ## {id, missing}
var _pending_completed: Array = []
var _pending_shortfalls: Array = [] ## {id, reason}


func _ready() -> void:
	_clear_state()


func set_population_provider(provider: PopulationProvider) -> void:
	if _loaded:
		push_error("BuildingEconomy.set_population_provider called after load (D-11d); ignored")
		return
	_population = provider


func has_population_provider() -> bool:
	return _population != null


func set_workforce_provider(provider: WorkforceProvider) -> void:
	if _loaded:
		push_error("BuildingEconomy.set_workforce_provider called after load (D-12c); ignored")
		return
	_workforce = provider


func has_workforce_provider() -> bool:
	return _workforce != null


func get_warehouse_capacity_provider() -> CapacityProvider:
	if _warehouse_provider == null:
		_warehouse_provider = _WarehouseCapacityAdapter.new(self)
	return _warehouse_provider


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func last_errors() -> Array:
	## C-06: full validation list from the last order_* call.
	return _last_errors.duplicate(true)


func slot_id(port_id: String, seq_n: int) -> StringName:
	return StringName(SLOT_ID_FMT % [port_id, seq_n])


func load_and_validate(
	zones_dir: String = ZONES_DIR,
	city_center_dir: String = CITY_CENTER_DIR,
	buildings_dir: String = BUILDINGS_DIR
) -> Array:
	var errors: Array = []
	_clear_state()

	if not Params.is_loaded():
		errors.append(
			_err(
				CODE_PARAMS_NOT_LOADED,
				"Params",
				null,
				"Params must load_and_validate before BuildingEconomy"
			)
		)
		_emit_errors(errors)
		return errors

	if not PortRegistry.is_loaded():
		errors.append(
			_err(
				CODE_PORT_REGISTRY_NOT_LOADED,
				"PortRegistry",
				null,
				"PortRegistry must load_and_validate before BuildingEconomy"
			)
		)
		_emit_errors(errors)
		return errors

	if _population == null:
		errors.append(
			_err(
				CODE_POPULATION_PROVIDER_MISSING,
				"PopulationProvider",
				null,
				"PopulationProvider must be injected before load (D-11d)"
			)
		)
		_emit_errors(errors)
		return errors

	if _workforce == null:
		errors.append(
			_err(
				CODE_WORKFORCE_PROVIDER_MISSING,
				"WorkforceProvider",
				null,
				"WorkforceProvider must be injected before load (D-12c)"
			)
		)
		_emit_errors(errors)
		return errors

	# D-12b / D-15b: missing KONTOR_UPGRADE → ERR-SYS08-09 refuse boot (not order-time).
	if not Params.has_prm(PRM_KONTOR_UPGRADE):
		errors.append(
			_err(
				ERR_SYS08_09,
				PRM_KONTOR_UPGRADE,
				null,
				"PRM-SYS08-KONTOR_UPGRADE missing (D-12b／D-15b)"
			)
		)
		_emit_errors(errors)
		return errors

	# D-12g / D-15b: ACC_SCALE registered in WP-20; missing → refuse boot.
	if not Params.has_prm(PRM_ACC_SCALE):
		errors.append(
			_err(
				ERR_SYS08_09,
				PRM_ACC_SCALE,
				null,
				"PRM-SYS08-ACC_SCALE missing (D-12g)"
			)
		)
		_emit_errors(errors)
		return errors

	var zones_by_port: Dictionary = _load_zones(zones_dir, errors)
	var city_by_port: Dictionary = _load_city_centers(city_center_dir, errors)
	_building_defs = _load_building_defs(buildings_dir, errors)
	if not errors.is_empty():
		_emit_errors(errors)
		return errors

	for port_variant in PortRegistry.all_ids():
		var port_id: String = String(port_variant)
		_build_port_slots(port_id, zones_by_port, city_by_port)

	_loaded = true
	return errors


func land_price(slot_key: StringName) -> int:
	assert(_loaded, "BuildingEconomy.land_price before load")
	_clear_last_error()
	var slot: Slot = _slot(slot_key)
	if slot == null:
		_record_fail(ERR_SYS08_08, "slot_id", slot_key, "unknown slot")
		return 0

	var port_id: String = slot.port_id
	var base_li: int = Params.get_int(PRM_BASE_LAND_LI)
	var pop_unit: int = Params.get_int(PRM_POP_UNIT)
	var pop: int = _population.population(StringName(port_id))
	if pop < PopulationProvider.POPULATION_FAILURE + 1:
		_record_fail(ERR_SYS08_08, "population", port_id, "population provider failure")
		return 0

	var scarcity: float = 1.0
	var ring_f: float = 1.0
	if slot.kind == Slot.Kind.KONTOR or slot.kind == Slot.Kind.PUBLIC:
		scarcity = 1.0
		ring_f = 1.0
	else:
		scarcity = _scarcity_civil(port_id, slot.zone)
		var r_total: int = int(_r_by_port.get(port_id, 0))
		var alpha: float = Params.get_float(PRM_RING_ALPHA)
		var ring_base: float = 1.0 + float(r_total - slot.ring)
		if ring_base < 1.0:
			ring_base = 1.0
		ring_f = pow(ring_base, alpha)
		if ring_f < 1.0:
			ring_f = 1.0

	var pop_ratio: float = float(pop) / float(pop_unit)
	var mid: float = float(base_li) * sqrt(pop_ratio) * scarcity * ring_f
	var q: float = AmountQuantize.quantize_amount(mid)
	return ceili(q)


func buy_land(actor: StringName, slot_key: StringName) -> int:
	assert(_loaded, "BuildingEconomy.buy_land before load")
	_clear_last_error()
	var slot: Slot = _slot(slot_key)
	if slot == null:
		return _fail(ERR_SYS08_08, "slot_id", slot_key, "unknown slot")

	# D-12a: open zone OR gathering belt (only when ≥1 zone already open).
	if slot.kind == Slot.Kind.CIVIL and not slot.zone_open and not _is_gathering_belt(slot):
		return _fail(ERR_SYS08_01, "zone_open", slot.zone, "zone not open")

	var city_id: StringName = CashLedger.make_city_id(slot.port_id)
	if slot.land_owner != city_id:
		return _fail(ERR_SYS08_02, "land_owner", slot.land_owner, "not city-owned")
	if slot.building_id != &"":
		return _fail(ERR_SYS08_02, "building_id", slot.building_id, "slot has building")

	var price: int = land_price(slot_key)
	if price <= 0:
		if _last_error.is_empty():
			_record_fail(ERR_SYS08_07, "price", price, "land_price failed")
		return 0

	CashLedger.create_account(city_id, Account.Kind.CITY)

	var post_err: Error = CashLedger.post(
		[
			CashLedger.make_entry(actor, 0 - price),
			CashLedger.make_entry(city_id, price),
		],
		REASON_LAND_PURCHASE,
		REQUESTER_SYS08
	)
	if post_err != OK:
		return _fail(ERR_SYS08_07, "post", price, "land purchase post failed")

	slot.land_owner = actor
	var seq: int = 0
	if CashLedger._postings.size() > 0:
		seq = int((CashLedger._postings[CashLedger._postings.size() - 1] as Posting).seq)
	land_bought.emit(actor, slot_key, seq)
	return seq


func order_build(actor: StringName, slot_key: StringName, type_id: StringName) -> StringName:
	assert(_loaded, "BuildingEconomy.order_build before load")
	_clear_last_error()
	var errs: Array = _validate_order_build(actor, slot_key, type_id)
	_last_errors = errs
	if not errs.is_empty():
		_last_error = (errs[0] as Dictionary).duplicate(true)
		for e in errs:
			push_error("BuildingEconomy: %s" % str(e))
		return &""

	var slot: Slot = _slot(slot_key)
	var def: BuildingDef = _building_defs[String(type_id)] as BuildingDef
	var build_class: StringName = StringName(def.build_class)
	var cash_map: Dictionary = Params.get_value(PRM_BUILD_CASH_LI)
	var cash_li: int = int(cash_map[String(build_class)])
	var mat_root: Dictionary = Params.get_value(PRM_BUILD_MAT)
	var mat_need: Dictionary = (mat_root[String(build_class)] as Dictionary).duplicate(true)
	var days_map: Dictionary = Params.get_value(PRM_BUILD_DAYS)
	var build_days: int = int(days_map[String(build_class)])

	var post_err: Error = CashLedger.post(
		[
			CashLedger.make_entry(actor, 0 - cash_li),
			CashLedger.make_entry(CashLedger.ID_SINK, cash_li),
		],
		REASON_CONSTRUCTION,
		REQUESTER_SYS08
	)
	if post_err != OK:
		return StringName(_fail_sn(ERR_SYS08_07, "post", cash_li, "construction cash post failed"))

	var bld := Building.new()
	bld.building_id = _next_bld_id(slot.port_id)
	bld.type = type_id
	bld.build_class = build_class
	bld.owner = actor
	bld.port_id = slot.port_id
	bld.slot_id = slot_key
	bld.level = 1
	bld.days_left = build_days
	if build_class == CLASS_PUBLIC:
		bld.cb_id = type_id

	var missing: Dictionary = _apply_acquire(actor, slot.port_id, mat_need, bld.locked_materials)
	bld.missing_materials = missing
	if missing.is_empty():
		bld.state = Building.State.BUILDING
	else:
		bld.state = Building.State.WAITING_MATERIAL

	slot.building_id = bld.building_id
	slot.vacancy_start_day = -1
	_register_building(bld)

	if bld.state == Building.State.BUILDING:
		construction_started.emit(bld.building_id)
	else:
		construction_waiting.emit(bld.building_id, missing.duplicate(true))
	return bld.building_id


func order_upgrade(actor: StringName, bld_key: StringName) -> StringName:
	assert(_loaded, "BuildingEconomy.order_upgrade before load")
	_clear_last_error()
	var bld: Building = _building(bld_key)
	if bld == null:
		return StringName(_fail_sn(ERR_SYS08_08, "bld_id", bld_key, "unknown building"))
	if bld.owner != actor:
		return StringName(_fail_sn(ERR_SYS08_05, "owner", bld.owner, "not building owner"))
	if bld.state != Building.State.ACTIVE:
		return StringName(_fail_sn(ERR_SYS08_03, "state", bld.state, "upgrade only from ACTIVE"))
	if bld.level >= 3:
		return StringName(_fail_sn(ERR_SYS08_03, "level", bld.level, "already level 3"))

	var to_level: int = bld.level + 1
	var cash_li := 0
	var mat_need: Dictionary = {}
	var build_days := 0

	if bld.build_class == CLASS_KONTOR:
		if not Params.has_prm(PRM_KONTOR_UPGRADE):
			return StringName(
				_fail_sn(ERR_SYS08_09, PRM_KONTOR_UPGRADE, null, "KONTOR_UPGRADE missing (G-02)")
			)
		var arr: Array = Params.get_value(PRM_KONTOR_UPGRADE)
		var idx: int = to_level - 2
		if idx < 0 or idx >= arr.size():
			return StringName(_fail_sn(ERR_SYS08_09, "level", to_level, "KONTOR_UPGRADE index"))
		var row: Dictionary = arr[idx]
		cash_li = int(row.get("CASH_LI", 0))
		build_days = int(row.get("DAYS", 1))
		for k in row.keys():
			var ks := String(k)
			if ks == "CASH_LI" or ks == "DAYS":
				continue
			mat_need[ks] = int(row[k])
	elif bld.build_class == CLASS_PUBLIC:
		var fee: Dictionary = public_upgrade_fee(StringName(bld.port_id), to_level)
		cash_li = int(fee.get("CASH_LI", 0))
		mat_need = (fee.get("MAT", {}) as Dictionary).duplicate(true)
		var days_map: Dictionary = Params.get_value(PRM_BUILD_DAYS)
		build_days = int(days_map[String(CLASS_PUBLIC)])
	elif (
		bld.build_class == CLASS_RESIDENCE
		or bld.build_class == CLASS_IND1
		or bld.build_class == CLASS_IND2
		or bld.build_class == CLASS_IND3
		or bld.build_class == CLASS_WAREHOUSE
	):
		return StringName(_fail_sn(ERR_SYS08_03, "build_class", bld.build_class, "upgrade not allowed"))
	else:
		return StringName(_fail_sn(ERR_SYS08_03, "build_class", bld.build_class, "upgrade not allowed"))

	var post_err: Error = CashLedger.post(
		[
			CashLedger.make_entry(actor, 0 - cash_li),
			CashLedger.make_entry(CashLedger.ID_SINK, cash_li),
		],
		REASON_CONSTRUCTION,
		REQUESTER_SYS08
	)
	if post_err != OK:
		return StringName(_fail_sn(ERR_SYS08_07, "post", cash_li, "upgrade cash post failed"))

	bld.locked_materials = {}
	bld.missing_materials = {}
	bld.days_left = build_days
	bld.level = to_level
	var missing: Dictionary = _apply_acquire(actor, bld.port_id, mat_need, bld.locked_materials)
	bld.missing_materials = missing
	if missing.is_empty():
		bld.state = Building.State.BUILDING
		construction_started.emit(bld.building_id)
	else:
		bld.state = Building.State.WAITING_MATERIAL
		construction_waiting.emit(bld.building_id, missing.duplicate(true))
	return bld.building_id


func public_upgrade_fee(port_id: StringName, to_level: int) -> Dictionary:
	## FRM-07: pop × UPGRADE_PER_CAPITA[level]; cash CEIL to li; mats CEIL to 擔.
	assert(_loaded, "BuildingEconomy.public_upgrade_fee before load")
	var pop: int = _population.population(port_id)
	var arr: Array = Params.get_value(PRM_UPGRADE_PER_CAPITA)
	var idx: int = to_level - 2
	var out := {"CASH_LI": 0, "MAT": {}}
	if idx < 0 or idx >= arr.size():
		return out
	var row: Dictionary = arr[idx]
	var cash_per: int = int(row.get("CASH_LI", 0))
	out["CASH_LI"] = ceili(AmountQuantize.quantize_amount(float(pop) * float(cash_per)))
	var mats: Dictionary = {}
	for k in row.keys():
		var ks := String(k)
		if ks == "CASH_LI":
			continue
		var per: float = float(row[k])
		mats[ks] = ceili(AmountQuantize.quantize_amount(float(pop) * per))
	out["MAT"] = mats
	return out


func pause(actor: StringName, bld_key: StringName) -> int:
	## FRM-23: ACTIVE → PAUSED.
	assert(_loaded, "BuildingEconomy.pause before load")
	_clear_last_error()
	var bld: Building = _building(bld_key)
	if bld == null:
		return _fail(ERR_SYS08_08, "bld_id", bld_key, "unknown building")
	if bld.owner != actor:
		return _fail(ERR_SYS08_05, "owner", bld.owner, "not building owner")
	if bld.state != Building.State.ACTIVE:
		return _fail(ERR_SYS08_03, "state", bld.state, "pause only from ACTIVE")
	bld.state = Building.State.PAUSED
	return 1


func resume(actor: StringName, bld_key: StringName) -> int:
	## FRM-23: PAUSED → ACTIVE.
	assert(_loaded, "BuildingEconomy.resume before load")
	_clear_last_error()
	var bld: Building = _building(bld_key)
	if bld == null:
		return _fail(ERR_SYS08_08, "bld_id", bld_key, "unknown building")
	if bld.owner != actor:
		return _fail(ERR_SYS08_05, "owner", bld.owner, "not building owner")
	if bld.state != Building.State.PAUSED:
		return _fail(ERR_SYS08_03, "state", bld.state, "resume only from PAUSED")
	bld.state = Building.State.ACTIVE
	return 1


func demolish(actor: StringName, bld_key: StringName) -> int:
	assert(_loaded, "BuildingEconomy.demolish before load")
	_clear_last_error()
	var bld: Building = _building(bld_key)
	if bld == null:
		return _fail(ERR_SYS08_08, "bld_id", bld_key, "unknown building")
	if bld.owner != actor:
		return _fail(ERR_SYS08_05, "owner", bld.owner, "not building owner")
	# 12-07: demolish kontor not open this period → ERR-03 (gap: hold inventory).
	if bld.build_class == CLASS_KONTOR:
		return _fail(ERR_SYS08_03, "build_class", CLASS_KONTOR, "demolish kontor not open (gap)")

	var slot: Slot = _slot(bld.slot_id)
	if slot != null:
		slot.building_id = &""
		slot.vacancy_start_day = Clock.day if Clock != null else 0

	# WP-21／OQ-13w: queue workforce release for PopulationModel next daily_step.
	if PopulationModel != null and PopulationModel.is_loaded():
		PopulationModel.release_workshop_workers(StringName(bld.port_id), bld.building_id)

	var key := String(bld.building_id)
	_buildings.erase(key)
	var port_arr: Array = _buildings_by_port.get(bld.port_id, [])
	var i := 0
	while i < port_arr.size():
		if (port_arr[i] as Building).building_id == bld.building_id:
			port_arr.remove_at(i)
			break
		i = i + 1
	return 1


func daily_step(day: int) -> Array:
	## D-12h / 8.6 F: ① construction → ② workshop produce → ④ wage accrue.
	## day kept for callers; production uses Clock-independent FRM-08..12 math.
	assert(_loaded, "BuildingEconomy.daily_step before load")
	var _day_unused: int = day
	var errors: Array = []
	_step_construction(errors)
	_step_produce(errors)
	_step_wage_accrual()
	return errors


func flush_signals() -> void:
	## D-12h: emit queued daily construction / shortfall signals (SimLoop step 6).
	for id_variant in _pending_started:
		construction_started.emit(id_variant as StringName)
	for item_variant in _pending_waiting:
		var item: Dictionary = item_variant
		construction_waiting.emit(item["id"] as StringName, item["missing"] as Dictionary)
	for id_variant in _pending_completed:
		construction_completed.emit(id_variant as StringName)
	for item_variant2 in _pending_shortfalls:
		var sf: Dictionary = item_variant2
		production_shortfall.emit(sf["id"] as StringName, sf["reason"] as StringName)
	_pending_started = []
	_pending_waiting = []
	_pending_completed = []
	_pending_shortfalls = []


func _step_construction(_errors: Array) -> void:
	var ids: Array = _buildings.keys()
	ids.sort()
	for id_variant in ids:
		var bld: Building = _buildings[String(id_variant)] as Building
		if bld.state == Building.State.WAITING_MATERIAL:
			var mat_root: Dictionary = Params.get_value(PRM_BUILD_MAT)
			var need: Dictionary = {}
			if bld.missing_materials.is_empty():
				need = (mat_root[String(bld.build_class)] as Dictionary).duplicate(true)
				for g in bld.locked_materials.keys():
					var gs := String(g)
					need[gs] = int(need.get(gs, 0)) - int(bld.locked_materials[g])
					if int(need[gs]) <= 0:
						need.erase(gs)
			else:
				need = bld.missing_materials.duplicate(true)
			var still: Dictionary = _apply_acquire(
				bld.owner, bld.port_id, need, bld.locked_materials
			)
			bld.missing_materials = still
			if still.is_empty():
				var days_map: Dictionary = Params.get_value(PRM_BUILD_DAYS)
				bld.days_left = int(days_map[String(bld.build_class)])
				bld.state = Building.State.BUILDING
				_pending_started.append(bld.building_id)
			else:
				_pending_waiting.append({"id": bld.building_id, "missing": still.duplicate(true)})
		elif bld.state == Building.State.BUILDING:
			bld.days_left = bld.days_left - 1
			if bld.days_left <= 0:
				bld.days_left = 0
				bld.state = Building.State.ACTIVE
				bld.missing_materials = {}
				_pending_completed.append(bld.building_id)


func _step_produce(errors: Array) -> void:
	## 12-10 / FRM-08..11: ports ↑, then tier → output_good_id → bld_id ↑ (Q-08e).
	var jobs: Array = []
	for id_variant in _buildings.keys():
		var bld: Building = _buildings[String(id_variant)] as Building
		if not _is_workshop(bld):
			continue
		if bld.state != Building.State.ACTIVE:
			continue
		var def: BuildingDef = _building_defs.get(String(bld.type), null) as BuildingDef
		if def == null:
			continue
		jobs.append({"bld": bld, "def": def})
	jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ba: Building = a["bld"]
		var bb: Building = b["bld"]
		var da: BuildingDef = a["def"]
		var db: BuildingDef = b["def"]
		if ba.port_id != bb.port_id:
			return ba.port_id < bb.port_id
		if da.tier != db.tier:
			return da.tier < db.tier
		if da.output_good_id != db.output_good_id:
			return da.output_good_id < db.output_good_id
		return String(ba.building_id) < String(bb.building_id)
	)
	for job_variant in jobs:
		var job: Dictionary = job_variant
		_produce_workshop(job["bld"] as Building, job["def"] as BuildingDef, errors)


func _step_wage_accrual() -> void:
	## 12-11 / FRM-12 daily: player ACTIVE workshops only; PAUSED skips; city skips.
	var ids: Array = _buildings.keys()
	ids.sort()
	var k_out: float = Params.get_float(PRM_OUTPUT_K)
	var wage_w: float = Params.get_float(PRM_WAGE_SHARE_W)
	var wage_base: int = Params.get_int(PRM_WAGE_BASE_LI)
	var acc_scale: int = Params.get_int(PRM_ACC_SCALE)
	var k_pow: float = pow(k_out, wage_w)
	for id_variant in ids:
		var bld: Building = _buildings[String(id_variant)] as Building
		if not _is_workshop(bld):
			continue
		if bld.state != Building.State.ACTIVE:
			continue
		if _is_city_owner(bld.owner):
			continue
		var workers: int = _workers_of(bld.building_id)
		if workers <= 0:
			continue
		var mid: float = float(workers) * float(wage_base) * k_pow * float(acc_scale)
		bld.acc_wage_li = bld.acc_wage_li + floori(AmountQuantize.quantize_amount(mid))


func _produce_workshop(bld: Building, def: BuildingDef, errors: Array) -> void:
	var workers: int = _workers_of(bld.building_id)
	var k_out: float = Params.get_float(PRM_OUTPUT_K)
	var recipe_n: float = Params.get_float(PRM_RECIPE_N)
	var acc_scale: int = Params.get_int(PRM_ACC_SCALE)
	var days_pw: int = Params.get_int(PRM_DAYS_PER_WEEK)
	var denom: int = days_pw * acc_scale

	# FRM-08 potential
	var w_week: float = float(workers) * float(def.base_output_per_worker) * k_out
	bld.acc_out = bld.acc_out + floori(AmountQuantize.quantize_amount(w_week * float(acc_scale)))
	var out_pot: int = 0
	if denom > 0:
		out_pot = int(bld.acc_out / denom)
	bld.acc_out = bld.acc_out - out_pot * denom

	var is_city: bool = _is_city_owner(bld.owner)
	var src: Dictionary
	var dst: Dictionary
	if is_city:
		src = GoodsLedger.make_market(bld.port_id)
		dst = src
	else:
		src = GoodsLedger.make_warehouse(String(bld.owner), bld.port_id)
		dst = src

	# FRM-09 feasibility
	var out_feas: int = out_pot
	var inputs: Array = _recipe_inputs(def)
	if not inputs.is_empty():
		out_feas = 0x7fffffff
		for inp_variant in inputs:
			var inp: Dictionary = inp_variant
			var avail: int = GoodsLedger.get_qty(src, StringName(String(inp["good"])))
			var per: float = float(inp["qty"]) * recipe_n
			if per <= 0.0:
				continue
			var feas_i: int = floori(AmountQuantize.quantize_amount(float(avail) / per))
			if feas_i < out_feas:
				out_feas = feas_i
		if out_feas == 0x7fffffff:
			out_feas = out_pot

	# FRM-10 capacity
	var out_cap: int = out_pot
	if not is_city:
		var cap: int = warehouse_capacity(bld.owner, StringName(bld.port_id))
		var used: int = _warehouse_used(bld.owner, bld.port_id)
		out_cap = cap - used
		if out_cap < 0:
			out_cap = 0

	var out: int = out_pot
	if out_feas < out:
		out = out_feas
	if out_cap < out:
		out = out_cap
	if out < 0:
		out = 0

	if out < out_pot:
		var reason: StringName = SHORTFALL_INPUT
		if out_cap < out_feas:
			reason = SHORTFALL_CAPACITY
		_pending_shortfalls.append({"id": bld.building_id, "reason": reason})

	if out <= 0:
		return

	# FRM-11 consume then produce
	for inp_variant2 in inputs:
		var inp2: Dictionary = inp_variant2
		var take: int = ceili(
			AmountQuantize.quantize_amount(float(out) * float(inp2["qty"]) * recipe_n)
		)
		if take <= 0:
			continue
		var seq_c: int = GoodsLedger.transfer(
			src,
			GoodsLedger.make_external(),
			StringName(String(inp2["good"])),
			take,
			GoodsLedger.REASON_CONSUME,
			REQUESTER_SYS08
		)
		if seq_c <= 0:
			errors.append(GoodsLedger.last_error())

	var out_good: String = def.output_good_id
	if out_good.is_empty():
		return
	var seq_p: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		dst,
		StringName(out_good),
		out,
		GoodsLedger.REASON_PRODUCE,
		REQUESTER_SYS08
	)
	if seq_p <= 0:
		errors.append(GoodsLedger.last_error())


func _is_workshop(bld: Building) -> bool:
	return (
		bld.build_class == CLASS_IND1
		or bld.build_class == CLASS_IND2
		or bld.build_class == CLASS_IND3
	)


func _is_city_owner(owner: StringName) -> bool:
	return String(owner).begins_with("CITY-")


func _workers_of(ws_id: StringName) -> int:
	var n: int = _workforce.workers(ws_id)
	if n < WorkforceProvider.WORKERS_FAILURE + 1:
		return 0
	return n


func _recipe_inputs(def: BuildingDef) -> Array:
	var out: Array = []
	if not def.input1_good_id.is_empty() and def.input1_qty > 0:
		out.append({"good": def.input1_good_id, "qty": def.input1_qty})
	if not def.input2_good_id.is_empty() and def.input2_qty > 0:
		out.append({"good": def.input2_good_id, "qty": def.input2_qty})
	return out


func _warehouse_used(owner: StringName, port_id: String) -> int:
	var wh: Dictionary = GoodsLedger.make_warehouse(String(owner), port_id)
	var sum := 0
	for good_variant in GoodCatalog.all_ids():
		sum = sum + GoodsLedger.get_qty(wh, StringName(String(good_variant)))
	return sum


func warehouse_capacity(actor: StringName, port: StringName) -> int:
	assert(_loaded, "BuildingEconomy.warehouse_capacity before load")
	var level := 0
	var wh_count := 0
	for bld_variant in _buildings_by_port.get(String(port), []):
		var bld: Building = bld_variant
		if bld.owner != actor:
			continue
		if bld.state != Building.State.ACTIVE:
			continue
		if bld.build_class == CLASS_KONTOR:
			if bld.level > level:
				level = bld.level
		elif bld.build_class == CLASS_WAREHOUSE:
			wh_count = wh_count + 1
	if level <= 0:
		return 0
	var caps: Array = Params.get_value(PRM_KONTOR_CAP)
	var idx: int = level - 1
	if idx < 0 or idx >= caps.size():
		return 0
	var base: int = int(caps[idx])
	var per: int = Params.get_int(PRM_WAREHOUSE_CAP)
	return base + wh_count * per


func capacity(container: Variant) -> int:
	return warehouse_capacity_for_container(container)


func warehouse_capacity_for_container(container: Variant) -> int:
	if typeof(container) != TYPE_DICTIONARY:
		return CapacityProvider.CAPACITY_FAILURE
	var d: Dictionary = container
	if String(d.get(GoodsLedger.KEY_KIND, "")) != KIND_WAREHOUSE:
		return CapacityProvider.CAPACITY_FAILURE
	var owner: String = String(d.get(GoodsLedger.KEY_OWNER, ""))
	var port: String = String(d.get(GoodsLedger.KEY_PORT, ""))
	return warehouse_capacity(StringName(owner), StringName(port))


func workplaces(port: StringName) -> Array:
	assert(_loaded, "BuildingEconomy.workplaces before load")
	var out: Array = []
	for bld_variant in _buildings_by_port.get(String(port), []):
		var bld: Building = bld_variant
		if bld.state != Building.State.ACTIVE:
			continue
		if (
			bld.build_class == CLASS_IND1
			or bld.build_class == CLASS_IND2
			or bld.build_class == CLASS_IND3
		):
			out.append(bld)
	return out


func residences(port: StringName) -> Array:
	assert(_loaded, "BuildingEconomy.residences before load")
	var out: Array = []
	for bld_variant in _buildings_by_port.get(String(port), []):
		var bld: Building = bld_variant
		if bld.state != Building.State.ACTIVE:
			continue
		if bld.build_class == CLASS_RESIDENCE:
			out.append(bld)
	return out


func public_level(port: StringName, cb: StringName) -> int:
	assert(_loaded, "BuildingEconomy.public_level before load")
	var best := 0
	for bld_variant in _buildings_by_port.get(String(port), []):
		var bld: Building = bld_variant
		if bld.state != Building.State.ACTIVE:
			continue
		if bld.build_class != CLASS_PUBLIC:
			continue
		if bld.cb_id != cb and bld.type != cb:
			continue
		if bld.level > best:
			best = bld.level
	return best


func ring_count_open(_port_id: String) -> int:
	return int(_r_by_port.get(_port_id, 0))


func slots_for_port(_port_id: String) -> Array:
	return _slots_by_port.get(_port_id, [])


func get_slot(slot_key: StringName) -> Slot:
	return _slot(slot_key)


func get_building(bld_key: StringName) -> Building:
	return _building(bld_key)


func buildings_for_port(port_id: String) -> Array:
	return _buildings_by_port.get(port_id, [])


func is_gathering_belt_slot(slot_key: StringName) -> bool:
	var slot: Slot = _slot(slot_key)
	if slot == null:
		return false
	return _is_gathering_belt(slot)


func _validate_order_build(actor: StringName, slot_key: StringName, type_id: StringName) -> Array:
	## 12-03 check order; C-06 collect all.
	var errs: Array = []
	var slot: Slot = _slot(slot_key)
	var type_s := String(type_id)
	var def: BuildingDef = null
	if slot == null:
		errs.append(_err(ERR_SYS08_08, "slot_id", slot_key, "unknown slot"))
	if not _building_defs.has(type_s):
		errs.append(_err(ERR_SYS08_08, "type", type_id, "unknown type"))
	else:
		def = _building_defs[type_s] as BuildingDef

	if slot == null or def == null:
		return errs

	var build_class: StringName = StringName(def.build_class)
	var city_id: StringName = CashLedger.make_city_id(slot.port_id)

	# ERR-05 owner
	if build_class == CLASS_PUBLIC:
		if actor != city_id:
			errs.append(_err(ERR_SYS08_05, "actor", actor, "PUBLIC requires CITY actor"))
	else:
		if slot.land_owner != actor:
			errs.append(_err(ERR_SYS08_05, "land_owner", slot.land_owner, "not land owner"))

	# ERR-02 occupied
	if slot.building_id != &"":
		errs.append(_err(ERR_SYS08_02, "building_id", slot.building_id, "slot has building"))

	# ERR-01 zone
	if slot.kind == Slot.Kind.CIVIL and not slot.zone_open and not _is_gathering_belt(slot):
		errs.append(_err(ERR_SYS08_01, "zone_open", slot.zone, "zone not open"))

	# ERR-03 placement rules
	if not _placement_ok(slot, build_class, def, errs):
		pass

	# ERR-04 kontor uniqueness / plots
	if build_class == CLASS_KONTOR:
		if slot.kind != Slot.Kind.KONTOR:
			errs.append(_err(ERR_SYS08_03, "slot.kind", slot.kind, "KONTOR only on kontor plots"))
		var existing := 0
		for bld_variant in _buildings_by_port.get(slot.port_id, []):
			var b: Building = bld_variant
			if b.owner == actor and b.build_class == CLASS_KONTOR:
				existing = existing + 1
		if existing > 0:
			errs.append(_err(ERR_SYS08_04, "kontor", actor, "actor already has kontor in port"))
		var used_plots := 0
		for bld_variant2 in _buildings_by_port.get(slot.port_id, []):
			var b2: Building = bld_variant2
			if b2.build_class == CLASS_KONTOR:
				used_plots = used_plots + 1
		var plot_cap: int = Params.get_int(PRM_KONTOR_PLOTS)
		if used_plots >= plot_cap:
			errs.append(_err(ERR_SYS08_04, "kontor_plots", used_plots, "kontor plots full"))

	# ERR-13 kontor prerequisite (D-12f); city public exempt; kontor itself exempt
	if build_class != CLASS_KONTOR and build_class != CLASS_PUBLIC:
		if not _has_active_kontor(actor, slot.port_id):
			errs.append(
				_err(ERR_SYS08_13, "kontor", actor, "need active own kontor in port (D-12f)")
			)

	# ERR-07 cash (pre-check; post still authoritative)
	if Params.has_prm(PRM_BUILD_CASH_LI):
		var cash_map: Dictionary = Params.get_value(PRM_BUILD_CASH_LI)
		var need_cash: int = int(cash_map.get(String(build_class), 0))
		if CashLedger.has_method("balance") and CashLedger.balance(actor) < need_cash:
			errs.append(_err(ERR_SYS08_07, "cash", need_cash, "insufficient cash for BUILD_CASH"))

	return errs


func _placement_ok(slot: Slot, build_class: StringName, def: BuildingDef, errs: Array) -> bool:
	var ok := true
	var on_belt: bool = _is_gathering_belt(slot)
	if build_class == CLASS_IND1:
		if not on_belt:
			errs.append(_err(ERR_SYS08_03, "build_class", build_class, "IND1 only on gathering belt"))
			ok = false
		if slot.kind != Slot.Kind.CIVIL:
			errs.append(_err(ERR_SYS08_03, "slot.kind", slot.kind, "IND1 needs CIVIL slot"))
			ok = false
	elif (
		build_class == CLASS_IND2
		or build_class == CLASS_IND3
		or build_class == CLASS_RESIDENCE
		or build_class == CLASS_WAREHOUSE
	):
		if on_belt or (slot.kind == Slot.Kind.CIVIL and not slot.zone_open):
			errs.append(
				_err(ERR_SYS08_03, "zone", slot.zone, "civilian types need open city zone")
			)
			ok = false
		if slot.kind != Slot.Kind.CIVIL:
			errs.append(_err(ERR_SYS08_03, "slot.kind", slot.kind, "civilian types need CIVIL"))
			ok = false
	elif build_class == CLASS_KONTOR:
		if slot.kind != Slot.Kind.KONTOR:
			errs.append(_err(ERR_SYS08_03, "slot.kind", slot.kind, "KONTOR only on kontor plots"))
			ok = false
	elif build_class == CLASS_PUBLIC:
		if slot.kind != Slot.Kind.PUBLIC:
			errs.append(_err(ERR_SYS08_03, "slot.kind", slot.kind, "PUBLIC only on public slots"))
			ok = false
	else:
		errs.append(_err(ERR_SYS08_03, "build_class", build_class, "unknown build_class"))
		ok = false

	# Workshop must be PRODUCER specialty for output good
	if build_class == CLASS_IND1 or build_class == CLASS_IND2 or build_class == CLASS_IND3:
		var out_g: String = def.output_good_id
		if out_g != "":
			var role: int = PortRegistry.get_role(slot.port_id, out_g)
			if role != PortRegistry.ROLE_PRODUCER:
				errs.append(
					_err(ERR_SYS08_03, "output_good_id", out_g, "port not PRODUCER for good")
				)
				ok = false

	# Warehouse requires own active kontor (also covered by ERR-13; keep 03 for placement)
	if build_class == CLASS_WAREHOUSE:
		if not _has_active_kontor(slot.land_owner, slot.port_id):
			errs.append(_err(ERR_SYS08_03, "warehouse", slot.port_id, "warehouse needs own kontor"))
			ok = false

	return ok


func _has_active_kontor(actor: StringName, port_id: String) -> bool:
	for bld_variant in _buildings_by_port.get(port_id, []):
		var bld: Building = bld_variant
		if bld.owner == actor and bld.build_class == CLASS_KONTOR and bld.state == Building.State.ACTIVE:
			return true
	return false


func _is_gathering_belt(slot: Slot) -> bool:
	if slot.kind != Slot.Kind.CIVIL:
		return false
	if slot.zone_open:
		return false
	var max_open: int = int(_max_open_zone.get(slot.port_id, -1))
	if max_open < 0:
		# No open zone → no gathering belt (preserves TST-SYS08-02).
		return false
	return slot.zone == max_open + 1


func _apply_acquire(actor: StringName, port_id: String, need: Dictionary, locked: Dictionary) -> Dictionary:
	## Call public acquire_materials (D-17b); fold acquired amounts into locked.
	var result: Dictionary = acquire_materials(actor, StringName(port_id), need)
	var missing: Dictionary = result["missing"] as Dictionary
	for g_variant in need.keys():
		var g: String = String(g_variant)
		var want: int = int(need[g])
		var rem: int = int(missing.get(g, 0))
		var got: int = want - rem
		if got > 0:
			locked[g] = int(locked.get(g, 0)) + got
	return missing


func acquire_materials(actor: StringName, port_id: StringName, needs: Dictionary) -> Dictionary:
	## D-17b public BC-2 entry: {acquired: bool, missing: Dictionary}.
	## Materials are CONSTRUCT_USE'd; caller tracks locked = need − missing.
	var locked: Dictionary = {}
	var missing: Dictionary = _acquire_materials_into(
		actor, String(port_id), needs.duplicate(true), locked
	)
	return {"acquired": missing.is_empty(), "missing": missing.duplicate(true)}


func _acquire_materials_into(
	actor: StringName, port_id: String, need: Dictionary, locked: Dictionary
) -> Dictionary:
	## BC-2 + D-12e: per good ascending; warehouse then market CONSTRUCT_USE; missing → WAITING.
	var missing: Dictionary = {}
	var goods: Array = need.keys()
	goods.sort()
	var is_city: bool = String(actor).begins_with("CITY-")
	for g_variant in goods:
		var g: String = String(g_variant)
		var want: int = int(need[g])
		if want <= 0:
			continue
		var got := 0
		if not is_city:
			var wh: Dictionary = GoodsLedger.make_warehouse(String(actor), port_id)
			var have: int = GoodsLedger.get_qty(wh, StringName(g))
			var take: int = mini(have, want)
			if take > 0:
				var seq_w: int = GoodsLedger.transfer(
					wh,
					GoodsLedger.make_external(),
					StringName(g),
					take,
					GoodsLedger.REASON_CONSTRUCT_USE,
					REQUESTER_SYS08
				)
				if seq_w > 0:
					got = got + take
					locked[g] = int(locked.get(g, 0)) + take
		var still: int = want - got
		if still > 0:
			var market: Dictionary = GoodsLedger.make_market(port_id)
			var mstock: int = GoodsLedger.get_qty(market, StringName(g))
			var buy_qty: int = mini(still, mstock)
			if buy_qty > 0:
				var quote: Dictionary = MarketPricer.quote(
					StringName(port_id), StringName(g), MarketPricer.SIDE_BUY, buy_qty
				)
				if not quote.has(MarketPricer.KEY_ERROR):
					var price: int = int(quote[MarketPricer.KEY_TOTAL_LI])
					var bal: int = CashLedger.balance(actor)
					if bal >= price:
						var cash_rc: Error = CashLedger.post(
							[
								CashLedger.make_entry(actor, 0 - price),
								CashLedger.make_entry(CashLedger.ID_SINK, price),
							],
							REASON_TRADE,
							REQUESTER_SYS08
						)
						if cash_rc == OK:
							var seq_m: int = GoodsLedger.transfer(
								market,
								GoodsLedger.make_external(),
								StringName(g),
								buy_qty,
								GoodsLedger.REASON_CONSTRUCT_USE,
								REQUESTER_SYS08
							)
							if seq_m > 0:
								got = got + buy_qty
								locked[g] = int(locked.get(g, 0)) + buy_qty
		var rem: int = want - got
		if rem > 0:
			missing[g] = rem
	return missing


func _next_bld_id(port_id: String) -> StringName:
	var n: int = int(_bld_seq_by_port.get(port_id, 0)) + 1
	_bld_seq_by_port[port_id] = n
	return StringName(BLD_ID_FMT % [port_id, n])


func _register_building(bld: Building) -> void:
	var key := String(bld.building_id)
	_buildings[key] = bld
	if not _buildings_by_port.has(bld.port_id):
		_buildings_by_port[bld.port_id] = []
	(_buildings_by_port[bld.port_id] as Array).append(bld)


func _building(bld_key: StringName) -> Building:
	var key := String(bld_key)
	if not _buildings.has(key):
		return null
	return _buildings[key] as Building


func _build_port_slots(
	port_id: String,
	zones_by_port: Dictionary,
	city_by_port: Dictionary
) -> void:
	var city_id: StringName = CashLedger.make_city_id(port_id)
	var seq: int = 1
	var port_slots: Array = []
	var ring_global: int = 0
	var r_open: int = 0
	var max_open: int = -1

	var zone_rows: Array = zones_by_port.get(port_id, [])
	zone_rows.sort_custom(func(a: ZoneDef, b: ZoneDef) -> bool: return a.zone < b.zone)

	for zd_variant in zone_rows:
		var zd: ZoneDef = zd_variant
		if zd.open_at_start == 1:
			r_open = r_open + zd.rings
			if zd.zone > max_open:
				max_open = zd.zone
		var per_ring: Array = _split_slots_even(zd.slots, zd.rings)
		for local_ring in range(zd.rings):
			var global_ring: int = ring_global + local_ring + 1
			var count: int = int(per_ring[local_ring])
			for _j in range(count):
				var s := Slot.new()
				s.kind = Slot.Kind.CIVIL
				s.port_id = port_id
				s.zone = zd.zone
				s.ring = global_ring
				s.land_owner = city_id
				s.building_id = &""
				s.zone_open = zd.open_at_start == 1
				s.slot_id = slot_id(port_id, seq)
				seq = seq + 1
				_register_slot(s, port_slots)
		ring_global = ring_global + zd.rings

	_r_by_port[port_id] = r_open
	_max_open_zone[port_id] = max_open

	var public_slots: int = 0
	if city_by_port.has(port_id):
		public_slots = int((city_by_port[port_id] as CityCenterDef).public_slots)

	for _p in range(public_slots):
		var ps := Slot.new()
		ps.kind = Slot.Kind.PUBLIC
		ps.port_id = port_id
		ps.zone = 0
		ps.ring = 0
		ps.land_owner = city_id
		ps.building_id = &""
		ps.zone_open = true
		ps.slot_id = slot_id(port_id, seq)
		seq = seq + 1
		_register_slot(ps, port_slots)

	var kontor_n: int = Params.get_int(PRM_KONTOR_PLOTS)
	for _k in range(kontor_n):
		var ks := Slot.new()
		ks.kind = Slot.Kind.KONTOR
		ks.port_id = port_id
		ks.zone = 0
		ks.ring = 0
		ks.land_owner = city_id
		ks.building_id = &""
		ks.zone_open = true
		ks.slot_id = slot_id(port_id, seq)
		seq = seq + 1
		_register_slot(ks, port_slots)

	_slots_by_port[port_id] = port_slots


func _split_slots_even(total_slots: int, rings: int) -> Array:
	if rings <= 0:
		return []
	var weights: Array = []
	for _i in range(rings):
		weights.append(1)
	return CashLedger.split_largest_remainder(total_slots, weights)


func _scarcity_civil(port_id: String, zone: int) -> float:
	var total: int = 0
	var empty: int = 0
	for slot_variant in _slots_by_port.get(port_id, []):
		var slot: Slot = slot_variant
		if slot.kind != Slot.Kind.CIVIL or slot.zone != zone:
			continue
		total = total + 1
		if slot.building_id == &"":
			empty = empty + 1
	if total <= 0:
		return 1.0
	var ratio: float = float(empty) / float(total)
	var floor_v: float = Params.get_float(PRM_SCARCITY_FLOOR)
	var denom: float = ratio
	if denom < floor_v:
		denom = floor_v
	if denom <= 0.0:
		denom = floor_v
	return 1.0 / denom


func _register_slot(slot: Slot, port_slots: Array) -> void:
	var key := String(slot.slot_id)
	_slots[key] = slot
	port_slots.append(slot)


func _slot(slot_key: StringName) -> Slot:
	var key := String(slot_key)
	if not _slots.has(key):
		return null
	return _slots[key] as Slot


func _load_zones(zones_dir: String, errors: Array) -> Dictionary:
	var by_port: Dictionary = {}
	var dir := DirAccess.open(zones_dir)
	if dir == null:
		return by_port
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(TRES_SUFFIX):
			continue
		var path: String = zones_dir.path_join(file_name)
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, file_name, "zone load failed"))
			continue
		if not res is ZoneDef:
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, file_name, "not ZoneDef"))
			continue
		var zd: ZoneDef = res
		if not by_port.has(zd.port_id):
			by_port[zd.port_id] = []
		(by_port[zd.port_id] as Array).append(zd)
	dir.list_dir_end()
	return by_port


func _load_city_centers(city_center_dir: String, errors: Array) -> Dictionary:
	var by_port: Dictionary = {}
	var dir := DirAccess.open(city_center_dir)
	if dir == null:
		return by_port
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(TRES_SUFFIX):
			continue
		var path: String = city_center_dir.path_join(file_name)
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, file_name, "city_center load failed"))
			continue
		if not res is CityCenterDef:
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, file_name, "not CityCenterDef"))
			continue
		var cc: CityCenterDef = res
		by_port[cc.port_id] = cc
	dir.list_dir_end()
	return by_port


func _load_building_defs(buildings_dir: String, errors: Array) -> Dictionary:
	var by_type: Dictionary = {}
	var dir := DirAccess.open(buildings_dir)
	if dir == null:
		return by_type
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(TRES_SUFFIX):
			continue
		var path: String = buildings_dir.path_join(file_name)
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, file_name, "building def load failed"))
			continue
		if not res is BuildingDef:
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, file_name, "not BuildingDef"))
			continue
		var bd: BuildingDef = res
		by_type[bd.type] = bd
	dir.list_dir_end()
	return by_type


func _clear_state() -> void:
	_slots = {}
	_slots_by_port = {}
	_r_by_port = {}
	_max_open_zone = {}
	_buildings = {}
	_buildings_by_port = {}
	_building_defs = {}
	_bld_seq_by_port = {}
	_pending_started = []
	_pending_waiting = []
	_pending_completed = []
	_pending_shortfalls = []
	_loaded = false
	_clear_last_error()


func _clear_last_error() -> void:
	_last_error = {}
	_last_errors = []


func _fail(code: StringName, field: String, value: Variant, message: String) -> int:
	_record_fail(code, field, value, message)
	return 0


func _fail_sn(code: StringName, field: String, value: Variant, message: String) -> StringName:
	_record_fail(code, field, value, message)
	return &""


func _record_fail(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = _err(code, field, value, message)
	_last_errors = [_last_error.duplicate(true)]
	push_error("BuildingEconomy: %s" % str(_last_error))


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("BuildingEconomy: %s" % str(e))


class _WarehouseCapacityAdapter extends CapacityProvider:
	var _economy: BuildingEconomy

	func _init(economy: BuildingEconomy) -> void:
		_economy = economy

	func capacity(container: Variant) -> int:
		if _economy == null or not _economy.is_loaded():
			return 0
		return _economy.warehouse_capacity_for_container(container)
