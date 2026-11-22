extends Node
## Autoload: ShipRegistry — SYS-13／14 ships & voyages (TechSpec 13-07／D-14b／D-19f／D-20a).
## _ready() only clears fields; load_and_validate／apply_opening_init via SimLoop.boot (2.2-01).

signal ship_departed(
	ship_id: StringName, from_port: StringName, to_port: StringName, depart_tick: int, arrival_tick: int
)
signal ship_rerouted(ship_id: StringName, dest_port: StringName, arrival_tick: int)
signal ship_arrived(
	ship_id: StringName, port_id: StringName, from_port_id: StringName, tick: int
)
signal crew_changed(ship_id: StringName, crew: int)

const SYS_ID := &"SYS-13"
const SCRIPT_PATH := "res://autoload/ship_registry.gd"
const REQUESTER := &"SYS-13"

const ERR_SYS13_01 := &"ERR-SYS13-01"
const ERR_SYS13_02 := &"ERR-SYS13-02"
const ERR_SYS13_03 := &"ERR-SYS13-03"
const ERR_SYS13_04 := &"ERR-SYS13-04"
const ERR_SYS13_05 := &"ERR-SYS13-05"
const ERR_SYS13_06 := &"ERR-SYS13-06"
const ERR_SYS13_07 := &"ERR-SYS13-07"
const ERR_SYS13_12 := &"ERR-SYS13-12"
const ERR_SYS14_02 := &"ERR-SYS14-02"
const ERR_SYS14_03 := &"ERR-SYS14-03"
const ERR_SYS14_04 := &"ERR-SYS14-04"
const ERR_SYS14_05 := &"ERR-SYS14-05"
## D-14b: SailorPoolProvider must be injected before load.
const ERR_SYS13_POOL_MISSING := &"ERR-SYS13-POOL_MISSING"

const PRM_CAPACITY := "PRM-SYS13-CAPACITY"
const PRM_TPW := "PRM-SYS13-TICKS_PER_WAYPOINT"
const PRM_CREW := "PRM-SYS13-CREW"
const PRM_PRICE_CASH := "PRM-SYS13-PRICE_CASH"
const PRM_BUILD_MATERIALS := "PRM-SYS13-BUILD_MATERIALS"
const PRM_BUILD_DAYS := "PRM-SYS13-BUILD_DAYS"
const PRM_CREW_WAGE_WK := "PRM-SYS13-CREW_WAGE_WK"
const PRM_REPAIR_RATE := "PRM-SYS13-REPAIR_RATE_SEASON"
const PRM_YARD_CONCURRENT := "PRM-SYS13-YARD_CONCURRENT"
const PRM_SALVAGE_RATE := "PRM-SYS13-SALVAGE_RATE"
const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_DAYS_PER_WEEK := "PRM-SYS04-DAYS_PER_WEEK"
const HOLD_CHECK_FAILURE := -1 ## EX-02

## 03_Systems 10.7「無值」keys — missing → ERR-SYS13-12 (D-19f a).
const NOVALUE_PRMS: Array[String] = [
	PRM_CAPACITY,
	PRM_TPW,
	PRM_CREW,
	PRM_PRICE_CASH,
	PRM_BUILD_MATERIALS,
	PRM_BUILD_DAYS,
	PRM_CREW_WAGE_WK,
	PRM_REPAIR_RATE,
]

const REASON_CREW_WAGE := &"CREW_WAGE"
const REASON_SHIP_REPAIR := &"SHIP_REPAIR"

const CB_DOCK := &"CB-06"
const OPENING_PORT := "PT-10"
const OPENING_TYPE := &"SH-01"
const PLAYER_ACTOR := &"ACT-PLAYER"

const SHIP_ID_FMT := "SHIP:%04d"

## UNIT-DRAFT ints (fixtures use 0=淺; TST-SYS13-14 ladder).
const DRAFT_SHALLOW := 0
const DRAFT_MEDIUM := 1
const DRAFT_DEEP := 2

const SHIP_DRAFT := {
	"SH-01": DRAFT_SHALLOW,
	"SH-02": DRAFT_MEDIUM,
	"SH-03": DRAFT_MEDIUM,
	"SH-04": DRAFT_DEEP,
}

const PATH_KEY_LANE_ID := "lane_id"
const PATH_KEY_FROM_NODE := "from_node"

var _loaded: bool = false
var _sailor_pool: SailorPoolProvider = null
var _ship_observer: ShipEventObserver = null
var _ships: Dictionary = {} ## ship_id:String → Ship
var _next_ship_seq: int = 1
var _last_error: Dictionary = {}
var _hold_provider: _HoldCapacityAdapter = null
var _pending_signals: Array = [] ## {name:String, args:Array}


func _ready() -> void:
	_clear_runtime(false)


func set_sailor_pool_provider(provider: SailorPoolProvider) -> void:
	## D-14b: inject before load only (same spirit as D-11d).
	if _loaded:
		push_error("ShipRegistry.set_sailor_pool_provider called after load; ignored")
		return
	_sailor_pool = provider


func has_sailor_pool_provider() -> bool:
	return _sailor_pool != null


func set_ship_observer(observer: ShipEventObserver) -> void:
	## D-34d／25.1 H: SimLoop.boot injects IntelLedger adapter (ERR-SYS15-06 if missing).
	_ship_observer = observer


func has_ship_observer() -> bool:
	return _ship_observer != null


func get_hold_capacity_provider() -> CapacityProvider:
	if _hold_provider == null:
		_hold_provider = _HoldCapacityAdapter.new(self)
	return _hold_provider


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func load_and_validate() -> Array:
	var errors: Array = []
	_clear_runtime(true)
	if not Params.is_loaded():
		errors.append(_err(ERR_SYS13_12, "Params", null, "Params must load before ShipRegistry"))
		_emit_errors(errors)
		return errors
	if _sailor_pool == null:
		errors.append(
			_err(
				ERR_SYS13_POOL_MISSING,
				"SailorPoolProvider",
				null,
				"SailorPoolProvider must be injected before load (D-14b)"
			)
		)
	errors.append_array(_validate_params())
	if not errors.is_empty():
		_emit_errors(errors)
		_loaded = false
		return errors
	_loaded = true
	return errors


func spawn_docked_ship(
	type: StringName, owner: StringName, port_id: StringName, crew: int
) -> StringName:
	## Test／tooling helper (not 10.5 H); registers HOLD at port. Production opening uses apply_opening_init.
	assert(_loaded, "ShipRegistry.spawn_docked_ship before load")
	var s: Ship = _create_ship(type, owner, port_id, crew)
	GoodsLedger.ensure_hold_registered(
		GoodsLedger.make_hold(String(s.ship_id), String(owner)), port_id
	)
	return s.ship_id


func apply_opening_init() -> Array:
	## FRM-SYS13-06: player SH-01 @ PT-10, full crew, no beggar deduction (OQ-16q／D-19f d).
	assert(_loaded, "ShipRegistry.apply_opening_init before load")
	var errors: Array = []
	if not Params.has_prm(StringName(PRM_CREW)):
		errors.append(_err(ERR_SYS13_12, PRM_CREW, null, "CREW required for opening SH-01"))
		_emit_errors(errors)
		return errors
	var crew_map: Dictionary = Params.get_value(StringName(PRM_CREW))
	var crew_n: int = int(crew_map.get(String(OPENING_TYPE), 0))
	if crew_n < 1:
		errors.append(_err(ERR_SYS13_12, PRM_CREW, crew_n, "CREW[SH-01] must be ≥ 1"))
		_emit_errors(errors)
		return errors
	var ship: Ship = _create_ship(OPENING_TYPE, PLAYER_ACTOR, StringName(OPENING_PORT), crew_n)
	var reg_rc: int = GoodsLedger.ensure_hold_registered(
		GoodsLedger.make_hold(String(ship.ship_id), String(PLAYER_ACTOR)),
		StringName(OPENING_PORT)
	)
	if reg_rc != GoodsLedger.CODE_OK:
		errors.append(
			_err(ERR_SYS13_01, "HOLD", ship.ship_id, "opening HOLD registration failed")
		)
		_emit_errors(errors)
		return errors
	return errors


func validate() -> Array:
	return _validate_params()


func ship_ids(owner: StringName) -> Array:
	var out: Array = []
	var keys: Array = _ships.keys()
	keys.sort()
	for k in keys:
		var s: Ship = _ships[k]
		if s.owner == owner:
			out.append(s.ship_id)
	return out


func ship_info(ship_id: StringName) -> Dictionary:
	var s: Ship = _ships.get(String(ship_id), null) as Ship
	if s == null:
		_record(ERR_SYS13_01, "ship_id", ship_id, "unknown ship_id")
		return {}
	_clear_last()
	return s.to_info()


func hire_crew(actor: StringName, ship_id: StringName, n: int) -> int:
	## FRM-SYS13-04.
	assert(_loaded, "ShipRegistry.hire_crew before load")
	_clear_last()
	var s: Ship = _require_owned_docked(actor, ship_id)
	if s == null:
		return 0
	if n <= 0:
		_record(ERR_SYS13_01, "n", n, "hire_crew n must be > 0")
		return 0
	var cap: int = _crew_cap(s.type)
	if s.crew + n > cap:
		_record(ERR_SYS13_05, "crew", s.crew + n, "hire would exceed CREW[type]")
		return 0
	var hired: int = _sailor_pool.hire_sailors(s.port_id, n)
	if hired != n:
		_record(ERR_SYS13_06, "beggars", hired, "insufficient beggars (ERR-SYS13-06)")
		return 0
	s.crew = s.crew + n
	_queue_signal("crew_changed", [s.ship_id, s.crew])
	_flush_signals()
	return n


func fire_crew(actor: StringName, ship_id: StringName, n: int) -> int:
	## FRM-SYS13-05.
	assert(_loaded, "ShipRegistry.fire_crew before load")
	_clear_last()
	var s: Ship = _require_owned_docked(actor, ship_id)
	if s == null:
		return 0
	if n <= 0:
		_record(ERR_SYS13_01, "n", n, "fire_crew n must be > 0")
		return 0
	if n > s.crew:
		_record(ERR_SYS13_07, "n", n, "fire_crew n > crew")
		return 0
	var released: int = _sailor_pool.release_sailors(s.port_id, n)
	if released != n:
		_record(ERR_SYS13_01, "release", released, "release_sailors failed")
		return 0
	s.crew = s.crew - n
	_queue_signal("crew_changed", [s.ship_id, s.crew])
	_flush_signals()
	return n


func sail(actor: StringName, ship_id: StringName, dest_port: StringName) -> int:
	## FRM-SYS14-03; D-20a container_departed after SAILING.
	assert(_loaded, "ShipRegistry.sail before load")
	_clear_last()
	var s: Ship = _ships.get(String(ship_id), null) as Ship
	if s == null:
		_record(ERR_SYS13_01, "ship_id", ship_id, "unknown ship_id")
		return 0
	if s.owner != actor:
		_record(ERR_SYS13_02, "owner", actor, "actor is not ship owner")
		return 0
	if s.state != Ship.STATE_DOCKED:
		_record(ERR_SYS13_03, "state", s.state, "sail requires DOCKED")
		return 0
	var dest: String = String(dest_port)
	var origin: String = String(s.port_id)
	if dest == origin:
		_record(ERR_SYS14_04, "dest_port", dest, "dest equals current port")
		return 0
	if s.crew < _crew_cap(s.type):
		_record(ERR_SYS13_04, "crew", s.crew, "crew < CREW[type]")
		return 0
	var ship_draft: int = int(SHIP_DRAFT.get(String(s.type), DRAFT_DEEP))
	var dest_draft: int = port_draft(dest_port)
	if ship_draft > dest_draft:
		_record(ERR_SYS14_02, "draft", ship_draft, "ship draft exceeds dest port_draft")
		return 0
	var path: Array = SeaLanes.path(origin, dest)
	if path.is_empty():
		_record(ERR_SYS14_03, "path", "%s→%s" % [origin, dest], "no path")
		return 0
	var tpw: int = _tpw(s.type)
	var total_wp: int = _path_waypoints(path)
	var depart_tick: int = Clock.tick
	var arrival: int = depart_tick + total_wp * tpw
	var from_port: StringName = s.port_id
	s.origin_port = from_port
	s.dest_port = dest_port
	s.path = path
	s.wp_offset = 0
	s.leg_start_tick = depart_tick
	s.arrival_tick = arrival
	s.last_port_departure_tick = depart_tick
	s.state = Ship.STATE_SAILING
	s.port_id = &""
	var hold_id: StringName = s.hold_container_id()
	GoodsLedger.container_departed(hold_id)
	GoodsLedger.set_container_port(hold_id, &"")
	_queue_signal("ship_departed", [s.ship_id, from_port, dest_port, depart_tick, arrival])
	_flush_signals()
	# 25.1 F／D-34d: on_departed after SAILING committed, before return (snapshot fail ≠ block sail).
	if _ship_observer != null:
		_ship_observer.on_departed(s.ship_id, s.owner, from_port, depart_tick)
	return arrival


func reroute(actor: StringName, ship_id: StringName, dest_port: StringName) -> int:
	## FRM-SYS14-05.
	assert(_loaded, "ShipRegistry.reroute before load")
	_clear_last()
	var s: Ship = _ships.get(String(ship_id), null) as Ship
	if s == null:
		_record(ERR_SYS13_01, "ship_id", ship_id, "unknown ship_id")
		return 0
	if s.owner != actor:
		_record(ERR_SYS13_02, "owner", actor, "actor is not ship owner")
		return 0
	if s.state != Ship.STATE_SAILING:
		_record(ERR_SYS14_05, "state", s.state, "reroute requires SAILING")
		return 0
	var dest: String = String(dest_port)
	var ship_draft: int = int(SHIP_DRAFT.get(String(s.type), DRAFT_DEEP))
	if ship_draft > port_draft(dest_port):
		_record(ERR_SYS14_02, "draft", ship_draft, "ship draft exceeds dest port_draft")
		return 0
	var tpw: int = _tpw(s.type)
	var t_now: int = Clock.tick
	var elapsed: int = t_now - s.leg_start_tick
	if elapsed < 0:
		elapsed = 0
	var k: int = int(floori(float(elapsed) / float(tpw)))
	var t_next: int = s.leg_start_tick + (k + 1) * tpw
	var completed: int = s.wp_offset + (k + 1)
	var loc: Dictionary = _locate_completed(s.path, completed)
	if loc.is_empty():
		_record(ERR_SYS14_03, "reroute", ship_id, "cannot locate ship for reroute")
		return 0
	var node_a: String = String(loc["node_a"])
	var node_b: String = String(loc["node_b"])
	var n_wp: int = int(loc["n"])
	var j_wp: int = int(loc["j"])
	var lane_id: String = String(loc["lane_id"])
	var hop_index: int = int(loc["hop_index"])
	var forward_cost: int = (n_wp - j_wp) + _dist_waypoints(node_b, dest)
	var back_allowed: bool = not (_is_port_node(node_a) and node_a != dest)
	var back_cost: int = j_wp + _dist_waypoints(node_a, dest)
	var go_forward: bool = true
	if back_allowed and back_cost < forward_cost:
		go_forward = false
	var new_path: Array = []
	var remaining: int = 0
	var new_offset: int = 0
	if go_forward:
		# Keep current hop + hops after it; offset = j (already done on first hop).
		new_path.append({PATH_KEY_LANE_ID: lane_id, PATH_KEY_FROM_NODE: node_a})
		for i in range(hop_index + 1, s.path.size()):
			new_path.append(s.path[i])
		if node_b != dest:
			# Replace tail after current lane with path(b, dest) if dest changed.
			var old_tail_dest := _path_end_node(s.path)
			if dest != String(s.dest_port) or old_tail_dest != dest:
				new_path = [{PATH_KEY_LANE_ID: lane_id, PATH_KEY_FROM_NODE: node_a}]
				var tail: Array = SeaLanes.path(node_b, dest) if node_b != dest else []
				if node_b != dest and tail.is_empty():
					_record(ERR_SYS14_03, "path", "%s→%s" % [node_b, dest], "no forward path")
					return 0
				for hop in tail:
					new_path.append(hop)
		new_offset = j_wp
		remaining = _path_waypoints(new_path) - new_offset
	else:
		# Turn back toward a, then path(a, dest). First hop reversed.
		new_path = [{PATH_KEY_LANE_ID: lane_id, PATH_KEY_FROM_NODE: node_b}]
		if node_a != dest:
			var tail_b: Array = SeaLanes.path(node_a, dest)
			if tail_b.is_empty():
				_record(ERR_SYS14_03, "path", "%s→%s" % [node_a, dest], "no back path")
				return 0
			for hop in tail_b:
				new_path.append(hop)
		# At t_next we are j from a; reversing means (n-j) already toward... wait:
		# j = waypoints passed from a toward b. Going back: need j waypoints to reach a.
		# So offset on reversed hop (from b) = n - j (already "done" from b side? No —
		# at boundary after j from a, distance to a is j if we reverse. Fresh reverse hop
		# from b with offset = n - j means remaining on first hop = n - (n-j) = j. ✓
		new_offset = n_wp - j_wp
		remaining = _path_waypoints(new_path) - new_offset
	s.dest_port = dest_port
	s.path = new_path
	s.wp_offset = new_offset
	s.leg_start_tick = t_next
	s.arrival_tick = t_next + remaining * tpw
	_queue_signal("ship_rerouted", [s.ship_id, dest_port, s.arrival_tick])
	_flush_signals()
	return s.arrival_tick


func position(ship_id: StringName) -> Dictionary:
	## FRM-SYS14-04.
	assert(_loaded, "ShipRegistry.position before load")
	_clear_last()
	var s: Ship = _ships.get(String(ship_id), null) as Ship
	if s == null:
		_record(ERR_SYS13_01, "ship_id", ship_id, "unknown ship_id")
		return {}
	if s.state == Ship.STATE_DOCKED:
		return {"state": s.state, "port_id": s.port_id, "tick": Clock.tick}
	var tpw: int = _tpw(s.type)
	var elapsed: int = Clock.tick - s.leg_start_tick
	if elapsed < 0:
		elapsed = 0
	var k: int = int(floori(float(elapsed) / float(tpw)))
	var completed: int = s.wp_offset + k
	var loc: Dictionary = _locate_completed(s.path, completed)
	if loc.is_empty():
		return {
			"state": s.state,
			"dest_port": s.dest_port,
			"arrival_tick": s.arrival_tick,
			"tick": Clock.tick,
		}
	return {
		"state": s.state,
		"lane_id": loc["lane_id"],
		"from_node": loc["node_a"],
		"waypoints_done": loc["j"],
		"waypoints_total": loc["n"],
		"tick": Clock.tick,
	}


func port_draft(port_id: StringName) -> int:
	## FRM-SYS13-11.
	assert(_loaded, "ShipRegistry.port_draft before load")
	var port: PortDef = PortRegistry.get_port(String(port_id))
	if port == null:
		_record(ERR_SYS13_01, "port_id", port_id, "unknown port")
		return HOLD_CHECK_FAILURE
	var base: int = int(port.draft_limit_class)
	var dock_lv: int = 0
	if BuildingEconomy.is_loaded():
		dock_lv = BuildingEconomy.public_level(port_id, CB_DOCK)
	var boosted: int = base + maxi(0, dock_lv - 1)
	return mini(DRAFT_DEEP, boosted)


func can_trade(ship_id: StringName, port_id: StringName) -> bool:
	## OQ-16h: DOCKED and same port.
	var s: Ship = _ships.get(String(ship_id), null) as Ship
	if s == null:
		return false
	return s.state == Ship.STATE_DOCKED and s.port_id == port_id


func hold_transfer_allowed(container: Variant) -> bool:
	## FRM-SYS13-10／ERR-SYS13-03: HOLD TRADE／LOAD only while DOCKED at registered port.
	if not _loaded:
		return false
	var ship_key: String = _ship_id_from_hold(container)
	if ship_key.is_empty():
		return false
	var s: Ship = _ships.get(ship_key, null) as Ship
	if s == null:
		return false
	if s.state != Ship.STATE_DOCKED:
		_record(ERR_SYS13_03, "state", s.state, "HOLD transfer while SAILING")
		return false
	var hold_id: String = String(s.hold_container_id())
	var meta_port: String = String(GoodsLedger.get_container_port_id(StringName(hold_id)))
	if meta_port.is_empty() or meta_port != String(s.port_id):
		_record(ERR_SYS13_03, "port", meta_port, "HOLD not berthed for trade")
		return false
	_clear_last()
	return true


func tick_step(tick: int) -> void:
	## FRM-SYS14-06: arrivals with arrival_tick == tick, ship_id ascending.
	## 25.1 F／D-34d: after arrival loop, on_arrivals at most once (batch atomic).
	assert(_loaded, "ShipRegistry.tick_step before load")
	var arriving: Array = []
	for key in _ships.keys():
		var s: Ship = _ships[key]
		if s.state == Ship.STATE_SAILING and s.arrival_tick == tick:
			arriving.append(s)
	arriving.sort_custom(func(a: Ship, b: Ship) -> bool: return String(a.ship_id) < String(b.ship_id))
	var arrivals: Array = []
	for s_variant in arriving:
		var s: Ship = s_variant
		var from_port: StringName = s.origin_port
		var dest: StringName = s.dest_port
		var owner_id: StringName = s.owner
		var sid: StringName = s.ship_id
		s.state = Ship.STATE_DOCKED
		s.port_id = dest
		s.path = []
		s.leg_start_tick = 0
		s.arrival_tick = 0
		s.wp_offset = 0
		GoodsLedger.set_container_port(s.hold_container_id(), dest)
		_queue_signal("ship_arrived", [s.ship_id, dest, from_port, tick])
		arrivals.append({
			"ship_id": sid,
			"owner_id": owner_id,
			"port_id": dest,
			"from_port_id": from_port,
		})
	if not arrivals.is_empty() and _ship_observer != null:
		_ship_observer.on_arrivals(tick, arrivals)
	_flush_signals()


func daily_step(_day: int) -> Array:
	## FRM-SYS13-07 daily accrual; ship_id ascending (D-19f b after BE+Pop).
	assert(_loaded, "ShipRegistry.daily_step before load")
	var errors: Array = []
	var wage: int = Params.get_int(StringName(PRM_CREW_WAGE_WK))
	var keys: Array = _ships.keys()
	keys.sort()
	for key in keys:
		var s: Ship = _ships[key]
		s.acc_wage = s.acc_wage + s.crew * wage
	return errors


func cutoff_step(_season_index: int) -> Array:
	## FRM-SYS13-07／08: wage then repair; ship_id ascending; before close_season (D-19f c).
	assert(_loaded, "ShipRegistry.cutoff_step before load")
	var errors: Array = []
	var keys: Array = _ships.keys()
	keys.sort()
	var days_d: int = Params.get_int(StringName(PRM_DAYS_PER_SEASON))
	var repair_rate: float = float(Params.get_value(StringName(PRM_REPAIR_RATE)))
	var price_map: Dictionary = Params.get_value(StringName(PRM_PRICE_CASH))
	for key in keys:
		var s: Ship = _ships[key]
		if s.acc_wage > 0:
			var days_pw: int = Params.get_int(StringName(PRM_DAYS_PER_WEEK))
			var due_w: int = int(ceili(float(s.acc_wage) / float(days_pw)))
			if due_w > 0:
				CashLedger.charge_mandatory(s.owner, due_w, REASON_CREW_WAGE, REQUESTER)
			s.acc_wage = 0
		var days_held: int = Clock.day - s.held_from_day + 1
		if days_held < 0:
			days_held = 0
		var price: int = int(price_map.get(String(s.type), 0))
		var due_r: int = 0
		if price > 0 and repair_rate > 0.0 and days_held > 0 and days_d > 0:
			due_r = int(ceili(float(price) * repair_rate * float(days_held) / float(days_d)))
		if due_r > 0:
			CashLedger.charge_mandatory(s.owner, due_r, REASON_SHIP_REPAIR, REQUESTER)
		s.held_from_day = Clock.day + 1
	return errors


func capacity_for_hold(container: Variant) -> int:
	## FRM-SYS13-10: CAPACITY[type] for HOLD:<ship_id>.
	if not _loaded:
		return CapacityProvider.CAPACITY_FAILURE
	var ship_key: String = _ship_id_from_hold(container)
	if ship_key.is_empty():
		return CapacityProvider.CAPACITY_FAILURE
	var s: Ship = _ships.get(ship_key, null) as Ship
	if s == null:
		return CapacityProvider.CAPACITY_FAILURE
	var cap_map: Dictionary = Params.get_value(StringName(PRM_CAPACITY))
	return int(cap_map.get(String(s.type), CapacityProvider.CAPACITY_FAILURE))


func flush_signals() -> void:
	_flush_signals()


# --- internals ---


func _clear_runtime(keep_provider: bool) -> void:
	_loaded = false
	_ships = {}
	_next_ship_seq = 1
	_last_error = {}
	_pending_signals = []
	_hold_provider = null
	_ship_observer = null
	if not keep_provider:
		_sailor_pool = null


func _validate_params() -> Array:
	var errors: Array = []
	for key in NOVALUE_PRMS:
		if not Params.has_prm(StringName(key)):
			errors.append(_err(ERR_SYS13_12, key, null, "required §10.7 無值 PRM missing"))
	# Valued keys also required once registered in schema (fixture／boot).
	for key in [PRM_YARD_CONCURRENT, PRM_SALVAGE_RATE]:
		if not Params.has_prm(StringName(key)):
			errors.append(_err(ERR_SYS13_12, key, null, "required §10.7 PRM missing"))
	return errors


func _create_ship(
	type: StringName, owner: StringName, port_id: StringName, crew: int
) -> Ship:
	var s := Ship.new()
	s.ship_id = StringName(SHIP_ID_FMT % _next_ship_seq)
	_next_ship_seq += 1
	s.type = type
	s.owner = owner
	s.crew = crew
	s.state = Ship.STATE_DOCKED
	s.port_id = port_id
	s.held_from_day = Clock.day if Clock.day > 0 else 1
	s.acc_wage = 0
	_ships[String(s.ship_id)] = s
	return s


func _require_owned_docked(actor: StringName, ship_id: StringName) -> Ship:
	var s: Ship = _ships.get(String(ship_id), null) as Ship
	if s == null:
		_record(ERR_SYS13_01, "ship_id", ship_id, "unknown ship_id")
		return null
	if s.owner != actor:
		_record(ERR_SYS13_02, "owner", actor, "actor is not ship owner")
		return null
	if s.state != Ship.STATE_DOCKED:
		_record(ERR_SYS13_03, "state", s.state, "requires DOCKED")
		return null
	return s


func _crew_cap(type: StringName) -> int:
	var m: Dictionary = Params.get_value(StringName(PRM_CREW))
	return int(m.get(String(type), 0))


func _tpw(type: StringName) -> int:
	var m: Dictionary = Params.get_value(StringName(PRM_TPW))
	return int(m.get(String(type), 1))


func _path_waypoints(path: Array) -> int:
	var total: int = 0
	for hop_variant in path:
		var hop: Dictionary = hop_variant
		total += SeaLanes.waypoints(String(hop[PATH_KEY_LANE_ID]))
	return total


func _dist_waypoints(from_node: String, to_node: String) -> int:
	if from_node == to_node:
		return 0
	var p: Array = SeaLanes.path(from_node, to_node)
	if p.is_empty():
		return 1 << 30
	return _path_waypoints(p)


func _is_port_node(node_id: String) -> bool:
	for n_variant in SeaLanes.nodes():
		var n: SeaNode = n_variant
		if n.node_id == node_id:
			return n.kind == SeaNode.KIND_PORT
	return PortRegistry.get_port(node_id) != null


func _lane_other(lane_id: String, from_node: String) -> String:
	var ends: PackedStringArray = SeaLanes.lane_endpoints(lane_id)
	if ends.size() != 2:
		return ""
	if ends[0] == from_node:
		return ends[1]
	if ends[1] == from_node:
		return ends[0]
	return ""


func _path_end_node(path: Array) -> String:
	if path.is_empty():
		return ""
	var last: Dictionary = path[path.size() - 1]
	var lane_id: String = String(last[PATH_KEY_LANE_ID])
	var from_n: String = String(last[PATH_KEY_FROM_NODE])
	return _lane_other(lane_id, from_n)


func _locate_completed(path: Array, completed: int) -> Dictionary:
	## Locate after `completed` waypoints along path.
	## Returns {lane_id, node_a, node_b, n, j, hop_index}; j = waypoints into current lane from node_a.
	## If completed is exactly at a lane boundary into the next lane, j=0 on that next lane.
	## If completed == 0 at start, j=0 on first lane.
	if path.is_empty():
		return {}
	var walked: int = 0
	for hop_i in range(path.size()):
		var hop: Dictionary = path[hop_i]
		var lane_id: String = String(hop[PATH_KEY_LANE_ID])
		var from_n: String = String(hop[PATH_KEY_FROM_NODE])
		var n_wp: int = SeaLanes.waypoints(lane_id)
		var other: String = _lane_other(lane_id, from_n)
		if other.is_empty():
			return {}
		if completed < walked + n_wp:
			return {
				"lane_id": lane_id,
				"node_a": from_n,
				"node_b": other,
				"n": n_wp,
				"j": completed - walked,
				"hop_index": hop_i,
			}
		if completed == walked + n_wp:
			# Exactly at node_b boundary.
			if hop_i + 1 < path.size():
				var nxt: Dictionary = path[hop_i + 1]
				var n_lane: String = String(nxt[PATH_KEY_LANE_ID])
				var n_from: String = String(nxt[PATH_KEY_FROM_NODE])
				var n_other: String = _lane_other(n_lane, n_from)
				return {
					"lane_id": n_lane,
					"node_a": n_from,
					"node_b": n_other,
					"n": SeaLanes.waypoints(n_lane),
					"j": 0,
					"hop_index": hop_i + 1,
				}
			return {
				"lane_id": lane_id,
				"node_a": from_n,
				"node_b": other,
				"n": n_wp,
				"j": n_wp,
				"hop_index": hop_i,
			}
		walked += n_wp
	return {}


func _ship_id_from_hold(container: Variant) -> String:
	if typeof(container) == TYPE_DICTIONARY:
		var d: Dictionary = container
		if String(d.get(GoodsLedger.KEY_KIND, "")) == GoodsLedger.KIND_HOLD:
			return String(d.get(GoodsLedger.KEY_SHIP, ""))
	var key := String(container)
	var prefix := "HOLD:"
	if key.begins_with(prefix):
		return key.substr(prefix.length())
	return ""


func _queue_signal(name: String, args: Array) -> void:
	_pending_signals.append({"name": name, "args": args})


func _flush_signals() -> void:
	var batch: Array = _pending_signals
	_pending_signals = []
	for item_variant in batch:
		var item: Dictionary = item_variant
		var n: String = String(item["name"])
		var args: Array = item["args"]
		match n:
			"ship_departed":
				ship_departed.emit(args[0], args[1], args[2], args[3], args[4])
			"ship_rerouted":
				ship_rerouted.emit(args[0], args[1], args[2])
			"ship_arrived":
				ship_arrived.emit(args[0], args[1], args[2], args[3])
			"crew_changed":
				crew_changed.emit(args[0], args[1])


func _clear_last() -> void:
	_last_error = {}


func _record(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)
	push_error("ShipRegistry: %s" % str(_last_error))


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("ShipRegistry: %s" % str(e))


class _HoldCapacityAdapter extends CapacityProvider:
	var _reg: Node

	func _init(reg: Node) -> void:
		_reg = reg

	func capacity(container: Variant) -> int:
		if _reg == null or not _reg.is_loaded():
			return CAPACITY_FAILURE
		return _reg.capacity_for_hold(container)
