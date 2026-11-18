extends Node
## Autoload: BuildingEconomy — SYS-08 data layer (TechSpec §11 / WP-18).
## _ready() field init only; load_and_validate() builds ST-SLOT (11-03).

signal land_bought(actor: StringName, slot_id: StringName, seq: int)

const SYS_ID := &"SYS-08"
const SCRIPT_PATH := "res://autoload/building_economy.gd"

const ZONES_DIR := "res://data/zones/"
const CITY_CENTER_DIR := "res://data/city_center/"
const TRES_SUFFIX := ".tres"
const COMPOSITE_JOINER := "__"

const KIND_WAREHOUSE := GoodsLedger.KIND_WAREHOUSE

const ERR_SYS08_01 := &"ERR-SYS08-01"
const ERR_SYS08_02 := &"ERR-SYS08-02"
const ERR_SYS08_07 := &"ERR-SYS08-07"
const ERR_SYS08_08 := &"ERR-SYS08-08"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_PORT_REGISTRY_NOT_LOADED := &"PORT_REGISTRY_NOT_LOADED"
const CODE_POPULATION_PROVIDER_MISSING := &"POPULATION_PROVIDER_MISSING"

const REASON_LAND_PURCHASE := &"LAND_PURCHASE"
const REQUESTER_SYS08 := &"SYS-08"

const PRM_BASE_LAND_LI := "PRM-SYS08-BASE_LAND_LI"
const PRM_POP_UNIT := "PRM-SYS08-POP_UNIT"
const PRM_SCARCITY_FLOOR := "PRM-SYS08-SCARCITY_FLOOR"
const PRM_RING_ALPHA := "PRM-SYS08-RING_ALPHA"
const PRM_KONTOR_PLOTS := "PRM-SYS08-KONTOR_PLOTS"
const PRM_KONTOR_CAP := "PRM-SYS08-KONTOR_CAP"
const PRM_WAREHOUSE_CAP := "PRM-SYS08-WAREHOUSE_CAP"

const SLOT_PREFIX := "SLOT:"
const SLOT_ID_FMT := "SLOT:%s:%04d"

var _slots: Dictionary = {} ## slot_id:String → Slot
var _slots_by_port: Dictionary = {} ## port_id:String → Array[Slot]
var _r_by_port: Dictionary = {} ## port_id:String → int open-zone ring sum
var _population: PopulationProvider = null
var _warehouse_provider: _WarehouseCapacityAdapter = null
var _loaded: bool = false
var _last_error: Dictionary = {}


func _ready() -> void:
	_clear_state()


func set_population_provider(provider: PopulationProvider) -> void:
	if _loaded:
		push_error("BuildingEconomy.set_population_provider called after load (D-11d); ignored")
		return
	_population = provider


func has_population_provider() -> bool:
	return _population != null


func get_warehouse_capacity_provider() -> CapacityProvider:
	if _warehouse_provider == null:
		_warehouse_provider = _WarehouseCapacityAdapter.new(self)
	return _warehouse_provider


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func slot_id(port_id: String, seq_n: int) -> StringName:
	return StringName(SLOT_ID_FMT % [port_id, seq_n])


func load_and_validate(
	zones_dir: String = ZONES_DIR,
	city_center_dir: String = CITY_CENTER_DIR
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

	var zones_by_port: Dictionary = _load_zones(zones_dir, errors)
	var city_by_port: Dictionary = _load_city_centers(city_center_dir, errors)
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
	# PRM-SYS08-BASE_LAND_LI
	var base_li: int = Params.get_int(PRM_BASE_LAND_LI)
	# PRM-SYS08-POP_UNIT
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
		# PRM-SYS08-RING_ALPHA
		var alpha: float = Params.get_float(PRM_RING_ALPHA)
		var ring_base: float = 1.0 + float(r_total - slot.ring)
		if ring_base < 1.0:
			ring_base = 1.0
		ring_f = pow(ring_base, alpha)
		if ring_f < 1.0:
			ring_f = 1.0

	var pop_ratio: float = float(pop) / float(pop_unit)
	var mid: float = float(base_li) * sqrt(pop_ratio) * scarcity * ring_f
	# D-11e: quantize then ceili
	var q: float = AmountQuantize.quantize_amount(mid)
	return ceili(q)


func buy_land(actor: StringName, slot_key: StringName) -> int:
	assert(_loaded, "BuildingEconomy.buy_land before load")
	_clear_last_error()
	var slot: Slot = _slot(slot_key)
	if slot == null:
		return _fail(ERR_SYS08_08, "slot_id", slot_key, "unknown slot")

	if slot.kind == Slot.Kind.CIVIL and not slot.zone_open:
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
	var seq: int = GoodsLedger.next_seq() - 1
	land_bought.emit(actor, slot_key, seq)
	return seq


func warehouse_capacity(_actor: StringName, _port: StringName) -> int:
	assert(_loaded, "BuildingEconomy.warehouse_capacity before load")
	# FRM-19: no kontor → 0 (WP-18: no buildings)
	return 0


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


func workplaces(_port: StringName) -> Array:
	assert(_loaded, "BuildingEconomy.workplaces before load")
	return []


func residences(_port: StringName) -> Array:
	assert(_loaded, "BuildingEconomy.residences before load")
	return []


func public_level(_port: StringName, _cb_id: StringName) -> int:
	assert(_loaded, "BuildingEconomy.public_level before load")
	return 0


func ring_count_open(_port_id: String) -> int:
	return int(_r_by_port.get(_port_id, 0))


func slots_for_port(_port_id: String) -> Array:
	return _slots_by_port.get(_port_id, [])


func get_slot(slot_key: StringName) -> Slot:
	return _slot(slot_key)


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

	var zone_rows: Array = zones_by_port.get(port_id, [])
	zone_rows.sort_custom(func(a: ZoneDef, b: ZoneDef) -> bool: return a.zone < b.zone)

	for zd_variant in zone_rows:
		var zd: ZoneDef = zd_variant
		if zd.open_at_start == 1:
			r_open = r_open + zd.rings
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

	# PRM-SYS08-KONTOR_PLOTS
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
	# PRM-SYS08-SCARCITY_FLOOR
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


func _clear_state() -> void:
	_slots = {}
	_slots_by_port = {}
	_r_by_port = {}
	_loaded = false
	_clear_last_error()


func _clear_last_error() -> void:
	_last_error = {}


func _fail(code: StringName, field: String, value: Variant, message: String) -> int:
	_record_fail(code, field, value, message)
	return 0


func _record_fail(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = _err(code, field, value, message)
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