extends Node
## Autoload: TraderRegistry — SYS-17 ST-TRADER (03_Systems 17.1／WP-36／D-104(c)／D-109).
## _ready() only clears fields; load／boot steps via SimLoop (2.2-01／D-23g).
## Cash／goods／ships stay in their ledgers (D-23b). Bankruptcy liquidation is SYS-22 (D-50);
## M1b only freezes (D-109(d)).

signal trader_plan_set(trader_id: StringName, ship_id: StringName, plan: Dictionary)
signal trader_retired(trader_id: StringName)

const SYS_ID := &"SYS-17"
const SCRIPT_PATH := "res://autoload/trader_registry.gd"
const CURVE_PATH := "res://data/market/price_curve.tres"

const ERR_SYS17_01 := &"ERR-SYS17-01"
const ERR_SYS17_02 := &"ERR-SYS17-02"
const ERR_SYS17_03 := &"ERR-SYS17-03"
const ERR_SYS17_04 := &"ERR-SYS17-04"
const ERR_SYS17_05 := &"ERR-SYS17-05"
const ERR_SYS17_06 := &"ERR-SYS17-06"
const ERR_SYS17_07 := &"ERR-SYS17-07"

const PRM_COUNT := "PRM-SYS17-MERCHANT_COUNT_MAX"
const PRM_START_CASH := "PRM-SYS17-START_CASH"
const PRM_SHIP_MIX := "PRM-SYS17-SHIP_MIX"
const PRM_TIER_MIX := "PRM-SYS17-TIER_MIX"
const PRM_EXPLORE_RATE := "PRM-SYS17-EXPLORE_RATE"
const PRM_EXPLORE_QTY := "PRM-SYS17-EXPLORE_QTY"
const PRM_PROFIT_MIN := "PRM-SYS17-PROFIT_MIN_LI"
const PRM_IDLE_MAX := "PRM-SYS17-IDLE_DAYS_MAX"
const PRM_LOSS_TOL := "PRM-SYS17-LOSS_TOL_PPM"
const PRM_PPM := "PRM-SYS06-PPM_SCALE"
const PRM_TICKS_PER_DAY := "PRM-SYS00-TICKS_PER_DAY"
const PRM_ARREARS_LIM := "PRM-SYS05-ARREARS_SEASONS_TO_BANKRUPT"
const PRM_TPW := "PRM-SYS13-TICKS_PER_WAYPOINT"
const PRM_CAPACITY := "PRM-SYS13-CAPACITY"
const PRM_CREW := "PRM-SYS13-CREW"

const MODE_IDLE := &"IDLE"
const MODE_SAILING := &"SAILING"
const MODE_RETIRED := &"RETIRED"

const SHIP_TYPE := &"SH-03" ## D-104(c)／D-94 third type (250 擔)
const TRADER_ID_FMT := "TR-%03d"
const ACCOUNT_TOKEN_FMT := "TR-%03d"
const PURPOSE_EXPLORE := "EXPLORE"
const TAX_LI := 0 ## D-109(b) until WP-39
const PRM_TOP_N := "PRM-SYS17-TOP_N_PRECISE"

## CashLedger second genesis exception (D-23c); AUTHORIZED_REQUESTERS unchanged.

var _loaded: bool = false
var _enabled: bool = false
var _qual_open: bool = false
var _genesis_granted: bool = false
var _last_error: Dictionary = {}
var _traders: Dictionary = {} ## trader_id:String → Dictionary
var _frozen: Dictionary = {} ## account_id:String → true (D-109(d) M1b)
var _voyage_days: Dictionary = {} ## "from|to" → int days
var _curve_weeks: PackedFloat64Array = PackedFloat64Array()
var _curve_mults: PackedFloat64Array = PackedFloat64Array()
var _pending_signals: Array = []
var _day_errors: Array = []
## Explore seed from scenario (FRM-SYS23-03／FRM-SYS17-04). No module-fixed default (F3).
var _rng_seed: int = 0
## Test-only destination intel inject (F2: product／sim must not depend on this; default empty).
## Key "port|good" → {mid_li:int, weeks:float}；null mid → no candidate.
var _intel_override: Dictionary = {}


func _ready() -> void:
	_clear_runtime()


func set_layers(traders_on: bool, qual_open: bool) -> void:
	## D-109(e)／scenario layers.TRADERS／QUAL_OPEN. Call before apply_boot_steps.
	_enabled = traders_on
	_qual_open = qual_open


func set_rng_seed(seed: int) -> void:
	_rng_seed = seed


func set_intel_override(port_id: StringName, good_id: StringName, mid_li: Variant, weeks: Variant = null) -> void:
	## Test／fixture only (F2): product／sim paths use IntelLedger.board_for(actor, P, O, g).
	var key := "%s|%s" % [String(port_id), String(good_id)]
	if mid_li == null:
		_intel_override.erase(key)
		return
	_intel_override[key] = {"mid_li": int(mid_li), "weeks": weeks}


func clear_intel_overrides() -> void:
	_intel_override.clear()


func mark_frozen(account_id: StringName, frozen: bool = true) -> void:
	## D-109(d): M1b freeze until SYS-22. Also used by freeze-skip tests.
	var k := String(account_id)
	if frozen:
		_frozen[k] = true
	else:
		_frozen.erase(k)


func is_frozen(account_id: StringName) -> bool:
	if CashLedger.has_method("is_frozen"):
		return CashLedger.is_frozen(account_id)
	return _frozen.has(String(account_id))


func is_loaded() -> bool:
	return _loaded


func is_enabled() -> bool:
	return _enabled


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func take_day_errors() -> Array:
	var out: Array = _day_errors.duplicate(true)
	_day_errors.clear()
	return out


func load_and_validate() -> Array:
	## Validate SYS17 PRMs when traders layer enabled; otherwise no-op.
	var errors: Array = []
	_clear_runtime_keep_layers()
	if not _enabled:
		_loaded = false
		return errors
	if not Params.is_loaded():
		errors.append(_err(ERR_SYS17_01, "Params", null, "Params must load before TraderRegistry"))
		_emit(errors)
		return errors
	for key in [
		PRM_COUNT, PRM_START_CASH, PRM_SHIP_MIX, PRM_TIER_MIX, PRM_EXPLORE_RATE,
		PRM_EXPLORE_QTY, PRM_PROFIT_MIN, PRM_IDLE_MAX, PRM_LOSS_TOL, PRM_PPM, PRM_TOP_N
	]:
		if not Params.has_prm(StringName(key)):
			errors.append(_err(ERR_SYS17_01, key, null, "missing PRM (ERR-SYS17-01)"))
	if not errors.is_empty():
		_emit(errors)
		return errors
	var n: int = Params.get_int(StringName(PRM_COUNT))
	if n < 1:
		errors.append(_err(ERR_SYS17_01, PRM_COUNT, n, "MERCHANT_COUNT_MAX must be ≥ 1"))
	var top_n: int = Params.get_int(StringName(PRM_TOP_N))
	if top_n < 1:
		errors.append(_err(ERR_SYS17_01, PRM_TOP_N, top_n, "TOP_N_PRECISE must be ≥ 1"))
	var mix: Variant = Params.get_value(StringName(PRM_SHIP_MIX))
	if typeof(mix) != TYPE_ARRAY and not (mix is PackedInt32Array) and not (mix is PackedInt64Array):
		errors.append(_err(ERR_SYS17_01, PRM_SHIP_MIX, mix, "SHIP_MIX must be int array"))
	elif _array_len(mix) != n:
		errors.append(_err(ERR_SYS17_01, PRM_SHIP_MIX, _array_len(mix), "SHIP_MIX length must equal MERCHANT_COUNT_MAX"))
	var tier: Variant = Params.get_value(StringName(PRM_TIER_MIX))
	if typeof(tier) != TYPE_ARRAY and not (tier is PackedInt32Array) and not (tier is PackedInt64Array):
		errors.append(_err(ERR_SYS17_01, PRM_TIER_MIX, tier, "TIER_MIX must be int array"))
	elif _array_len(tier) != n:
		errors.append(_err(ERR_SYS17_01, PRM_TIER_MIX, _array_len(tier), "TIER_MIX length must equal MERCHANT_COUNT_MAX"))
	_load_curve()
	if not errors.is_empty():
		_emit(errors)
		return errors
	_loaded = true
	return errors


func apply_boot_steps() -> Array:
	## FRM-SYS17-06／07: ① roster+accounts → ② grant_genesis_cash → ③ ships+crew.
	## Call after SimLoop validation／player genesis; no-op if traders off.
	var errors: Array = []
	if not _enabled:
		return errors
	errors.append_array(load_and_validate())
	if not errors.is_empty() or not _loaded:
		return errors
	errors.append_array(_step_create_roster())
	if not errors.is_empty():
		return errors
	var g_rc: Error = grant_genesis_cash()
	if g_rc != OK:
		var ge: Dictionary = last_error()
		if ge.is_empty():
			ge = _err(ERR_SYS17_02, "grant_genesis_cash", g_rc, "genesis failed")
		errors.append(ge)
		return errors
	errors.append_array(_step_assign_ships())
	if not errors.is_empty():
		return errors
	_build_voyage_matrix()
	return errors


func grant_genesis_cash() -> Error:
	## FRM-SYS17-06／D-23c: SOURCE → each ACT-TR-nnn；cash = ships × START_CASH (D-104(c)).
	assert(_loaded or _enabled, "TraderRegistry.grant_genesis_cash before enable")
	_clear_last()
	if _genesis_granted:
		_record(ERR_SYS17_02, "grant_genesis_cash", true, "GENESIS_ALREADY_GRANTED")
		return FAILED
	if not CashLedger.is_loaded():
		_record(ERR_SYS17_01, "CashLedger", null, "CashLedger not loaded")
		return FAILED
	var start_per_ship: int = Params.get_int(StringName(PRM_START_CASH))
	var entries: Array = []
	var total: int = 0
	var ids: PackedStringArray = all_trader_ids()
	for tid in ids:
		var t: Dictionary = _traders[String(tid)]
		var ships_n: int = (t["ship_ids"] as Array).size()
		if ships_n < 1:
			## Ships not yet assigned — use SHIP_MIX count.
			ships_n = int(t.get("ship_count_planned", 1))
		var cash: int = start_per_ship * ships_n
		total += cash
		entries.append(CashLedger.make_entry(t["account_id"], cash))
	if total <= 0 or entries.is_empty():
		_record(ERR_SYS17_04, "grant_genesis_cash", total, "no traders to fund")
		return FAILED
	entries.insert(0, CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - total))
	var rc: Error = CashLedger.post(
		entries, CashLedger.REASON_GENESIS_CASH, CashLedger.REQUESTER_TRADER_GENESIS_GRANT
	)
	if rc != OK:
		_last_error = CashLedger.last_error().duplicate(true)
		push_error("TraderRegistry: genesis post failed %s" % str(_last_error))
		return FAILED
	_genesis_granted = true
	return OK


func get_trader(id: StringName) -> Variant:
	## H: Resource-like Dictionary; missing → null + last_error (D-08c).
	_clear_last()
	var key := String(id)
	if not _traders.has(key):
		_record(ERR_SYS17_03, "trader_id", id, "UNKNOWN_TRADER")
		return null
	return (_traders[key] as Dictionary).duplicate(true)


func all_trader_ids() -> PackedStringArray:
	var keys: Array = _traders.keys()
	keys.sort()
	return PackedStringArray(keys)


func retire(trader_id: StringName) -> Error:
	## FRM-SYS17-08／D-50: SYS-22 calls after liquidation; mode → RETIRED only.
	_clear_last()
	var key := String(trader_id)
	if not _traders.has(key):
		_record(ERR_SYS17_03, "trader_id", trader_id, "UNKNOWN_TRADER")
		return FAILED
	var t: Dictionary = _traders[key]
	for sid_v in t["ship_ids"]:
		var info: Dictionary = ShipRegistry.ship_info(sid_v)
		if not info.is_empty() and StringName(info.get("state", &"")) == Ship.STATE_SAILING:
			_record(ERR_SYS17_07, "trader_id", trader_id, "RETIRE_WHILE_SAILING")
			return FAILED
	t["mode"] = MODE_RETIRED
	t["retired"] = true
	t["plans"] = {}
	_queue_signal("trader_retired", [trader_id])
	return OK


func daily_step(day: int) -> Array:
	## FRM-SYS17-01／03／05；D-104(c)⑤ perf. Insert after IntelLedger (17.1 F／25.1).
	_day_errors.clear()
	if not _enabled or not _loaded:
		return _day_errors
	_refresh_freeze_from_arrears()
	_build_board_cache_day()
	## Explore lottery once per day (FRM-SYS17-04).
	var explore_set: Dictionary = _pick_explore_traders(day)
	## Process (trader_id, ship_id) ascending (D-109 plan-per-ship).
	var pairs: Array = []
	for tid in all_trader_ids():
		var t: Dictionary = _traders[String(tid)]
		if bool(t.get("retired", false)) or t.get("mode") == MODE_RETIRED:
			continue
		if is_frozen(t["account_id"]):
			continue
		var sids: Array = t["ship_ids"]
		var sorted_ships: Array = sids.duplicate()
		sorted_ships.sort_custom(func(a, b): return String(a) < String(b))
		for sid in sorted_ships:
			pairs.append([tid, sid])
	pairs.sort_custom(func(a, b):
		var ta := String(a[0])
		var tb := String(b[0])
		if ta != tb:
			return ta < tb
		return String(a[1]) < String(b[1])
	)
	for pair in pairs:
		var tid: StringName = pair[0]
		var sid: StringName = pair[1]
		_process_ship_day(tid, sid, day, explore_set.has(String(tid)))
	return _day_errors


func flush_signals() -> void:
	for item_v in _pending_signals:
		var item: Dictionary = item_v
		var n: String = String(item["name"])
		var args: Array = item["args"]
		if n == "trader_plan_set":
			trader_plan_set.emit(args[0], args[1], args[2])
		elif n == "trader_retired":
			trader_retired.emit(args[0])
	_pending_signals.clear()


# --- boot helpers ---


func _step_create_roster() -> Array:
	var errors: Array = []
	var n: int = Params.get_int(StringName(PRM_COUNT))
	var mix: Array = _to_int_array(Params.get_value(StringName(PRM_SHIP_MIX)))
	var tiers: Array = _to_int_array(Params.get_value(StringName(PRM_TIER_MIX)))
	for i in range(n):
		var idx: int = i + 1
		var tid := StringName(TRADER_ID_FMT % idx)
		var acct := CashLedger.make_actor_id(ACCOUNT_TOKEN_FMT % idx)
		if CashLedger.create_account(acct, Account.Kind.ACTOR, tid) != OK:
			errors.append(CashLedger.last_error())
			continue
		_traders[String(tid)] = {
			"trader_id": tid,
			"account_id": acct,
			"ship_ids": [],
			"ship_count_planned": int(mix[i]),
			"qualifications": {"tier": int(tiers[i])},
			"mode": MODE_IDLE,
			"plans": {}, ## ship_id → plan
			"idle_days": {}, ## ship_id → int
			"retired": false,
			"home_port": &"",
		}
	return errors


func _step_assign_ships() -> Array:
	## D-109(a): ships by opening pop largest-remainder; same trader → same port; ties port_id asc.
	var errors: Array = []
	if not ShipRegistry.is_loaded():
		errors.append(_err(ERR_SYS17_04, "ShipRegistry", null, "ShipRegistry required for ships"))
		return errors
	var ports: Array = _opening_port_pops()
	if ports.is_empty():
		errors.append(_err(ERR_SYS17_04, "ports", null, "no ports for ship allocation"))
		return errors
	var total_ships: int = 0
	for tid in all_trader_ids():
		total_ships += int((_traders[String(tid)] as Dictionary).get("ship_count_planned", 0))
	if total_ships < 1:
		errors.append(_err(ERR_SYS17_04, PRM_SHIP_MIX, total_ships, "NO_SHIP"))
		return errors
	var alloc: Array = _largest_remainder_ports(ports, total_ships)
	## Assign traders in id order into port buckets (ships of one trader stay together).
	var port_slots: Dictionary = {} ## port → remaining capacity
	for row in alloc:
		port_slots[String(row["port_id"])] = int(row["ships"])
	var port_order: Array = port_slots.keys()
	port_order.sort()
	var crew_map: Dictionary = Params.get_value(StringName(PRM_CREW))
	var crew_n: int = int(crew_map.get(String(SHIP_TYPE), 0))
	if crew_n < 1:
		errors.append(_err(ERR_SYS17_04, PRM_CREW, crew_n, "CREW[SH-03] required"))
		return errors
	for tid in all_trader_ids():
		var t: Dictionary = _traders[String(tid)]
		var need: int = int(t["ship_count_planned"])
		var chosen := &""
		for p in port_order:
			if int(port_slots.get(p, 0)) >= need:
				chosen = StringName(p)
				port_slots[p] = int(port_slots[p]) - need
				break
		if chosen == &"":
			## Fallback: any port with remaining, even if < need (should not happen with LR).
			for p in port_order:
				if int(port_slots.get(p, 0)) > 0:
					chosen = StringName(p)
					port_slots[p] = maxi(0, int(port_slots[p]) - need)
					break
		if chosen == &"":
			chosen = StringName(port_order[0])
		t["home_port"] = chosen
		var beggars_before: int = 0
		if PopulationModel.is_loaded():
			beggars_before = PopulationModel.beggars(chosen)
		for _s in range(need):
			var sid: StringName = ShipRegistry.spawn_docked_ship(
				SHIP_TYPE, t["account_id"], chosen, crew_n
			)
			if sid == &"":
				errors.append(_err(ERR_SYS17_04, "spawn", tid, "ship spawn failed"))
				continue
			(t["ship_ids"] as Array).append(sid)
			(t["plans"] as Dictionary)[String(sid)] = TradeEvaluator.empty_plan()
			(t["idle_days"] as Dictionary)[String(sid)] = 0
		if PopulationModel.is_loaded():
			var beggars_after: int = PopulationModel.beggars(chosen)
			if beggars_after < beggars_before:
				errors.append(
					_err(ERR_SYS17_04, "sailors", chosen, "opening crew must not reduce beggars (D-23e)")
				)
	## Verify at least one ship.
	var any_ship := false
	for tid2 in all_trader_ids():
		if not (_traders[String(tid2)]["ship_ids"] as Array).is_empty():
			any_ship = true
			break
	if not any_ship:
		errors.append(_err(ERR_SYS17_04, "ships", 0, "NO_SHIP"))
	return errors


func _opening_port_pops() -> Array:
	## [{port_id, pop}] sorted port_id asc.
	var out: Array = []
	if not PortRegistry.is_loaded():
		return out
	for pid_v in PortRegistry.all_ids():
		var pid: StringName = pid_v
		var pop: int = 0
		if PopulationModel.is_loaded():
			pop = PopulationModel.population(pid)
		out.append({"port_id": pid, "pop": pop})
	out.sort_custom(func(a, b): return String(a["port_id"]) < String(b["port_id"]))
	return out


func _largest_remainder_ports(ports: Array, total_ships: int) -> Array:
	## D-109(a): quota = floor(pop／Σpop × N); remainders fill; ties port_id asc (already sorted).
	var sum_pop: int = 0
	for p in ports:
		sum_pop += int(p["pop"])
	var result: Array = []
	var assigned: int = 0
	var fracs: Array = []
	for p in ports:
		var pop: int = int(p["pop"])
		var exact: float = 0.0
		if sum_pop > 0:
			exact = float(pop) * float(total_ships) / float(sum_pop)
		var base: int = floori(exact)
		result.append({"port_id": p["port_id"], "ships": base, "frac": exact - float(base)})
		assigned += base
	var remain: int = total_ships - assigned
	fracs = result.duplicate()
	fracs.sort_custom(func(a, b):
		if float(a["frac"]) != float(b["frac"]):
			return float(a["frac"]) > float(b["frac"])
		return String(a["port_id"]) < String(b["port_id"])
	)
	for i in range(remain):
		if i >= fracs.size():
			break
		var pid := String(fracs[i]["port_id"])
		for row in result:
			if String(row["port_id"]) == pid:
				row["ships"] = int(row["ships"]) + 1
				break
	return result


func _build_voyage_matrix() -> void:
	## D-104(c)⑤: once at boot — days = ceili(waypoints × TPW ／ TICKS_PER_DAY).
	_voyage_days.clear()
	if not SeaLanes.is_loaded() or not PortRegistry.is_loaded():
		return
	var tpd: int = Params.get_int(StringName(PRM_TICKS_PER_DAY))
	if tpd < 1:
		tpd = 1
	var tpw_map: Dictionary = Params.get_value(StringName(PRM_TPW))
	var tpw: int = int(tpw_map.get(String(SHIP_TYPE), 1))
	if tpw < 1:
		tpw = 1
	var ids: Array = []
	for pid_v in PortRegistry.all_ids():
		ids.append(String(pid_v))
	ids.sort()
	for a in ids:
		for b in ids:
			if a == b:
				continue
			var path: Array = SeaLanes.path(a, b)
			if path.is_empty():
				continue
			var wp: int = 0
			for hop_v in path:
				wp += SeaLanes.waypoints(String((hop_v as Dictionary).get("lane_id", "")))
			var days: int = ceili(float(wp * tpw) / float(tpd))
			if days < 1:
				days = 1
			_voyage_days["%s|%s" % [a, b]] = days


# --- daily ---


func _refresh_freeze_from_arrears() -> void:
	## D-109(d): when arrears_seasons ≥ limit, freeze (no SYS-22 yet).
	if not CashLedger.is_loaded() or not Params.has_prm(StringName(PRM_ARREARS_LIM)):
		return
	var lim: int = Params.get_int(StringName(PRM_ARREARS_LIM))
	for tid in all_trader_ids():
		var t: Dictionary = _traders[String(tid)]
		var acct: StringName = t["account_id"]
		if CashLedger.arrears_seasons(acct) >= lim:
			mark_frozen(acct, true)


func _build_board_cache_day() -> void:
	## D-104(c)⑤ shared mid cache reserved; per-candidate board_for is authoritative (F2).
	pass


func _pick_explore_traders(day: int) -> Dictionary:
	var out: Dictionary = {}
	var rate: float = Params.get_float(StringName(PRM_EXPLORE_RATE))
	if rate <= 0.0:
		return out
	var ids: PackedStringArray = all_trader_ids()
	## F4① GAP: EXPLORE_RATE is 定點數 0..1 (not ppm); FRM-SYS17-04 writes no integer
	## precision for n×rate — do not invent ppm conversion (dispatch: 列缺口停該項).
	var n_pick: int = int(floor(float(ids.size()) * rate + 1e-9))
	if n_pick < 1 and rate > 0.0 and not ids.is_empty():
		n_pick = 1
	## Deterministic: score each trader by SplitMix output; take lowest n_pick ids by score then id.
	var scored: Array = []
	for tid in ids:
		var seed: int = Rng.derive_seed(_rng_seed, day, String(tid), "", PURPOSE_EXPLORE)
		var step: Array = Rng.next(seed)
		scored.append({"id": String(tid), "r": int(step[1])})
	scored.sort_custom(func(a, b):
		if int(a["r"]) != int(b["r"]):
			return int(a["r"]) < int(b["r"])
		return String(a["id"]) < String(b["id"])
	)
	for i in range(mini(n_pick, scored.size())):
		out[String(scored[i]["id"])] = true
	return out


func _process_ship_day(tid: StringName, sid: StringName, day: int, explore: bool) -> void:
	var t: Dictionary = _traders[String(tid)]
	var info: Dictionary = ShipRegistry.ship_info(sid)
	if info.is_empty():
		return
	var plans: Dictionary = t["plans"]
	var plan: Dictionary = plans.get(String(sid), TradeEvaluator.empty_plan())
	var state: StringName = StringName(info.get("state", &""))
	## FRM-SYS17-05: arrival day → sell.
	if state == Ship.STATE_DOCKED and StringName(plan.get("phase", &"")) == TradeEvaluator.PHASE_OUTBOUND:
		_try_sell(tid, sid, t, plan, info)
		plan = plans.get(String(sid), TradeEvaluator.empty_plan())
		info = ShipRegistry.ship_info(sid)
		state = StringName(info.get("state", &""))
	if state != Ship.STATE_DOCKED:
		return
	if StringName(plan.get("phase", &"")) != TradeEvaluator.PHASE_NONE:
		## Still holding outbound goods that failed to sell — wait.
		if StringName(plan.get("phase", &"")) == TradeEvaluator.PHASE_OUTBOUND:
			return
	## Idle docked → evaluate.
	_evaluate_and_maybe_sail(tid, sid, t, info, explore)


func _try_sell(tid: StringName, sid: StringName, t: Dictionary, plan: Dictionary, info: Dictionary) -> void:
	var good: StringName = plan.get("good_id", &"")
	var port: StringName = StringName(info.get("port_id", &""))
	var acct: StringName = t["account_id"]
	var hold_id: StringName = StringName(GoodsLedger.CONTAINER_ID_FMT_HOLD % String(sid))
	var hold_dict: Dictionary = GoodsLedger.make_hold(String(sid), String(acct))
	var qty: int = GoodsLedger.get_qty(hold_dict, good)
	if qty <= 0:
		_note_plan_inconsistent(tid, sid, "OUTBOUND but hold empty")
		_clear_plan(t, sid)
		t["mode"] = MODE_IDLE
		return
	var quote: Dictionary = MarketPricer.quote(port, good, MarketPricer.SIDE_SELL, qty)
	var preview: int = int(quote.get(MarketPricer.KEY_TOTAL_LI, 0))
	var seq: int = TradeDesk.execute_trade(
		acct, hold_id, port, good, MarketPricer.SIDE_SELL, qty, preview
	)
	if seq < 1:
		## Stay; retry next day (FRM-SYS17-05).
		_day_errors.append(_wrap_trade_reject(tid, TradeDesk.last_error()))
		return
	_clear_plan(t, sid)
	t["mode"] = MODE_IDLE
	(t["idle_days"] as Dictionary)[String(sid)] = 0


func _evaluate_and_maybe_sail(
	tid: StringName, sid: StringName, t: Dictionary, info: Dictionary, explore: bool
) -> void:
	var from_port: StringName = StringName(info.get("port_id", &""))
	var acct: StringName = t["account_id"]
	var idle_map: Dictionary = t["idle_days"]
	var idle: int = int(idle_map.get(String(sid), 0))
	var cap_map: Dictionary = Params.get_value(StringName(PRM_CAPACITY))
	var hold_cap: int = int(cap_map.get(String(SHIP_TYPE), 0))
	var hold_id: StringName = StringName(GoodsLedger.CONTAINER_ID_FMT_HOLD % String(sid))
	var hold_dict: Dictionary = GoodsLedger.make_hold(String(sid), String(acct))
	## Free hold space.
	var used: int = 0
	if GoodCatalog.is_loaded():
		for g in GoodCatalog.all_ids():
			used += GoodsLedger.get_qty(hold_dict, g)
	var free_cap: int = hold_cap - used
	if free_cap < 1:
		idle_map[String(sid)] = idle + 1
		return
	var goods: Array = []
	if GoodCatalog.is_loaded():
		for g in GoodCatalog.all_ids():
			goods.append(g)
	goods.sort_custom(func(a, b): return String(a) < String(b))
	var ports: Array = []
	if PortRegistry.is_loaded():
		for p in PortRegistry.all_ids():
			ports.append(p)
	ports.sort_custom(func(a, b): return String(a) < String(b))

	var candidates: Array = []
	## Coarse pass then top-3 precise (D-104(c)⑤).
	var coarse: Array = []
	for dest_v in ports:
		var dest: StringName = dest_v
		if String(dest) == String(from_port):
			continue
		if not _can_enter(acct, dest):
			continue
		if not _draft_ok(sid, dest):
			continue
		var days: int = int(_voyage_days.get("%s|%s" % [String(from_port), String(dest)], 0))
		if days < 1:
			continue
		for good_v in goods:
			var good: StringName = good_v
			if not _can_trade_good(acct, from_port, good, MarketPricer.SIDE_BUY):
				continue
			if not _can_trade_good(acct, dest, good, MarketPricer.SIDE_SELL):
				continue
			var market_qty: int = GoodsLedger.get_qty(GoodsLedger.make_market(String(from_port)), good)
			if market_qty < 1:
				continue
			var afford: int = CashLedger.max_affordable_qty(acct, from_port, good)
			if afford < 1:
				continue
			var intel: Dictionary = _dest_intel(acct, from_port, dest, good)
			if intel.is_empty() or intel.get("mid_li", null) == null:
				continue ## D-109(c)／F2: n＝0 or empty board → not a candidate
			var weekly: int = 0
			if DemandModel.is_loaded() or DemandModel.has_potential_demand_provider():
				weekly = DemandModel.weekly_potential_demand(dest, good)
			if weekly < 1:
				continue ## D-110(g)
			var q: int = mini(mini(afford, free_cap), market_qty)
			if explore:
				q = mini(q, Params.get_int(StringName(PRM_EXPLORE_QTY)))
			if q < 1:
				continue
			var mid: int = int(intel["mid_li"])
			var rough_buy: int = mid ## coarse; precise quote later
			## Prefer 1-担 mid as rough unit cost proxy via MarketPricer.mid at origin (public).
			var origin_mid: float = MarketPricer.mid_price(from_port, good)
			rough_buy = floori(origin_mid * float(q))
			var score: int = TradeEvaluator.coarse_score(mid, q, rough_buy, days)
			coarse.append({
				"port_id": dest,
				"good_id": good,
				"qty": q,
				"voyage_days": days,
				"mid_li": mid,
				"weeks": intel.get("weeks", 0.0),
				"weekly": weekly,
				"score": score,
				"rough_buy": rough_buy,
			})
	coarse.sort_custom(func(a, b):
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		var ap := String(a["port_id"])
		var bp := String(b["port_id"])
		if ap != bp:
			return ap < bp
		return String(a["good_id"]) < String(b["good_id"])
	)
	var top_n: int = Params.get_int(StringName(PRM_TOP_N))
	var top: Array = coarse.slice(0, mini(top_n, coarse.size()))
	for c in top:
		var dest2: StringName = c["port_id"]
		var good2: StringName = c["good_id"]
		var q2: int = int(c["qty"])
		var days2: int = int(c["voyage_days"])
		var buy_q: Dictionary = MarketPricer.quote(from_port, good2, MarketPricer.SIDE_BUY, q2)
		if buy_q.has(MarketPricer.KEY_ERROR):
			continue
		var buy_cost: int = int(buy_q.get(MarketPricer.KEY_TOTAL_LI, 0))
		## Recompute affordable with precise quote.
		if buy_cost > CashLedger.balance(acct):
			continue
		var sell_rev: int = _estimate_sell_revenue(
			dest2, good2, q2, int(c["mid_li"]), c.get("weeks", 0.0), int(c["weekly"])
		)
		var profit: int = TradeEvaluator.daily_marginal_profit(sell_rev, buy_cost, TAX_LI, days2)
		candidates.append({
			"port_id": dest2,
			"good_id": good2,
			"qty": q2,
			"voyage_days": days2,
			"daily_profit_li": profit,
			"buy_cost_li": buy_cost,
			"sell_revenue_li": sell_rev,
		})
	## Explore: destinations with no offtake history preferred; skip profit gate later.
	if explore:
		candidates = _filter_explore_candidates(candidates, from_port)

	var best: Dictionary = TradeEvaluator.pick_best_candidate(candidates)
	var profit_min: int = Params.get_int(StringName(PRM_PROFIT_MIN))
	var idle_max: int = Params.get_int(StringName(PRM_IDLE_MAX))
	var loss_tol: int = Params.get_int(StringName(PRM_LOSS_TOL))
	var ppm: int = Params.get_int(StringName(PRM_PPM))
	if best.is_empty():
		idle_map[String(sid)] = idle + 1
		_clear_plan(t, sid)
		return
	var decision: Dictionary
	if explore:
		decision = {"sail": true, "idle_days_after": 0}
	else:
		decision = TradeEvaluator.decide_sail_or_idle(
			int(best["daily_profit_li"]),
			int(best["buy_cost_li"]),
			int(best["sell_revenue_li"]),
			idle,
			profit_min,
			idle_max,
			loss_tol,
			ppm
		)
	if not bool(decision["sail"]):
		idle_map[String(sid)] = int(decision["idle_days_after"])
		_clear_plan(t, sid)
		return
	## Execute buy + sail (FRM-SYS17-03 via TradeDesk).
	var dest_f: StringName = best["port_id"]
	var good_f: StringName = best["good_id"]
	var qty_f: int = int(best["qty"])
	var buy2: Dictionary = MarketPricer.quote(from_port, good_f, MarketPricer.SIDE_BUY, qty_f)
	var preview: int = int(buy2.get(MarketPricer.KEY_TOTAL_LI, 0))
	var seq: int = TradeDesk.execute_trade(
		acct, hold_id, from_port, good_f, MarketPricer.SIDE_BUY, qty_f, preview
	)
	if seq < 1:
		_day_errors.append(_wrap_trade_reject(tid, TradeDesk.last_error()))
		_clear_plan(t, sid)
		idle_map[String(sid)] = idle + 1
		return
	var arrival: int = ShipRegistry.sail(acct, sid, dest_f)
	if arrival < 1:
		## Rollback not available as single API — leave goods in hold; clear plan; record.
		_day_errors.append(_err(ERR_SYS17_06, "sail", sid, "sail failed after buy"))
		_clear_plan(t, sid)
		return
	var new_plan := {
		"phase": TradeEvaluator.PHASE_OUTBOUND,
		"from_port": from_port,
		"to_port": dest_f,
		"good_id": good_f,
		"qty": qty_f,
		"expected_profit_li": int(best["daily_profit_li"]),
	}
	(t["plans"] as Dictionary)[String(sid)] = new_plan
	t["mode"] = MODE_SAILING
	idle_map[String(sid)] = 0
	_queue_signal("trader_plan_set", [tid, sid, new_plan])


func _filter_explore_candidates(candidates: Array, from_port: StringName) -> Array:
	## Prefer destinations with empty offtake history for any candidate good.
	var cold: Array = []
	for c in candidates:
		var dest: StringName = c["port_id"]
		var good: StringName = c["good_id"]
		var snap: Dictionary = GoodsLedger.offtake_snapshot(dest, good)
		var wq: int = int(snap.get("window_qty", 0)) if not snap.is_empty() else 0
		if wq == 0:
			cold.append(c)
	return cold if not cold.is_empty() else candidates


func _estimate_sell_revenue(
	dest: StringName, good: StringName, qty: int, mid_li: int, weeks_v: Variant, weekly: int
) -> int:
	## D-110(g)／F4③: MarketPricer.batch_area is the single trapezoid site (N-04).
	if weekly < 1 or not MarketPricer.is_loaded():
		return mid_li * qty
	var anchor: int = 0
	if GoodCatalog.is_loaded():
		var gd: GoodDef = GoodCatalog.get_good(good)
		if gd != null:
			anchor = gd.base_price_li
	if anchor <= 0:
		return mid_li * qty
	var w0: float = 0.0
	if weeks_v != null and typeof(weeks_v) in [TYPE_FLOAT, TYPE_INT]:
		w0 = float(weeks_v)
	return TradeEvaluator.estimate_sell_revenue_li(anchor, float(weekly), w0, qty)


func _dest_intel(
	actor: StringName, present_port: StringName, dest: StringName, good: StringName
) -> Dictionary:
	## F2／FRM-SYS15-06 (2026-11-24): board_for(actor, 本港 P, 目的港 O, g).
	var key := "%s|%s" % [String(dest), String(good)]
	if _intel_override.has(key):
		return (_intel_override[key] as Dictionary).duplicate(true)
	if IntelLedger.is_loaded():
		var board: Dictionary = IntelLedger.board_for(actor, present_port, dest, good)
		if board.is_empty():
			return {}
		if int(board.get(IntelLedger.KEY_N, 0)) == 0:
			return {}
		if board.get(IntelLedger.KEY_CONSENSUS_MID, null) == null:
			return {}
		var weeks_x = board.get(IntelLedger.KEY_CONSENSUS_WEEKS, null)
		var weeks_f: Variant = null
		if weeks_x != null and typeof(weeks_x) == TYPE_INT and Params.has_prm("PRM-SYS15-WEEKS_SCALE"):
			var scale: int = Params.get_int("PRM-SYS15-WEEKS_SCALE")
			if scale > 0:
				weeks_f = float(int(weeks_x)) / float(scale)
		return {
			"mid_li": int(board[IntelLedger.KEY_CONSENSUS_MID]),
			"weeks": weeks_f if weeks_f != null else 0.0,
		}
	return {}


func _can_enter(actor: StringName, port: StringName) -> bool:
	if _qual_open:
		return true
	if TradeDesk.has_method("has_qualification_provider") and TradeDesk.has_qualification_provider():
		## Use injected provider via a soft path: TradeDesk doesn't expose can_enter;
		## call through QualificationProvider if accessible — tests inject allow-all.
		pass
	## Without TierRegistry, QUAL_OPEN is the M1b path (D-109(e)).
	return _qual_open


func _can_trade_good(actor: StringName, port: StringName, good: StringName, side: int) -> bool:
	if _qual_open:
		return true
	return _qual_open


func _draft_ok(ship_id: StringName, dest: StringName) -> bool:
	var info: Dictionary = ShipRegistry.ship_info(ship_id)
	if info.is_empty():
		return false
	var type_s: String = String(info.get("type", ""))
	## F4②／C-06: unknown ship type → error, no silent default draft.
	if not ShipRegistry.SHIP_DRAFT.has(type_s):
		_day_errors.append(
			_err(ERR_SYS17_04, "ship_type", type_s, "SHIP_DRAFT missing type (C-06; no default)")
		)
		push_error("TraderRegistry: SHIP_DRAFT missing type %s (C-06)" % type_s)
		return false
	var ship_draft: int = int(ShipRegistry.SHIP_DRAFT[type_s])
	return ship_draft <= ShipRegistry.port_draft(dest)


func _clear_plan(t: Dictionary, sid: StringName) -> void:
	(t["plans"] as Dictionary)[String(sid)] = TradeEvaluator.empty_plan()


func _note_plan_inconsistent(tid: StringName, sid: StringName, msg: String) -> void:
	var e: Dictionary = _err(ERR_SYS17_05, "plan", sid, msg)
	_day_errors.append(e)
	push_error("TraderRegistry: %s" % str(e))


func _wrap_trade_reject(tid: StringName, detail: Dictionary) -> Dictionary:
	var e: Dictionary = _err(ERR_SYS17_06, "trade", tid, "TRADE_REJECTED")
	e["detail"] = detail
	return e


# --- util ---


func _load_curve() -> void:
	var res: Resource = ResourceLoader.load(CURVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res is PriceCurve:
		var c: PriceCurve = res as PriceCurve
		_curve_weeks = c.weeks
		_curve_mults = c.mults


func _clear_runtime() -> void:
	_loaded = false
	_enabled = false
	_qual_open = false
	_genesis_granted = false
	_last_error = {}
	_traders.clear()
	_frozen.clear()
	_voyage_days.clear()
	_curve_weeks = PackedFloat64Array()
	_curve_mults = PackedFloat64Array()
	_pending_signals.clear()
	_day_errors.clear()
	_intel_override.clear()


func _clear_runtime_keep_layers() -> void:
	var en := _enabled
	var qo := _qual_open
	var seed := _rng_seed
	_clear_runtime()
	_enabled = en
	_qual_open = qo
	_rng_seed = seed


func _clear_last() -> void:
	_last_error = {}


func _record(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)
	push_error("TraderRegistry: %s" % str(_last_error))


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _emit(errors: Array) -> void:
	for e in errors:
		push_error("TraderRegistry: %s" % str(e))


func _queue_signal(name: String, args: Array) -> void:
	_pending_signals.append({"name": name, "args": args})


func _array_len(v: Variant) -> int:
	if v is Array:
		return (v as Array).size()
	if v is PackedInt32Array:
		return (v as PackedInt32Array).size()
	if v is PackedInt64Array:
		return (v as PackedInt64Array).size()
	return 0


func _to_int_array(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(int(x))
	elif v is PackedInt32Array:
		for x in v:
			out.append(int(x))
	elif v is PackedInt64Array:
		for x in v:
			out.append(int(x))
	return out
