extends Node
## Autoload: BuildingEconomy — SYS-08 data + build + produce/wage + city/season (WP-18..23).
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
const ERR_SYS08_10 := &"ERR-SYS08-10"
const ERR_SYS08_12 := &"ERR-SYS08-12"
const ERR_SYS08_13 := &"ERR-SYS08-13"
const ERR_SYS08_14 := &"ERR-SYS08-14" ## D-102(b)／FRM-SYS08-18: 工坊週毛利為負，無法報收購價

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_PORT_REGISTRY_NOT_LOADED := &"PORT_REGISTRY_NOT_LOADED"
const CODE_POPULATION_PROVIDER_MISSING := &"POPULATION_PROVIDER_MISSING"
const CODE_WORKFORCE_PROVIDER_MISSING := &"WORKFORCE_PROVIDER_MISSING"

const REASON_LAND_PURCHASE := &"LAND_PURCHASE"
const REASON_CONSTRUCTION := &"CONSTRUCTION"
const REASON_TRADE := &"TRADE"
const REASON_WAGE := &"WAGE"
const REASON_RENT := &"RENT"
const REASON_LAND_RENT := &"LAND_RENT"
const REASON_VACANCY_TAX := &"VACANCY_TAX"
const REASON_LEVY := &"LEVY"
const REASON_ZONE_OPEN := &"ZONE_OPEN"
const REASON_CITY_BUY := &"CITY_BUILDING_BUY"
const REQUESTER_SYS08 := &"SYS-08"
const SHORTFALL_INPUT := &"INPUT"
const SHORTFALL_CAPACITY := &"CAPACITY"

const GOOD_ARMS := &"GD-026"
const GOOD_POWDER := &"GD-023"
const CB_BARRACKS := &"CB-09"

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
## EX-02: feasibility sentinel (unbounded) — not a business output.
const FEAS_UNBOUNDED := 0x7fffffff
## EX-03: building level floor (spec enum base).
const BUILDING_LEVEL_MIN := 1
## EX-WP63: unset ring sentinel for innermost civil search (was bare 999999).
const RING_SENTINEL_UNSET := 999999
## EX-WP63: public upgrade cash failure sentinel（不得回 0 冒充免費）.
const PUBLIC_UPGRADE_CASH_FAIL := -1
const PRM_KONTOR_UPGRADE := "PRM-SYS08-KONTOR_UPGRADE"
const PRM_ACC_SCALE := "PRM-SYS08-ACC_SCALE"
const PRM_OUTPUT_K := "PRM-SYS08-OUTPUT_PER_WORKER_K"
const PRM_RECIPE_N := "PRM-SYS08-RECIPE_KEEP_N"
const PRM_WAGE_SHARE_W := "PRM-SYS08-WAGE_SHARE_W"
const PRM_WAGE_BASE_LI := "PRM-SYS08-WAGE_BASE_LI"
const PRM_DAYS_PER_WEEK := "PRM-SYS04-DAYS_PER_WEEK"
const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_LAND_RENT_RATE := "PRM-SYS08-LAND_RENT_RATE_YEAR"
const PRM_VACANCY_GRACE := "PRM-SYS08-VACANCY_GRACE_DAYS"
const PRM_VACANCY_RATE := "PRM-SYS08-VACANCY_RATE"
const PRM_HOUSING_SHARE := "PRM-SYS08-HOUSING_SHARE"
const PRM_MGMT_FEE := "PRM-SYS08-MGMT_FEE"
const PRM_CLASS_SPEND := "PRM-SYS08-CLASS_SPEND_LI"
const PRM_GARRISON := "PRM-SYS08-GARRISON"
const PRM_ARMS_PER := "PRM-SYS08-ARMS_PER_SOLDIER_WK"
const PRM_POWDER_PER := "PRM-SYS08-POWDER_PER_SOLDIER_WK"
const PRM_LEVY_THRESHOLD := "PRM-SYS08-LEVY_THRESHOLD_SEASONS"
const PRM_LEVY_RATE := "PRM-SYS08-LEVY_RATE"
const PRM_ZONE_POP_MIN := "PRM-SYS08-ZONE_POP_MIN"
const PRM_ZONE_SAT_MIN := "PRM-SYS08-ZONE_SAT_MIN"
const PRM_ZONE_SAT_DAYS := "PRM-SYS08-ZONE_SAT_DAYS"
const PRM_ZONE_OPEN_COST := "PRM-SYS08-ZONE_OPEN_COST_LI"
const PRM_TRANSFER_PREMIUM := "PRM-SYS08-TRANSFER_PREMIUM"
const PRM_COMPENSATION_WEEKS := "PRM-SYS08-COMPENSATION_WEEKS"
## D-97(c)／WP-62b: opening MARKET stock weeks（Owner-approved 4／2）.
const PRM_OPENING_STOCK_DEMAND_WEEKS := "PRM-SYS08-OPENING_STOCK_DEMAND_WEEKS"
const PRM_OPENING_STOCK_OUTPUT_WEEKS := "PRM-SYS08-OPENING_STOCK_OUTPUT_WEEKS"
const BUILD_QUEUE_DIR := "res://data/build_queue/"
const OPENING_DIR := "res://data/opening/"
const OPENING_PUBLIC_DIR := "res://data/opening_public/"
const PLAYER_ACTOR := &"ACT-PLAYER"
const PLAYER_HOME_PORT := "PT-10" ## 魍港 (FRM-SYS13-06／FRM-SYS08-21)

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
var _r_by_port: Dictionary = {} ## port_id:String → int R = max ring among open CIVIL slots
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
## WP-23 season／city state
var _queue_by_port: Dictionary = {} ## port → Array[BuildStep] sorted by step
var _queue_pos: Dictionary = {} ## port → int next index
var _zone_streak: Dictionary = {} ## port → int
var _acc_arms: Dictionary = {} ## port → int (ACC_SCALE units)
var _acc_powder: Dictionary = {} ## port → int
var _city_spend_hist: Dictionary = {} ## port → Array[int] recent season spends
var _season_city_spend: Dictionary = {} ## port → int spend this season
## WP-67／D-97(e) OBS-05 persistence: "port|season" → value.
var _obs05_spend_by_cat: Dictionary = {}
var _obs05_land_rent: Dictionary = {}
var _obs05_vacancy_tax: Dictionary = {}
## In-season accumulators (cleared each season_step).
var _season_spend_cat: Dictionary = {} ## port → {build_upgrade_li,garrison_li,levy_li,other_li}
var _season_land_rent_acc: Dictionary = {} ## port → int
var _season_vacancy_tax_acc: Dictionary = {} ## port → int
const SPEND_CAT_BUILD := "build_upgrade_li"
const SPEND_CAT_GARRISON := "garrison_li"
const SPEND_CAT_LEVY := "levy_li"
const SPEND_CAT_OTHER := "other_li"
const ERR_OBS05_LOOKUP := &"ERR-SYS08-08" ## D-08c unknown／unsettled → last_error
var _land_held_days: Dictionary = {} ## slot_id → days held this season (player)


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
	# WP-23 / TST-SYS08-15: no-value PRMs missing → ERR-SYS08-09 (C-06 collect all).
	var wp23_required: Array = [
		PRM_LAND_RENT_RATE,
		PRM_VACANCY_GRACE,
		PRM_VACANCY_RATE,
		PRM_HOUSING_SHARE,
		PRM_MGMT_FEE,
		PRM_CLASS_SPEND,
		PRM_GARRISON,
		PRM_ARMS_PER,
		PRM_POWDER_PER,
		PRM_LEVY_THRESHOLD,
		PRM_LEVY_RATE,
		PRM_ZONE_POP_MIN,
		PRM_ZONE_SAT_MIN,
		PRM_ZONE_SAT_DAYS,
		PRM_ZONE_OPEN_COST,
		PRM_TRANSFER_PREMIUM,
		PRM_COMPENSATION_WEEKS,
	]
	for key_v in wp23_required:
		var key: String = String(key_v)
		if not Params.has_prm(StringName(key)):
			errors.append(_err(ERR_SYS08_09, key, null, "required WP-23 PRM missing"))
	if not errors.is_empty():
		_emit_errors(errors)
		return errors

	var zones_by_port: Dictionary = _load_zones(zones_dir, errors)
	var city_by_port: Dictionary = _load_city_centers(city_center_dir, errors)
	_building_defs = _load_building_defs(buildings_dir, errors)
	_load_build_queues(BUILD_QUEUE_DIR, errors)
	## D-97(a)／D-102(f)／FRM-SYS08-21: ERR-SYS08-13 always on coherent datasets.
	## Formal city boot（含 sim_loop 重匯入的 fixture CSV）→ validate formal opening+queue.
	## Unit-test synthetic city dirs are not a coherent import with formal opening/queue —
	## clear queues and validate empty openings so N1 still runs（不得 skip 驗證）.
	var registry_ports: Array = []
	for rp_v in PortRegistry.all_ids():
		registry_ports.append(String(rp_v))
	var city_covers_registry := true
	for rp2 in registry_ports:
		if not city_by_port.has(String(rp2)):
			city_covers_registry = false
			break
	var formal_city_boot: bool = city_center_dir == CITY_CENTER_DIR
	if city_covers_registry and not formal_city_boot:
		_queue_by_port = {}
		_queue_pos = {}
	if city_covers_registry:
		var opening_load_errs: Array = []
		var opening_publics: Array = []
		if formal_city_boot:
			opening_publics = _load_opening_public(OPENING_PUBLIC_DIR, opening_load_errs)
			for oe in opening_load_errs:
				errors.append(oe)
		_validate_build_queue_import_d97a(city_by_port, opening_publics, errors)
	if not errors.is_empty():
		_emit_errors(errors)
		return errors

	for port_variant in PortRegistry.all_ids():
		var port_id: String = String(port_variant)
		_build_port_slots(port_id, zones_by_port, city_by_port)
		CashLedger.create_account(CashLedger.make_city_id(port_id), Account.Kind.CITY)
		if not _queue_pos.has(port_id):
			_queue_pos[port_id] = 0
		_zone_streak[port_id] = 0
		_acc_arms[port_id] = 0
		_acc_powder[port_id] = 0
		_season_city_spend[port_id] = 0
		_season_spend_cat[port_id] = _empty_spend_cat()
		_season_land_rent_acc[port_id] = 0
		_season_vacancy_tax_acc[port_id] = 0
		if not _city_spend_hist.has(port_id):
			_city_spend_hist[port_id] = []

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
	# FRM-04 grace clock starts on purchase of empty land.
	slot.vacancy_start_day = Clock.day if Clock != null else 0
	_land_held_days[String(slot_key)] = 0
	var seq: int = CashLedger.last_posting_seq()
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
	## D-102(e)／OBS-05: CITY PUBLIC new-build cash → build_upgrade_li（not other_li）.
	if build_class == CLASS_PUBLIC and _is_city_owner(actor):
		_note_city_spend(slot.port_id, cash_li, SPEND_CAT_BUILD)

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
	var max_lvl: int = (
		_kontor_max_level() if bld.build_class == CLASS_KONTOR else _public_max_level()
	)
	if bld.level >= max_lvl:
		return StringName(_fail_sn(ERR_SYS08_03, "level", bld.level, "already max level"))

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
		var idx: int = _upgrade_level_index(to_level)
		if idx < 0 or idx >= arr.size():
			return StringName(_fail_sn(ERR_SYS08_09, "level", to_level, "KONTOR_UPGRADE index"))
		var row: Dictionary = arr[idx]
		if not row.has("CASH_LI") or not row.has("DAYS"):
			return StringName(
				_fail_sn(ERR_SYS08_09, "KONTOR_UPGRADE", idx, "CASH_LI／DAYS key missing (A11)")
			)
		cash_li = int(row["CASH_LI"])
		build_days = int(row["DAYS"])
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
	## D-102(e)／OBS-05: CITY PUBLIC upgrade cash → build_upgrade_li.
	if bld.build_class == CLASS_PUBLIC and _is_city_owner(actor):
		_note_city_spend(bld.port_id, cash_li, SPEND_CAT_BUILD)

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



func _public_max_level() -> int:
	## EX-03: max public level = BUILDING_LEVEL_MIN + len(UPGRADE_PER_CAPITA).
	var arr: Array = Params.get_value(PRM_UPGRADE_PER_CAPITA)
	return BUILDING_LEVEL_MIN + arr.size()


func _kontor_max_level() -> int:
	## EX-03: max kontor level = BUILDING_LEVEL_MIN + len(KONTOR_UPGRADE).
	if not Params.has_prm(PRM_KONTOR_UPGRADE):
		return BUILDING_LEVEL_MIN
	var arr: Array = Params.get_value(PRM_KONTOR_UPGRADE)
	return BUILDING_LEVEL_MIN + arr.size()


func _upgrade_level_index(to_level: int) -> int:
	## EX-03: UPGRADE_PER_CAPITA／KONTOR_UPGRADE row index for target level (L2→0).
	return to_level - (BUILDING_LEVEL_MIN + 1)


func _zone_table_index(next_zone: int) -> int:
	## EX-03: ZONE_POP_MIN／ZONE_OPEN_COST[0] = zone 2.
	return next_zone - (BUILDING_LEVEL_MIN + 1)


func public_upgrade_fee(port_id: StringName, to_level: int) -> Dictionary:
	## FRM-07: pop × UPGRADE_PER_CAPITA[level]; cash CEIL to li; mats CEIL to 擔.
	assert(_loaded, "BuildingEconomy.public_upgrade_fee before load")
	var pop: int = _population.population(port_id)
	var arr: Array = Params.get_value(PRM_UPGRADE_PER_CAPITA)
	var idx: int = _upgrade_level_index(to_level)
	var out := {"CASH_LI": 0, "MAT": {}}
	if idx < 0 or idx >= arr.size():
		return out
	var row: Dictionary = arr[idx]
	if not row.has("CASH_LI"):
		_record_fail(ERR_SYS08_09, "UPGRADE_PER_CAPITA", idx, "CASH_LI key missing (A11)")
		return out
	var cash_per: int = int(row["CASH_LI"])
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
	## 8.6 F／14-05: ① build → ② produce → ③ garrison → ④ wage+rent → ⑤ zone streak.
	assert(_loaded, "BuildingEconomy.daily_step before load")
	var errors: Array = []
	_step_construction(errors)
	_step_produce(errors)
	_step_garrison_procure(day, errors)
	_step_wage_accrual()
	_step_rent_accrual()
	_step_zone_streak()
	_step_land_held_days()
	return errors


func season_step() -> Array:
	## 14-05／14-06: fixed quarter-end six steps by port_id asc, before close_season.
	assert(_loaded, "BuildingEconomy.season_step before load")
	var errors: Array = []
	var ports: Array = _buildings_by_port.keys()
	for pid_v in _slots_by_port.keys():
		if not ports.has(pid_v):
			ports.append(pid_v)
	ports.sort()
	for pid_v in ports:
		var port_id: String = String(pid_v)
		_season_wages(port_id)
		_season_rents(port_id)
		_season_land_and_vacancy(port_id)
		_season_city_build_queue(port_id)
		_season_zone_open(port_id)
		_season_levy(port_id)
		_persist_obs05_season(port_id)
		_clear_season_accums(port_id)
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
				## A12／R9-44 M2: keep days_left set at order_build／order_upgrade
				## (upgrade may use KONTOR_UPGRADE DAYS, not BUILD_DAYS[class]).
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
		out_feas = FEAS_UNBOUNDED ## EX-02 sentinel
		for inp_variant in inputs:
			var inp: Dictionary = inp_variant
			var avail: int = GoodsLedger.get_qty(src, StringName(String(inp["good"])))
			var per: float = float(inp["qty"]) * recipe_n
			if per <= 0.0:
				continue
			var feas_i: int = floori(AmountQuantize.quantize_amount(float(avail) / per))
			if feas_i < out_feas:
				out_feas = feas_i
		if out_feas == FEAS_UNBOUNDED:
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
		if bld.build_class == CLASS_KONTOR:
			## TD-16／D-84b: upgrade WAITING／BUILDING keeps prior kontor cap level.
			var eff: int = _effect_level(bld)
			if eff > level:
				level = eff
		elif bld.build_class == CLASS_WAREHOUSE:
			if bld.state != Building.State.ACTIVE:
				continue
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
		if bld.build_class != CLASS_PUBLIC:
			continue
		if bld.cb_id != cb and bld.type != cb:
			continue
		## TD-16／D-84b: upgrade period keeps prior public_level until completion day.
		var eff: int = _effect_level(bld)
		if eff > best:
			best = eff
	return best


func _effect_level(bld: Building) -> int:
	## TD-16／D-84b: order_upgrade advances `level` immediately; effects use prior until ACTIVE.
	## New builds stay at level 1 while WAITING／BUILDING → prior 0 (no effect until complete).
	if bld.state == Building.State.ACTIVE:
		return bld.level
	if bld.state == Building.State.WAITING_MATERIAL or bld.state == Building.State.BUILDING:
		return maxi(0, bld.level - 1)
	return 0


func ring_count_open(_port_id: String) -> int:
	return int(_r_by_port.get(_port_id, 0))


func slots_for_port(_port_id: String) -> Array:
	return _slots_by_port.get(_port_id, [])


func get_slot(slot_key: StringName) -> Slot:
	return _slot(slot_key)


func get_building(bld_key: StringName) -> Building:
	return _building(bld_key)


func get_building_def(type_id: StringName) -> BuildingDef:
	## D-89b 待追認: public readonly BuildingDef lookup (was _building_defs cross-module).
	assert(_loaded, "BuildingEconomy.get_building_def before load")
	return _building_defs.get(String(type_id), null) as BuildingDef


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
	var max_open: int = -1

	var zone_rows: Array = zones_by_port.get(port_id, [])
	zone_rows.sort_custom(func(a: ZoneDef, b: ZoneDef) -> bool: return a.zone < b.zone)

	for zd_variant in zone_rows:
		var zd: ZoneDef = zd_variant
		if zd.open_at_start == 1 and zd.zone > max_open:
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
	_recompute_r(port_id)


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



func _list_tres_sorted(dir_path: String) -> Array:
	## A9／C-08: DirAccess listing order must not affect results.
	var names: Array = []
	var abs_dir: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return names
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return names
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(TRES_SUFFIX):
			continue
		names.append(file_name)
	dir.list_dir_end()
	names.sort()
	return names


func _load_zones(zones_dir: String, errors: Array) -> Dictionary:
	## A11: missing dir／bad tres → errors (C-06); A9: sorted listing.
	var by_port: Dictionary = {}
	var abs_dir: String = ProjectSettings.globalize_path(zones_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		errors.append(_err(CODE_PARAMS_NOT_LOADED, zones_dir, null, "zones dir missing"))
		return by_port
	for file_name_v in _list_tres_sorted(zones_dir):
		var file_name: String = String(file_name_v)
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
	return by_port


func _load_city_centers(city_center_dir: String, errors: Array) -> Dictionary:
	## A11: missing dir／bad tres → errors; A9: sorted listing.
	var by_port: Dictionary = {}
	var abs_dir: String = ProjectSettings.globalize_path(city_center_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		errors.append(_err(CODE_PARAMS_NOT_LOADED, city_center_dir, null, "city_center dir missing"))
		return by_port
	for file_name_v in _list_tres_sorted(city_center_dir):
		var file_name: String = String(file_name_v)
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
	return by_port


func _load_building_defs(buildings_dir: String, errors: Array) -> Dictionary:
	## A11: missing dir／bad tres → errors; A9: sorted listing.
	var by_type: Dictionary = {}
	var abs_dir: String = ProjectSettings.globalize_path(buildings_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		errors.append(_err(CODE_PARAMS_NOT_LOADED, buildings_dir, null, "buildings dir missing"))
		return by_type
	for file_name_v in _list_tres_sorted(buildings_dir):
		var file_name: String = String(file_name_v)
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
	return by_type


func apply_opening_init(
	opening_dir: String = OPENING_DIR,
	opening_public_dir: String = OPENING_PUBLIC_DIR,
	player_port: String = PLAYER_HOME_PORT,
	player_actor: StringName = PLAYER_ACTOR
) -> Array:
	## FRM-SYS08-21／A9／D-87: validate all opening inputs first; write only if clean.
	## Order: residences → gathering (IND1) → processing (IND2／3) → public → player kontor.
	assert(_loaded, "BuildingEconomy.apply_opening_init before load")
	var errors: Array = []
	var openings: Array = _load_opening_workshops(opening_dir, errors)
	var publics: Array = _load_opening_public(opening_public_dir, errors)
	if openings.is_empty():
		errors.append(
			_err(ERR_SYS08_10, "opening_workshops", opening_dir, "opening workshops dir empty or missing")
		)
	if publics.is_empty():
		errors.append(
			_err(ERR_SYS08_10, "opening_public", opening_public_dir, "opening public dir empty or missing")
		)
	var ws_ports: Dictionary = {}
	for row_chk in openings:
		ws_ports[String((row_chk as OpeningWorkshop).port_id)] = true
	var pub_ports: Dictionary = {}
	for pub_chk in publics:
		pub_ports[String((pub_chk as OpeningPublic).port_id)] = true
	if PortRegistry.is_loaded():
		for pid_v in PortRegistry.all_ids():
			var want: String = String(pid_v)
			if not openings.is_empty() and not ws_ports.has(want):
				errors.append(
					_err(ERR_SYS08_10, "opening_workshops", want, "missing opening workshop for port")
				)
			if not publics.is_empty() and not pub_ports.has(want):
				errors.append(
					_err(ERR_SYS08_10, "opening_public", want, "missing opening public for port")
				)
	# Deterministic row order (A9／C-08).
	openings.sort_custom(
		func(a: OpeningWorkshop, b: OpeningWorkshop) -> bool:
			if a.port_id != b.port_id:
				return String(a.port_id) < String(b.port_id)
			return String(a.good_id) < String(b.good_id)
	)
	publics.sort_custom(
		func(a: OpeningPublic, b: OpeningPublic) -> bool:
			if a.port_id != b.port_id:
				return String(a.port_id) < String(b.port_id)
			return String(a.cb_id) < String(b.cb_id)
	)

	var occupied: Dictionary = {} ## slot_id → true (dry-run reservation)
	var plan: Array = [] ## Dictionary spawn descriptors

	# --- validate residences (innermost open civil) ---
	var house_cap: int = Params.get_int(PopulationModel.PRM_HOUSE_CAP)
	var port_ids: Array = []
	if PortRegistry.is_loaded():
		for pid_v2 in PortRegistry.all_ids():
			port_ids.append(String(pid_v2))
	port_ids.sort()
	if not _building_defs.has("RB-01"):
		errors.append(_err(ERR_SYS08_10, "residence", "RB-01", "BuildingDef RB-01 missing"))
	else:
		for port_id in port_ids:
			var pop_n: int = 0
			if PopulationModel.is_loaded():
				pop_n = (
					PopulationModel.population(StringName(port_id), &"POOR")
					+ PopulationModel.population(StringName(port_id), &"CITIZEN")
					+ PopulationModel.population(StringName(port_id), &"RICH")
				)
			elif _population != null:
				pop_n = _population.population(StringName(port_id))
			if pop_n <= 0:
				continue
			var need_h: int = ceili(float(pop_n) / float(house_cap))
			for _h in range(need_h):
				var rslot: StringName = _find_open_civil_slot(port_id, occupied)
				if rslot == &"":
					errors.append(_err(ERR_SYS08_10, "residence", port_id, "no civil slot for residence"))
					break
				occupied[String(rslot)] = true
				plan.append(
					{
						"kind": "spawn",
						"owner_kind": "city",
						"port_id": port_id,
						"slot_id": rslot,
						"type": &"RB-01",
						"build_class": CLASS_RESIDENCE,
						"level": 1,
						"cb_id": &"",
					}
				)

	# --- validate workshops: IND1 gathering then IND2／3 outermost ---
	var gathering_rows: Array = []
	var processing_rows: Array = []
	for row_v in openings:
		var row: OpeningWorkshop = row_v
		var def: BuildingDef = _def_for_output_good(row.good_id)
		if def == null:
			errors.append(
				_err(ERR_SYS08_10, "good_id", row.good_id, "no BuildingDef for opening good")
			)
			continue
		if def.build_class == "IND1":
			gathering_rows.append({"row": row, "def": def})
		else:
			processing_rows.append({"row": row, "def": def})

	for phase_rows in [gathering_rows, processing_rows]:
		for item_v in phase_rows:
			var item: Dictionary = item_v
			var row2: OpeningWorkshop = item["row"]
			var def2: BuildingDef = item["def"]
			for _i in range(row2.count):
				var slot_id: StringName = _find_slot_for_workshop(row2.port_id, def2, occupied)
				if slot_id == &"":
					errors.append(
						_err(
							ERR_SYS08_10,
							"slot",
							row2.port_id,
							(
								"no gathering belt for IND1"
								if def2.build_class == "IND1"
								else "no slot for opening workshop"
							)
						)
					)
					break
				occupied[String(slot_id)] = true
				plan.append(
					{
						"kind": "spawn",
						"owner_kind": "city",
						"port_id": row2.port_id,
						"slot_id": slot_id,
						"type": StringName(def2.type),
						"build_class": StringName(def2.build_class),
						"level": 1,
						"cb_id": &"",
						"staff": true,
					}
				)

	# --- validate opening_public ---
	for pub_v in publics:
		var pub: OpeningPublic = pub_v
		var pslot: StringName = _find_public_slot(pub.port_id, occupied)
		if pslot == &"":
			errors.append(_err(ERR_SYS08_10, "public", pub.port_id, "no public slot"))
			continue
		if not _building_defs.has(pub.cb_id):
			errors.append(
				_err(ERR_SYS08_10, "public", pub.cb_id, "BuildingDef missing for opening public")
			)
			continue
		occupied[String(pslot)] = true
		plan.append(
			{
				"kind": "spawn",
				"owner_kind": "city",
				"port_id": pub.port_id,
				"slot_id": pslot,
				"type": StringName(pub.cb_id),
				"build_class": CLASS_PUBLIC,
				"level": maxi(BUILDING_LEVEL_MIN, pub.level),
				"cb_id": StringName(pub.cb_id),
			}
		)

	# --- validate player kontor ---
	var has_player_port := false
	for pid_chk in port_ids:
		if String(pid_chk) == player_port:
			has_player_port = true
			break
	if has_player_port:
		var kslot: StringName = _find_kontor_slot(player_port, occupied)
		if kslot == &"":
			errors.append(_err(ERR_SYS08_10, "kontor", player_port, "no kontor slot for player"))
		elif not _building_defs.has("CB-17"):
			errors.append(_err(ERR_SYS08_10, "kontor", "CB-17", "BuildingDef CB-17 missing"))
		else:
			occupied[String(kslot)] = true
			plan.append(
				{
					"kind": "spawn",
					"owner_kind": "player",
					"port_id": player_port,
					"slot_id": kslot,
					"type": &"CB-17",
					"build_class": CLASS_KONTOR,
					"level": 1,
					"cb_id": &"",
					"actor": player_actor,
				}
			)

	# D-87: any error → no writes.
	if not errors.is_empty():
		_emit_errors(errors)
		return errors

	# --- commit ---
	var staffed_ports: Dictionary = {}
	for step_v in plan:
		var step: Dictionary = step_v
		var port_id3: String = String(step["port_id"])
		var owner: StringName
		if String(step["owner_kind"]) == "player":
			owner = step["actor"] as StringName
			CashLedger.create_account(owner, Account.Kind.ACTOR)
			var slot: Slot = _slot(step["slot_id"])
			if slot != null:
				slot.land_owner = owner
		else:
			owner = CashLedger.make_city_id(port_id3)
			CashLedger.create_account(owner, Account.Kind.CITY)
		var bld: Building = _spawn_active_building(
			owner,
			port_id3,
			step["slot_id"],
			step["type"],
			step["build_class"],
			int(step["level"])
		)
		if step.get("cb_id", &"") != &"":
			bld.cb_id = step["cb_id"]
		if bool(step.get("staff", false)):
			staffed_ports[port_id3] = true
	## WP-63 (h)／C-08: staffed_ports sorted before staff walk.
	var staff_ids: Array = staffed_ports.keys()
	staff_ids.sort()
	for pid_staff in staff_ids:
		_opening_staff_port(String(pid_staff))
	return errors


func apply_opening_market_stock() -> Array:
	## FRM-SYS08-21／D-97(c)／WP-62b: last opening step — GENESIS into MARKET.
	## q = DEMAND_WEEKS × weekly_potential_demand + floori(OUTPUT_WEEKS × Σ full-staff W).
	## Order (port_id, good_id) ascending; q=0 skip（no GENESIS event）.
	assert(_loaded, "BuildingEconomy.apply_opening_market_stock before load")
	var errors: Array = []
	if not DemandModel.is_loaded():
		errors.append(
			_err(
				ERR_SYS08_09,
				"DemandModel",
				null,
				"DemandModel must be loaded before opening market stock (D-97c)"
			)
		)
		_emit_errors(errors)
		return errors
	if not Params.has_prm(PRM_OPENING_STOCK_DEMAND_WEEKS) or not Params.has_prm(
		PRM_OPENING_STOCK_OUTPUT_WEEKS
	):
		errors.append(
			_err(
				ERR_SYS08_09,
				PRM_OPENING_STOCK_DEMAND_WEEKS,
				null,
				"opening stock PRMs missing (D-97c)"
			)
		)
		_emit_errors(errors)
		return errors
	if not GoodsLedger.is_loaded():
		errors.append(
			_err(ERR_SYS08_09, "GoodsLedger", null, "GoodsLedger required for opening stock")
		)
		_emit_errors(errors)
		return errors

	var demand_w: int = Params.get_int(PRM_OPENING_STOCK_DEMAND_WEEKS)
	var output_w: int = Params.get_int(PRM_OPENING_STOCK_OUTPUT_WEEKS)
	var k: float = Params.get_float(PRM_OUTPUT_K)
	## Σ full-staff weekly output W per (port, good) from opening workshops.
	var out_sum: Dictionary = {}
	var ports_b: Array = _buildings_by_port.keys()
	ports_b.sort()
	for pid_v in ports_b:
		var port_id: String = String(pid_v)
		for bld_v in _buildings_by_port.get(port_id, []):
			var bld: Building = bld_v
			if not _is_workshop(bld):
				continue
			var def: BuildingDef = _building_defs.get(String(bld.type), null) as BuildingDef
			if def == null or def.output_good_id.is_empty():
				continue
			## 满编 W = max_workers × BASE_OUTPUT_PER_WORKER × K（FRM-SYS08-08）.
			var w_full: float = float(def.max_workers) * float(def.base_output_per_worker) * k
			var key: String = "%s|%s" % [port_id, def.output_good_id]
			out_sum[key] = float(out_sum.get(key, 0.0)) + w_full

	var ports: Array = []
	for pv in PortRegistry.all_ids():
		ports.append(String(pv))
	ports.sort()
	var goods: Array = []
	for gv in GoodCatalog.all_ids():
		goods.append(String(gv))
	goods.sort()

	for port_id2 in ports:
		var mkt: Dictionary = GoodsLedger.make_market(String(port_id2))
		for good_id in goods:
			var pot: int = DemandModel.weekly_potential_demand(
				StringName(String(port_id2)), StringName(String(good_id))
			)
			var w_sum: float = float(out_sum.get("%s|%s" % [String(port_id2), String(good_id)], 0.0))
			var q: int = demand_w * pot + floori(float(output_w) * w_sum)
			if q <= 0:
				continue
			var seq: int = GoodsLedger.transfer(
				GoodsLedger.make_external(),
				mkt,
				StringName(String(good_id)),
				q,
				GoodsLedger.REASON_GENESIS,
				REQUESTER_SYS08
			)
			if seq <= 0:
				errors.append(
					_err(
						ERR_SYS08_10,
						"opening_stock",
						{"port_id": port_id2, "good_id": good_id, "q": q},
						"GENESIS opening stock transfer failed"
					)
				)
	if not errors.is_empty():
		_emit_errors(errors)
	return errors


func _spawn_active_building(
	owner: StringName,
	port_id: String,
	slot_id: StringName,
	type_id: StringName,
	build_class: StringName,
	level: int
) -> Building:
	var bld := Building.new()
	bld.building_id = _next_bld_id(port_id)
	bld.type = type_id
	bld.build_class = build_class
	bld.owner = owner
	bld.port_id = port_id
	bld.slot_id = slot_id
	bld.level = level
	bld.state = Building.State.ACTIVE
	bld.days_left = 0
	if build_class == CLASS_PUBLIC:
		bld.cb_id = type_id
	var slot: Slot = _slot(slot_id)
	if slot != null:
		slot.building_id = bld.building_id
		slot.vacancy_start_day = -1
		if not _is_city_owner(owner):
			slot.land_owner = owner
	_register_building(bld)
	return bld


func _def_for_output_good(good_id: String) -> BuildingDef:
	var best: BuildingDef = null
	for k in _building_defs.keys():
		var d: BuildingDef = _building_defs[k] as BuildingDef
		if d.output_good_id != good_id:
			continue
		if (
			d.build_class == "IND1"
			or d.build_class == "IND2"
			or d.build_class == "IND3"
		):
			best = d
			break
	return best


func _slot_free(slot: Slot, occupied: Dictionary) -> bool:
	if slot.building_id != &"":
		return false
	if occupied.has(String(slot.slot_id)):
		return false
	return true


func _find_slot_for_workshop(
	port_id: String, def: BuildingDef, occupied: Dictionary = {}
) -> StringName:
	## A9: IND1 gathering belt only (no civil fallback); IND2／3 outermost open civil.
	if def.build_class == "IND1":
		var belt_slots: Array = []
		for s_v in _slots_by_port.get(port_id, []):
			var s: Slot = s_v
			if not _slot_free(s, occupied):
				continue
			if _is_gathering_belt(s):
				belt_slots.append(s)
		belt_slots.sort_custom(
			func(a: Slot, b: Slot) -> bool:
				if a.ring != b.ring:
					return a.ring < b.ring
				return String(a.slot_id) < String(b.slot_id)
		)
		if belt_slots.is_empty():
			return &""
		return (belt_slots[0] as Slot).slot_id
	return _find_open_civil_slot_outermost(port_id, occupied)


func _find_open_civil_slot(port_id: String, occupied: Dictionary = {}) -> StringName:
	## Residences: innermost open civil first (FRM-SYS08-21).
	var best: StringName = &""
	var best_ring: int = RING_SENTINEL_UNSET
	var best_id := ""
	for s_v in _slots_by_port.get(port_id, []):
		var s: Slot = s_v
		if s.kind != Slot.Kind.CIVIL or not s.zone_open or not _slot_free(s, occupied):
			continue
		var sid: String = String(s.slot_id)
		if s.ring < best_ring or (s.ring == best_ring and (best_id == "" or sid < best_id)):
			best_ring = s.ring
			best = s.slot_id
			best_id = sid
	return best


func _find_open_civil_slot_outermost(port_id: String, occupied: Dictionary = {}) -> StringName:
	## Processing workshops: outermost open civil first (FRM-SYS08-21／A9).
	var best: StringName = &""
	var best_ring := -1
	var best_id := ""
	for s_v in _slots_by_port.get(port_id, []):
		var s: Slot = s_v
		if s.kind != Slot.Kind.CIVIL or not s.zone_open or not _slot_free(s, occupied):
			continue
		var sid: String = String(s.slot_id)
		if s.ring > best_ring or (s.ring == best_ring and (best_id == "" or sid < best_id)):
			best_ring = s.ring
			best = s.slot_id
			best_id = sid
	return best


func _find_public_slot(port_id: String, occupied: Dictionary = {}) -> StringName:
	var candidates: Array = []
	for s_v in _slots_by_port.get(port_id, []):
		var s: Slot = s_v
		if s.kind == Slot.Kind.PUBLIC and _slot_free(s, occupied):
			candidates.append(s)
	candidates.sort_custom(
		func(a: Slot, b: Slot) -> bool: return String(a.slot_id) < String(b.slot_id)
	)
	if candidates.is_empty():
		return &""
	return (candidates[0] as Slot).slot_id


func _find_kontor_slot(port_id: String, occupied: Dictionary = {}) -> StringName:
	var candidates: Array = []
	for s_v in _slots_by_port.get(port_id, []):
		var s: Slot = s_v
		if s.kind == Slot.Kind.KONTOR and _slot_free(s, occupied):
			candidates.append(s)
	candidates.sort_custom(
		func(a: Slot, b: Slot) -> bool: return String(a.slot_id) < String(b.slot_id)
	)
	if candidates.is_empty():
		return &""
	return (candidates[0] as Slot).slot_id


func _opening_staff_port(port_id: String) -> void:
	if not PopulationModel.is_loaded():
		return
	for bld_v in workplaces(StringName(port_id)):
		var bld: Building = bld_v
		if not _is_city_owner(bld.owner):
			continue
		var def: BuildingDef = _building_defs.get(String(bld.type), null) as BuildingDef
		if def == null:
			continue
		PopulationModel.set_workers(bld.building_id, def.max_workers)


func _load_opening_workshops(dir: String, errors: Array) -> Array:
	## A11: bad tres reported; missing dir → empty (caller adds ERR-SYS08-10).
	var out: Array = []
	var abs_dir: String = ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return out
	for fname_v in _list_tres_sorted(dir):
		var fname: String = String(fname_v)
		var path: String = dir.path_join(fname)
		var res: Resource = load(path)
		if res == null:
			errors.append(_err(ERR_SYS08_10, path, fname, "opening workshop load failed"))
			continue
		if not res is OpeningWorkshop:
			errors.append(_err(ERR_SYS08_10, path, fname, "not OpeningWorkshop"))
			continue
		out.append(res)
	return out


func _load_opening_public(dir: String, errors: Array) -> Array:
	## A11: bad tres reported; missing dir → empty (caller adds ERR-SYS08-10).
	var out: Array = []
	var abs_dir: String = ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return out
	for fname_v in _list_tres_sorted(dir):
		var fname: String = String(fname_v)
		var path: String = dir.path_join(fname)
		var res: Resource = load(path)
		if res == null:
			errors.append(_err(ERR_SYS08_10, path, fname, "opening public load failed"))
			continue
		if not res is OpeningPublic:
			errors.append(_err(ERR_SYS08_10, path, fname, "not OpeningPublic"))
			continue
		out.append(res)
	return out


func quote_city_building(bld_key: StringName) -> int:
	## FRM-18 quote (li); 0 + last_error on failure.
	assert(_loaded, "BuildingEconomy.quote_city_building before load")
	_clear_last_error()
	var bld: Building = _building(bld_key)
	if bld == null:
		_record_fail(ERR_SYS08_08, "bld_id", bld_key, "unknown building")
		return 0
	if not _is_city_owner(bld.owner):
		_record_fail(ERR_SYS08_12, "owner", bld.owner, "not city-owned building")
		return 0
	return _frm18_price(bld)


func buy_city_building(actor: StringName, bld_key: StringName) -> int:
	## FRM-18 purchase; full amount → CITY; land+building transfer.
	assert(_loaded, "BuildingEconomy.buy_city_building before load")
	_clear_last_error()
	var bld: Building = _building(bld_key)
	if bld == null:
		return _fail(ERR_SYS08_08, "bld_id", bld_key, "unknown building")
	if not _is_city_owner(bld.owner):
		return _fail(ERR_SYS08_12, "owner", bld.owner, "not city-owned building")
	var price: int = _frm18_price(bld)
	if price <= 0:
		return 0
	var city_id: StringName = CashLedger.make_city_id(bld.port_id)
	CashLedger.create_account(city_id, Account.Kind.CITY)
	var post_err: Error = CashLedger.post(
		[
			CashLedger.make_entry(actor, 0 - price),
			CashLedger.make_entry(city_id, price),
		],
		REASON_CITY_BUY,
		REQUESTER_SYS08
	)
	if post_err != OK:
		return _fail(ERR_SYS08_07, "post", price, "city building buy failed")
	bld.owner = actor
	var slot: Slot = _slot(bld.slot_id)
	if slot != null:
		slot.land_owner = actor
	_note_city_spend(bld.port_id, 0, SPEND_CAT_OTHER) # purchase is income to city, not spend
	var seq: int = CashLedger.last_posting_seq()
	return seq


## Test／WP-24 helper: inject build queue steps for a port (sorted by step).
func set_build_queue(port_id: String, steps: Array) -> void:
	var copy: Array = steps.duplicate()
	copy.sort_custom(func(a: BuildStep, b: BuildStep) -> bool: return a.step < b.step)
	_queue_by_port[port_id] = copy
	_queue_pos[port_id] = 0


func city_queue_position(port_id: StringName) -> int:
	## D-102(d)／C-14: next queue step index from 0; finished → step count; unknown port → −1 + last_error.
	assert(_loaded, "BuildingEconomy.city_queue_position before load")
	_clear_last_error()
	var pid: String = String(port_id)
	if not _slots_by_port.has(pid) and not _buildings_by_port.has(pid) and not _queue_by_port.has(pid):
		_record_fail(ERR_SYS08_08, "port_id", port_id, "unknown port for city_queue_position (D-102d)")
		return -1
	return int(_queue_pos.get(pid, 0))


func _frm18_price(bld: Building) -> int:
	var slot: Slot = _slot(bld.slot_id)
	var land_li: int = 0
	if slot != null:
		land_li = land_price(bld.slot_id)
	var cash_map: Dictionary = Params.get_value(PRM_BUILD_CASH_LI)
	var build_li: int = int(cash_map.get(String(bld.build_class), 0))
	var days_map: Dictionary = Params.get_value(PRM_BUILD_DAYS)
	var weeks: float = float(int(days_map.get(String(bld.build_class), 0))) / float(
		Params.get_int(PRM_DAYS_PER_WEEK)
	)
	var week_income: int = _weekly_income_estimate(bld)
	## D-102(b)／ERR-SYS08-14／EX-08-18-05: 週毛利 < 0 → fail + last_error；不得回 0 當價、不得成交.
	if week_income < 0:
		_record_fail(
			ERR_SYS08_14,
			"weekly_margin",
			week_income,
			"workshop weekly gross margin < 0; cannot quote buy price (D-102b／EX-08-18-05)"
		)
		return 0
	var premium: float = Params.get_float(PRM_TRANSFER_PREMIUM)
	var comp_w: int = Params.get_int(PRM_COMPENSATION_WEEKS)
	var mid: float = (
		(float(land_li) + float(build_li) + weeks * float(week_income)) * (1.0 + premium)
		+ float(comp_w) * float(week_income)
	)
	return ceili(AmountQuantize.quantize_amount(mid))


func _base_price_li(good_id: String) -> int:
	## FRM-SYS08-18／WP-63 (a): always GoodDef.base_price_li, never mid_price.
	if good_id.is_empty() or not GoodCatalog.is_loaded():
		return 0
	var g: GoodDef = GoodCatalog.get_good(good_id)
	if g == null:
		return 0
	return g.base_price_li


func _weekly_income_estimate(bld: Building) -> int:
	if bld.build_class == CLASS_RESIDENCE:
		# Use accrued rent scaled back to a week if any; else CLASS_SPEND proxy.
		var share: float = Params.get_float(PRM_HOUSING_SHARE)
		var mgmt: float = Params.get_float(PRM_MGMT_FEE)
		var spend: Dictionary = Params.get_value(PRM_CLASS_SPEND)
		var occ: Dictionary = _occupants_of(bld.building_id)
		var raw: float = 0.0
		for clazz in ["POOR", "CITIZEN", "RICH"]:
			raw += float(int(occ.get(clazz.to_lower(), 0))) * float(int(spend.get(clazz, 0)))
		return floori(AmountQuantize.quantize_amount(raw * share * (1.0 - mgmt)))
	if _is_workshop(bld):
		## FRM-SYS08-18／D-79／D-92b／WP-63: 基準價；收入 floori；投入／人工 ceili.
		var def: BuildingDef = _building_defs.get(String(bld.type), null) as BuildingDef
		if def == null:
			return 0
		var workers: int = _workers_of(bld.building_id)
		if workers <= 0:
			return 0
		var k: float = Params.get_float(PRM_OUTPUT_K)
		var wage_w: float = Params.get_float(PRM_WAGE_SHARE_W)
		var wage_base: int = Params.get_int(PRM_WAGE_BASE_LI)
		var recipe_n: float = Params.get_float(PRM_RECIPE_N)
		var week_out: float = float(workers) * float(def.base_output_per_worker) * k
		var out_px: float = float(_base_price_li(def.output_good_id))
		var revenue: float = week_out * out_px
		var input_cost: float = 0.0
		for inp_v in _recipe_inputs(def):
			var inp: Dictionary = inp_v
			var g: String = String(inp["good"])
			var px: float = float(_base_price_li(g))
			input_cost += week_out * float(inp["qty"]) * recipe_n * px
		var wage_cost: float = float(workers) * float(wage_base) * pow(k, wage_w)
		var rev_li: int = floori(AmountQuantize.quantize_amount(revenue))
		var in_li: int = ceili(AmountQuantize.quantize_amount(input_cost))
		var wag_li: int = ceili(AmountQuantize.quantize_amount(wage_cost))
		var gross: int = rev_li - in_li - wag_li
		## EX-08-18-05／D-102(b): < 0 → never clamp to 0; quote/buy set ERR-SYS08-14.
		return gross
	return 0


func _step_garrison_procure(_day: int, _errors: Array) -> void:
	## FRM-14／D-92a: all-int acc；daily += GARRISON×RATE×ACC_SCALE；
	## 1 擔 = DAYS_PER_WEEK×ACC_SCALE；不得先 ÷7 再量化.
	var acc_scale: int = Params.get_int(PRM_ACC_SCALE)
	var days_pw: int = Params.get_int(PRM_DAYS_PER_WEEK)
	var garrison: Array = Params.get_value(PRM_GARRISON)
	var arms_per: float = Params.get_float(PRM_ARMS_PER)
	var powder_per: float = Params.get_float(PRM_POWDER_PER)
	var thresh: int = days_pw * acc_scale
	## Quote provider registered once in SimLoop.boot（R9-65 C2）；tests set in fixtures.
	var ports: Array = _slots_by_port.keys()
	ports.sort()
	for pid_v in ports:
		var port_id: String = String(pid_v)
		var lv: int = public_level(StringName(port_id), CB_BARRACKS)
		var soldiers := 0
		if lv >= 1 and lv <= garrison.size():
			soldiers = int(garrison[lv - 1])
		var add_arms: float = float(soldiers) * arms_per * float(acc_scale)
		var add_powder: float = float(soldiers) * powder_per * float(acc_scale)
		_acc_arms[port_id] = int(_acc_arms.get(port_id, 0)) + floori(
			AmountQuantize.quantize_amount(add_arms)
		)
		_acc_powder[port_id] = int(_acc_powder.get(port_id, 0)) + floori(
			AmountQuantize.quantize_amount(add_powder)
		)
		_try_garrison_buy(port_id, GOOD_ARMS, _acc_arms, thresh)
		_try_garrison_buy(port_id, GOOD_POWDER, _acc_powder, thresh)


func _try_garrison_buy(port_id: String, good: StringName, acc_map: Dictionary, acc_scale: int) -> void:
	## FRM-14／D-97(d)／WP-67: validate CITY afford + MARKET stock ≥ q, then cash+goods.
	## Later failure → offsetting cash post (keep original); never delete postings.
	var units: int = int(acc_map.get(port_id, 0) / acc_scale)
	if units <= 0:
		return
	var city: StringName = CashLedger.make_city_id(port_id)
	CashLedger.create_account(city, Account.Kind.CITY)
	var market: Dictionary = GoodsLedger.make_market(port_id)
	var stock: int = GoodsLedger.get_qty(market, good)
	var q: int = mini(units, stock)
	var price := 0
	while q > 0:
		var quote: Dictionary = MarketPricer.quote(
			StringName(port_id), good, MarketPricer.SIDE_BUY, q
		)
		if quote.has(MarketPricer.KEY_ERROR):
			q = 0
			break
		price = int(quote[MarketPricer.KEY_TOTAL_LI])
		if price > CashLedger.balance(city):
			q = q - 1
			continue
		## Pre-validate goods path (stock already gated); then write cash then goods.
		if not GoodsLedger.can_transfer(
			market,
			GoodsLedger.make_external(),
			good,
			q,
			GoodsLedger.REASON_CONSUME,
			REQUESTER_SYS08
		):
			q = 0
			break
		var cash_rc: Error = CashLedger.post(
			[
				CashLedger.make_entry(city, 0 - price),
				CashLedger.make_entry(CashLedger.ID_SINK, price),
			],
			REASON_TRADE,
			REQUESTER_SYS08
		)
		if cash_rc != OK:
			q = 0
			break
		var seq: int = GoodsLedger.transfer(
			market,
			GoodsLedger.make_external(),
			good,
			q,
			GoodsLedger.REASON_CONSUME,
			REQUESTER_SYS08
		)
		if seq > 0:
			_note_city_spend(port_id, price, SPEND_CAT_GARRISON)
		else:
			## Goods failed after cash — offsetting entry; keep original post (D-97d).
			CashLedger.post(
				[
					CashLedger.make_entry(CashLedger.ID_SINK, 0 - price),
					CashLedger.make_entry(city, price),
				],
				REASON_TRADE,
				REQUESTER_SYS08
			)
			q = 0
		break
	## D-81: discard unmet whole units; keep fractional remainder (acc % scale).
	acc_map[port_id] = int(acc_map.get(port_id, 0)) % acc_scale


func _step_rent_accrual() -> void:
	## FRM-13 daily: acc_rent += occupants × spend × share × (1−mgmt) × ACC_SCALE.
	var share: float = Params.get_float(PRM_HOUSING_SHARE)
	var mgmt: float = Params.get_float(PRM_MGMT_FEE)
	var spend: Dictionary = Params.get_value(PRM_CLASS_SPEND)
	var acc_scale: int = Params.get_int(PRM_ACC_SCALE)
	var ids: Array = _buildings.keys()
	ids.sort()
	for id_v in ids:
		var bld: Building = _buildings[String(id_v)] as Building
		if bld.build_class != CLASS_RESIDENCE or bld.state != Building.State.ACTIVE:
			continue
		var occ: Dictionary = _occupants_of(bld.building_id)
		var raw: float = 0.0
		for clazz in ["POOR", "CITIZEN", "RICH"]:
			var n: int = int(occ.get(clazz.to_lower(), 0))
			raw += float(n) * float(int(spend.get(clazz, 0)))
		var mid: float = raw * share * (1.0 - mgmt) * float(acc_scale)
		bld.acc_rent_li = bld.acc_rent_li + floori(AmountQuantize.quantize_amount(mid))


func _occupants_of(res_id: StringName) -> Dictionary:
	if PopulationModel != null and PopulationModel.is_loaded():
		return PopulationModel.residence_occupants(res_id)
	return {"poor": 0, "citizen": 0, "rich": 0}


func _step_zone_streak() -> void:
	## FRM-16 daily half: streak++ if pop/sat gates pass, else 0.
	var sat_min: int = Params.get_int(PRM_ZONE_SAT_MIN)
	var pop_mins: Array = Params.get_value(PRM_ZONE_POP_MIN)
	var ports: Array = _slots_by_port.keys()
	ports.sort()
	for pid_v in ports:
		var port_id: String = String(pid_v)
		var next_zone: int = int(_max_open_zone.get(port_id, -1)) + 1
		var idx: int = _zone_table_index(next_zone) ## EX-03 [0]=zone 2
		if idx < 0 or idx >= pop_mins.size():
			_zone_streak[port_id] = 0
			continue
		var pop: int = 0
		if _population != null:
			pop = _population.population(StringName(port_id))
		var sat: int = 0
		if PopulationModel != null and PopulationModel.is_loaded():
			sat = PopulationModel.weighted_avg_sat(port_id)
		if pop >= int(pop_mins[idx]) and sat >= sat_min:
			_zone_streak[port_id] = int(_zone_streak.get(port_id, 0)) + 1
		else:
			_zone_streak[port_id] = 0


func _step_land_held_days() -> void:
	## FRM-SYS08-03／A10: all non-city land accrues held days (built or vacant).
	for slot_key_v in _slots.keys():
		var slot: Slot = _slots[String(slot_key_v)] as Slot
		if _is_city_owner(slot.land_owner):
			continue
		var k := String(slot.slot_id)
		_land_held_days[k] = int(_land_held_days.get(k, 0)) + 1


func _season_wages(port_id: String) -> void:
	## FRM-12 season: due = CEIL(acc / (DAYS_PER_WEEK * ACC_SCALE))? Spec: CEIL(acc_wage ÷ 7) with unit 1/7 li.
	## With D-12g: acc stores ×ACC_SCALE of (1/7) li → due = CEIL(acc / (7 * ACC_SCALE))? 
	## WP-20 stores floori(quantize(workers×base×K^W×ACC_SCALE)) per day as 1/(7) li × ACC_SCALE.
	## due = CEIL(acc / (DAYS_PW * ACC_SCALE)) in li? Spec FRM-12: due = CEIL(acc_wage ÷ 7) when unit is 1/7 li.
	## D-12g: acc units are 1/(DAYS×ACC_SCALE) li → due = CEIL(acc / (DAYS×ACC_SCALE)).
	var days_pw: int = Params.get_int(PRM_DAYS_PER_WEEK)
	var acc_scale: int = Params.get_int(PRM_ACC_SCALE)
	var denom: int = days_pw * acc_scale
	for bld_v in _buildings_by_port.get(port_id, []):
		var bld: Building = bld_v
		if not _is_workshop(bld) or _is_city_owner(bld.owner):
			continue
		if bld.acc_wage_li <= 0:
			continue
		var due: int = int(ceili(float(bld.acc_wage_li) / float(denom)))
		if due <= 0:
			continue
		CashLedger.create_account(bld.owner, Account.Kind.ACTOR)
		CashLedger.charge_mandatory(bld.owner, due, REASON_WAGE, REQUESTER_SYS08)
		bld.acc_wage_li = 0


func _season_rents(port_id: String) -> void:
	var days_pw: int = Params.get_int(PRM_DAYS_PER_WEEK)
	var acc_scale: int = Params.get_int(PRM_ACC_SCALE)
	var denom: int = days_pw * acc_scale
	for bld_v in _buildings_by_port.get(port_id, []):
		var bld: Building = bld_v
		if bld.build_class != CLASS_RESIDENCE:
			continue
		if bld.acc_rent_li <= 0:
			continue
		var r: int = floori(float(bld.acc_rent_li) / float(denom))
		if r <= 0:
			bld.acc_rent_li = 0
			continue
		var owner: StringName = bld.owner
		CashLedger.create_account(owner, Account.Kind.ACTOR)
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - r),
				CashLedger.make_entry(owner, r),
			],
			REASON_RENT,
			REQUESTER_SYS08
		)
		bld.acc_rent_li = 0


func _season_land_and_vacancy(port_id: String) -> void:
	## FRM-03 land rent + FRM-04 vacancy tax → CITY.
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var seasons_y: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	var rate_year: float = Params.get_float(PRM_LAND_RENT_RATE)
	var grace: int = Params.get_int(PRM_VACANCY_GRACE)
	var vac_rates: Array = Params.get_value(PRM_VACANCY_RATE)
	var city: StringName = CashLedger.make_city_id(port_id)
	CashLedger.create_account(city, Account.Kind.CITY)
	var day_now: int = Clock.day if Clock != null else 0
	for slot_v2 in _slots_by_port.get(port_id, []):
		var s2: Slot = slot_v2
		if _is_city_owner(s2.land_owner):
			continue
		## A10: no "held ≤ 0 → full season" fallback; use accrued days only.
		var held2: int = int(_land_held_days.get(String(s2.slot_id), 0))
		var rent2: int = _land_rent_li(s2, held2, days_d, seasons_y, rate_year)
		if rent2 > 0:
			_charge_to_city(s2.land_owner, city, rent2, REASON_LAND_RENT, port_id)
			_season_land_rent_acc[port_id] = int(_season_land_rent_acc.get(port_id, 0)) + rent2
		if s2.building_id != &"":
			continue
		if s2.vacancy_start_day < 0:
			continue
		var vacant_elapsed: int = day_now - s2.vacancy_start_day
		if vacant_elapsed <= grace:
			continue
		var vacant_days: int = mini(held2, vacant_elapsed - grace)
		if vacant_days <= 0:
			continue
		var years: int = int(vacant_elapsed / (seasons_y * days_d))
		var rate_i: int = mini(years, vac_rates.size() - 1)
		if rate_i < 0:
			rate_i = 0
		var vrate: float = float(vac_rates[rate_i])
		var price_now: int = land_price(s2.slot_id)
		var vtax: int = ceili(
			AmountQuantize.quantize_amount(
				float(price_now) * vrate * float(vacant_days) / float(seasons_y * days_d)
			)
		)
		if vtax > 0:
			_charge_to_city(s2.land_owner, city, vtax, REASON_VACANCY_TAX, port_id)
			_season_vacancy_tax_acc[port_id] = int(_season_vacancy_tax_acc.get(port_id, 0)) + vtax


func _land_rent_li(slot: Slot, held: int, days_d: int, seasons_y: int, rate_year: float) -> int:
	var base_li: int = Params.get_int(PRM_BASE_LAND_LI)
	var pop_unit: int = Params.get_int(PRM_POP_UNIT)
	var pop: int = 0
	if _population != null:
		pop = _population.population(StringName(slot.port_id))
	if pop < 1:
		pop = 1
	var ring_f: float = 1.0
	if slot.kind == Slot.Kind.CIVIL:
		var r_total: int = int(_r_by_port.get(slot.port_id, 0))
		var alpha: float = Params.get_float(PRM_RING_ALPHA)
		var ring_base: float = 1.0 + float(r_total - slot.ring)
		if ring_base < 1.0:
			ring_base = 1.0
		ring_f = pow(ring_base, alpha)
		if ring_f < 1.0:
			ring_f = 1.0
	var mid: float = (
		float(base_li)
		* sqrt(float(pop) / float(pop_unit))
		* ring_f
		* rate_year
		* float(held)
		/ float(seasons_y * days_d)
	)
	return ceili(AmountQuantize.quantize_amount(mid))


func _charge_to_city(
	payer: StringName, city: StringName, amount: int, reason: StringName, _port_id: String
) -> void:
	CashLedger.create_account(payer, Account.Kind.ACTOR)
	var bal: int = CashLedger.balance(payer)
	var paid: int = mini(bal, amount)
	var unpaid: int = amount - paid
	if paid > 0:
		CashLedger.post(
			[CashLedger.make_entry(payer, 0 - paid), CashLedger.make_entry(city, paid)],
			reason,
			REQUESTER_SYS08
		)
	if unpaid > 0:
		# Mirror mandatory arrears on payer; city does not receive unpaid.
		CashLedger.charge_mandatory(payer, unpaid, reason, REQUESTER_SYS08)


func _season_city_build_queue(port_id: String) -> void:
	## FRM-15: start next queue items while CITY can afford; no skipping.
	var steps: Array = _queue_by_port.get(port_id, [])
	var pos: int = int(_queue_pos.get(port_id, 0))
	var city: StringName = CashLedger.make_city_id(port_id)
	CashLedger.create_account(city, Account.Kind.CITY)
	while pos < steps.size():
		var step: BuildStep = steps[pos] as BuildStep
		var cash_map: Dictionary = Params.get_value(PRM_BUILD_CASH_LI)
		var cost: int = int(cash_map.get("PUBLIC", 0))
		# Upgrade cost if target_level > 1
		if step.target_level > 1:
			cost = _public_upgrade_cash(port_id, step.target_level)
		## D-102(f) fixture-safe: cost≤0 → stop（no ERR-SYS08-07 zero-amount post）.
		if cost <= 0:
			break
		if CashLedger.balance(city) < cost:
			break
		# Mark as started: advance pos (actual order_build needs free public slot — best-effort).
		var started: bool = _try_start_city_public(port_id, city, step, cost)
		if not started:
			break
		pos = pos + 1
	_queue_pos[port_id] = pos


func _public_upgrade_cash(port_id: String, to_level: int) -> int:
	## FRM-SYS08-07／WP-63 (g): pop × UPGRADE_PER_CAPITA[級].CASH_LI;
	## missing CASH_LI or level OOB → ERR-SYS08-09（不得回 0）.
	var pop: int = 0
	if _population != null:
		pop = _population.population(StringName(port_id))
	var arr: Array = Params.get_value(PRM_UPGRADE_PER_CAPITA)
	var idx: int = _upgrade_level_index(to_level)
	if idx < 0 or idx >= arr.size():
		_record_fail(ERR_SYS08_09, "level", to_level, "UPGRADE_PER_CAPITA index OOB (WP-63 g)")
		return PUBLIC_UPGRADE_CASH_FAIL
	var row: Dictionary = arr[idx] as Dictionary
	if not row.has("CASH_LI"):
		_record_fail(ERR_SYS08_09, "UPGRADE_PER_CAPITA", idx, "CASH_LI key missing (WP-63 g)")
		return PUBLIC_UPGRADE_CASH_FAIL
	var cash_per: int = int(row["CASH_LI"])
	return ceili(AmountQuantize.quantize_amount(float(pop) * float(cash_per)))


func _recompute_r(port_id: String) -> int:
	## FRM-SYS08-01／16: R = max ring among open CIVIL slots (boot + zone-open).
	var r_max := 0
	for s_v in _slots_by_port.get(port_id, []):
		var s: Slot = s_v
		if s.kind != Slot.Kind.CIVIL or not s.zone_open:
			continue
		if s.ring > r_max:
			r_max = s.ring
	_r_by_port[port_id] = r_max
	return r_max


func _try_start_city_public(port_id: String, city: StringName, step: BuildStep, cost: int) -> bool:
	## WP-65／A8／FRM-SYS08-15: L1 → order_build path；upgrade → in-place order_upgrade.
	var type_id: String = step.cb_id
	if step.target_level <= BUILDING_LEVEL_MIN:
		if not _building_defs.has(type_id):
			_record_fail(
				ERR_SYS08_08, "type", type_id, "BuildingDef missing for city queue (WP-65／C-06)"
			)
			return false
		var cash_map: Dictionary = Params.get_value(PRM_BUILD_CASH_LI)
		if not cash_map.has("PUBLIC"):
			_record_fail(
				ERR_SYS08_09, PRM_BUILD_CASH_LI, "PUBLIC", "BUILD_CASH_LI PUBLIC missing (A11)"
			)
			return false
		var slot_id: StringName = _find_public_slot(port_id)
		if slot_id == &"":
			return false
		var bid: StringName = order_build(city, slot_id, StringName(type_id))
		if bid == &"":
			return false
		_note_city_spend(port_id, int(cash_map["PUBLIC"]), SPEND_CAT_BUILD)
		return true
	## Upgrade: find city-owned PUBLIC at level == target − 1；no new slot.
	var target: Building = _find_city_public_upgrade_target(
		port_id, city, StringName(step.cb_id), step.target_level - 1
	)
	if target == null:
		return false
	var up_id: StringName = order_upgrade(city, target.building_id)
	if up_id == &"":
		return false
	_note_city_spend(port_id, cost, SPEND_CAT_BUILD)
	return true


func _find_city_public_upgrade_target(
	port_id: String, city: StringName, cb: StringName, need_level: int
) -> Building:
	## Prefer lowest building_id among ACTIVE city PUBLIC matching cb_id／level.
	var best: Building = null
	var best_id := ""
	for bld_v in _buildings_by_port.get(port_id, []):
		var bld: Building = bld_v
		if bld.owner != city or bld.build_class != CLASS_PUBLIC:
			continue
		if bld.state != Building.State.ACTIVE:
			continue
		if bld.cb_id != cb and bld.type != cb:
			continue
		if bld.level != need_level:
			continue
		var sid: String = String(bld.building_id)
		if best == null or sid < best_id:
			best = bld
			best_id = sid
	return best


func _season_zone_open(port_id: String) -> void:
	var need_days: int = Params.get_int(PRM_ZONE_SAT_DAYS)
	if int(_zone_streak.get(port_id, 0)) < need_days:
		return
	var next_zone: int = int(_max_open_zone.get(port_id, -1)) + 1
	var costs: Array = Params.get_value(PRM_ZONE_OPEN_COST)
	var idx: int = _zone_table_index(next_zone) ## EX-03 [0]=zone 2
	if idx < 0 or idx >= costs.size():
		return
	var cost: int = int(costs[idx])
	var city: StringName = CashLedger.make_city_id(port_id)
	if CashLedger.balance(city) < cost:
		return
	var post_err: Error = CashLedger.post(
		[
			CashLedger.make_entry(city, 0 - cost),
			CashLedger.make_entry(CashLedger.ID_SINK, cost),
		],
		REASON_ZONE_OPEN,
		REQUESTER_SYS08
	)
	if post_err != OK:
		return
	_note_city_spend(port_id, cost, SPEND_CAT_OTHER)
	# Open slots in that zone
	var opened := false
	for s_v in _slots_by_port.get(port_id, []):
		var s: Slot = s_v
		if s.kind == Slot.Kind.CIVIL and s.zone == next_zone:
			s.zone_open = true
			opened = true
	if opened:
		_max_open_zone[port_id] = next_zone
		_recompute_r(port_id)
		_zone_streak[port_id] = 0


func _season_levy(port_id: String) -> void:
	## FRM-17: thr = threshold × avg season spend; levy = FLOOR((bal−thr)×rate) → SINK.
	var city: StringName = CashLedger.make_city_id(port_id)
	CashLedger.create_account(city, Account.Kind.CITY)
	var hist: Array = _city_spend_hist.get(port_id, [])
	var seasons_y: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	var avg := 0
	if hist.is_empty():
		avg = int(_season_city_spend.get(port_id, 0))
	else:
		var n: int = mini(hist.size(), seasons_y)
		var sum := 0
		for i in range(hist.size() - n, hist.size()):
			sum = sum + int(hist[i])
		avg = int(sum / maxi(1, n))
	# No spend baseline yet → no levy (avoids thr=0 wiping CITY on first seasons).
	if avg <= 0:
		return
	var thr_mult: int = Params.get_int(PRM_LEVY_THRESHOLD)
	var thr: int = thr_mult * avg
	var bal: int = CashLedger.balance(city)
	if bal <= thr:
		return
	var rate: float = Params.get_float(PRM_LEVY_RATE)
	var levy: int = floori(float(bal - thr) * rate)
	if levy <= 0:
		return
	CashLedger.post(
		[
			CashLedger.make_entry(city, 0 - levy),
			CashLedger.make_entry(CashLedger.ID_SINK, levy),
		],
		REASON_LEVY,
		REQUESTER_SYS08
	)
	_note_city_spend(port_id, levy, SPEND_CAT_LEVY)


func _clear_season_accums(port_id: String) -> void:
	var spent: int = int(_season_city_spend.get(port_id, 0))
	var hist: Array = _city_spend_hist.get(port_id, [])
	hist.append(spent)
	_city_spend_hist[port_id] = hist
	_season_city_spend[port_id] = 0
	_season_spend_cat[port_id] = _empty_spend_cat()
	_season_land_rent_acc[port_id] = 0
	_season_vacancy_tax_acc[port_id] = 0
	_acc_arms[port_id] = 0
	_acc_powder[port_id] = 0
	for k in _land_held_days.keys():
		var slot: Slot = _slot(StringName(String(k)))
		if slot != null and slot.port_id == port_id:
			_land_held_days[k] = 0
	for bld_v in _buildings_by_port.get(port_id, []):
		var bld: Building = bld_v
		bld.acc_wage_li = 0
		bld.acc_rent_li = 0


func _empty_spend_cat() -> Dictionary:
	return {
		SPEND_CAT_BUILD: 0,
		SPEND_CAT_GARRISON: 0,
		SPEND_CAT_LEVY: 0,
		SPEND_CAT_OTHER: 0,
	}


func _note_city_spend(port_id: String, amount: int, category: String = SPEND_CAT_OTHER) -> void:
	if amount <= 0:
		return
	_season_city_spend[port_id] = int(_season_city_spend.get(port_id, 0)) + amount
	var cat: Dictionary = _season_spend_cat.get(port_id, _empty_spend_cat()) as Dictionary
	cat[category] = int(cat.get(category, 0)) + amount
	_season_spend_cat[port_id] = cat


func _obs05_key(port_id: String, season_index: int) -> String:
	return "%s|%d" % [port_id, season_index]


func _current_season_index() -> int:
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	if days_d <= 0:
		return 0
	var day: int = Clock.day if Clock != null else 0
	## season_step runs at season boundary; day already advanced to next season start.
	return maxi(0, int(day / days_d) - 1)


func _persist_obs05_season(port_id: String) -> void:
	var si: int = _current_season_index()
	var key: String = _obs05_key(port_id, si)
	var cat: Dictionary = (
		_season_spend_cat.get(port_id, _empty_spend_cat()) as Dictionary
	).duplicate()
	_obs05_spend_by_cat[key] = cat
	_obs05_land_rent[key] = int(_season_land_rent_acc.get(port_id, 0))
	_obs05_vacancy_tax[key] = int(_season_vacancy_tax_acc.get(port_id, 0))


func city_spend_by_category(port_id: StringName, season_index: int) -> Dictionary:
	## WP-67／D-97(e) OBS-05: keys build_upgrade_li、garrison_li、levy_li、other_li.
	assert(_loaded, "BuildingEconomy.city_spend_by_category before load")
	_clear_last_error()
	var pid: String = String(port_id)
	if not _slots_by_port.has(pid) and not _buildings_by_port.has(pid):
		_record_fail(ERR_OBS05_LOOKUP, "port_id", port_id, "unknown port for OBS-05 spend")
		return {}
	var key: String = _obs05_key(pid, season_index)
	if not _obs05_spend_by_cat.has(key):
		_record_fail(ERR_OBS05_LOOKUP, "season_index", season_index, "season not settled (OBS-05)")
		return {}
	return (_obs05_spend_by_cat[key] as Dictionary).duplicate()


func season_land_rent_li(port_id: StringName, season_index: int) -> int:
	## WP-67／D-97(e) OBS-05 land rent total for settled season; unset → −1.
	assert(_loaded, "BuildingEconomy.season_land_rent_li before load")
	_clear_last_error()
	var pid: String = String(port_id)
	if not _slots_by_port.has(pid) and not _buildings_by_port.has(pid):
		_record_fail(ERR_OBS05_LOOKUP, "port_id", port_id, "unknown port for OBS-05 rent")
		return -1
	var key: String = _obs05_key(pid, season_index)
	if not _obs05_land_rent.has(key):
		_record_fail(ERR_OBS05_LOOKUP, "season_index", season_index, "season not settled (OBS-05)")
		return -1
	return int(_obs05_land_rent[key])


func season_vacancy_tax_li(port_id: StringName, season_index: int) -> int:
	## WP-67／D-97(e) OBS-05 vacancy tax total for settled season; unset → −1.
	assert(_loaded, "BuildingEconomy.season_vacancy_tax_li before load")
	_clear_last_error()
	var pid: String = String(port_id)
	if not _slots_by_port.has(pid) and not _buildings_by_port.has(pid):
		_record_fail(ERR_OBS05_LOOKUP, "port_id", port_id, "unknown port for OBS-05 vacancy")
		return -1
	var key: String = _obs05_key(pid, season_index)
	if not _obs05_vacancy_tax.has(key):
		_record_fail(ERR_OBS05_LOOKUP, "season_index", season_index, "season not settled (OBS-05)")
		return -1
	return int(_obs05_vacancy_tax[key])


func _load_build_queues(queue_dir: String, errors: Array) -> void:
	## A9 sorted listing; A11 report bad tres (missing dir OK — empty queues).
	_queue_by_port = {}
	_queue_pos = {}
	var abs_dir: String = ProjectSettings.globalize_path(queue_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for fname_v in _list_tres_sorted(queue_dir):
		var fname: String = String(fname_v)
		var path: String = queue_dir.path_join(fname)
		var res: Resource = load(path)
		if res == null:
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, fname, "build queue load failed"))
			continue
		if not (res is BuildStep):
			errors.append(_err(CODE_PARAMS_NOT_LOADED, path, fname, "not BuildStep"))
			continue
		var step: BuildStep = res as BuildStep
		if not _queue_by_port.has(step.port_id):
			_queue_by_port[step.port_id] = []
		(_queue_by_port[step.port_id] as Array).append(step)
	for pid in _queue_by_port.keys():
		var arr: Array = _queue_by_port[pid]
		arr.sort_custom(func(a: BuildStep, b: BuildStep) -> bool: return a.step < b.step)
		_queue_pos[pid] = 0


func _validate_build_queue_import_d97a(
	city_by_port: Dictionary, opening_publics: Array, errors: Array
) -> void:
	## FRM-SYS08-21／D-97(a)／N1: slots + level continuity; ERR-SYS08-13; collect all (C-06).
	## Opening buildings count as level 1 (or their tres level); unbuilt cb_id starts at 0.
	var open_by_port: Dictionary = {}
	for op_v in opening_publics:
		var op: OpeningPublic = op_v as OpeningPublic
		if op == null:
			continue
		if not open_by_port.has(op.port_id):
			open_by_port[op.port_id] = []
		(open_by_port[op.port_id] as Array).append(op)

	## Only ports in PortRegistry（fixture boots must not validate unrelated formal ports）.
	var ports: Array = []
	for pid_v in PortRegistry.all_ids():
		ports.append(String(pid_v))
	ports.sort()

	for pid_v2 in ports:
		var port_id: String = String(pid_v2)
		var slots: int = 0
		if city_by_port.has(port_id):
			slots = int((city_by_port[port_id] as CityCenterDef).public_slots)
		var opens: Array = open_by_port.get(port_id, [])
		var open_n: int = opens.size()
		if open_n > slots:
			errors.append(
				_err(
					ERR_SYS08_13,
					"public_slots",
					{
						"port_id": port_id,
						"step": 0,
						"cb_id": "",
						"value": open_n,
						"public_slots": slots,
						"opening_public": open_n,
					},
					"opening_public count exceeds public_slots (D-97a)"
				)
			)
		var levels: Dictionary = {}
		for op2_v in opens:
			var op2: OpeningPublic = op2_v as OpeningPublic
			## Opening building present → at least level 1 (tres level if higher).
			var lv: int = maxi(1, int(op2.level))
			levels[String(op2.cb_id)] = lv

		var steps: Array = _queue_by_port.get(port_id, [])
		var new_seen: int = 0
		var remaining_new: int = maxi(0, slots - open_n)
		for step_v in steps:
			var step: BuildStep = step_v as BuildStep
			if step == null:
				continue
			var cb: String = String(step.cb_id)
			var cur: int = int(levels.get(cb, 0))
			var expected: int = cur + 1
			if step.target_level != expected:
				errors.append(
					_err(
						ERR_SYS08_13,
						"target_level",
						{
							"port_id": port_id,
							"step": step.step,
							"cb_id": cb,
							"value": step.target_level,
							"expected": expected,
						},
						"build_queue target_level must be current+1 (D-97a／EX skip-level)"
					)
				)
			else:
				levels[cb] = step.target_level

			if step.target_level == 1:
				new_seen += 1
				if remaining_new < 0 or new_seen > remaining_new:
					## EX-08-21-04: report the overflowing new-build step.
					errors.append(
						_err(
							ERR_SYS08_13,
							"public_slots",
							{
								"port_id": port_id,
								"step": step.step,
								"cb_id": cb,
								"value": open_n + new_seen,
								"public_slots": slots,
								"opening_public": open_n,
							},
							"opening_public + target_level=1 exceeds public_slots (D-97a／EX-08-21-04)"
						)
					)


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
	_queue_by_port = {}
	_queue_pos = {}
	_zone_streak = {}
	_acc_arms = {}
	_acc_powder = {}
	_city_spend_hist = {}
	_season_city_spend = {}
	_obs05_spend_by_cat = {}
	_obs05_land_rent = {}
	_obs05_vacancy_tax = {}
	_season_spend_cat = {}
	_season_land_rent_acc = {}
	_season_vacancy_tax_acc = {}
	_land_held_days = {}
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
