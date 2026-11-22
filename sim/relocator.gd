class_name SimRelocator
extends RefCounted
## FRM-SYS23-04 ideal relocator (WP-27／D-93). Integer path; MARKET→MARKET; SIM_RELOCATE.


const PRM_PPM_SCALE := "PRM-SYS06-PPM_SCALE"
const PRM_ROUND_EPS := "PRM-SYS04-ROUND_EPS"
const REQUESTER_SYS23 := &"SYS-23"
const ERR_SYS23_03 := "ERR-SYS23-03"
const ERR_SYS23_07 := "ERR-SYS23-07"


## C-02／D-93: relocate_f × PPM_SCALE → integer f_ppm; relative error ≤ ROUND_EPS → snap.
static func f_to_ppm(relocate_f: float, ppm_scale: int, round_eps: float) -> Dictionary:
	## Returns {ok: bool, f_ppm: int, error: String}.
	if ppm_scale <= 0:
		return {
			"ok": false,
			"f_ppm": 0,
			"error": "%s: PPM_SCALE must be > 0" % ERR_SYS23_03,
		}
	var product: float = relocate_f * float(ppm_scale)
	## C-02／D-01-style snap: round() only to test near-integer; final via floori.
	var nearest: float = round(product)
	var scale: float = absf(product)
	if scale < 1.0:
		scale = 1.0
	var rel_err: float = absf(product - nearest) / scale
	if rel_err > round_eps:
		return {
			"ok": false,
			"f_ppm": 0,
			"error": (
				"%s: relocate_f × PPM_SCALE not integer (product=%s rel_err=%s)"
				% [ERR_SYS23_03, str(product), str(rel_err)]
			),
		}
	return {"ok": true, "f_ppm": floori(nearest), "error": ""}


## Pure FRM-SYS23-04 allocation for one good (fixture／tests). No ledger writes.
## stocks: Dictionary port_id:String → int; potentials: port_id → int w_p.
## Returns {ok, error, exports: {port→e}, imports: {port→a}, moves: Array[{from,to,qty}]}.
static func plan_one_good(
	stocks: Dictionary,
	potentials: Dictionary,
	f_ppm: int,
	ppm_scale: int
) -> Dictionary:
	var empty := {
		"ok": true,
		"error": "",
		"exports": {},
		"imports": {},
		"moves": [],
	}
	if ppm_scale <= 0 or f_ppm < 0:
		return {
			"ok": false,
			"error": "%s: invalid f_ppm／ppm_scale" % ERR_SYS23_03,
			"exports": {},
			"imports": {},
			"moves": [],
		}
	var port_ids: Array = []
	for p_v in stocks.keys():
		port_ids.append(String(p_v))
	port_ids.sort() ## C-08

	var S: int = 0
	var W: int = 0
	var stock_by: Dictionary = {}
	var w_by: Dictionary = {}
	for pid_v in port_ids:
		var pid: String = String(pid_v)
		var stock_i: int = _as_nonneg_int(stocks.get(pid, 0), "stock")
		var w_i: int = _as_nonneg_int(potentials.get(pid, 0), "potential")
		stock_by[pid] = stock_i
		w_by[pid] = w_i
		if not _add_ok(S, stock_i):
			return _fail_overflow("S")
		S = S + stock_i
		if w_i > 0:
			if not _add_ok(W, w_i):
				return _fail_overflow("W")
			W = W + w_i
	if W == 0:
		return empty

	var exports: Dictionary = {}
	var T: int = 0
	for pid_v in port_ids:
		var pid2: String = String(pid_v)
		var stock_p: int = SimJsonInt.as_int(stock_by[pid2], "stock_p")
		var w_p: int = SimJsonInt.as_int(w_by[pid2], "w_p")
		## D-93／R9-65 B2: e_p all-integer; C-10 overflow checks before multiply.
		## e_p = (f_ppm × (stock_p × W − S × w_p)) ÷ (W × PPM_SCALE); only e_p > 0.
		if not _mul_ok(stock_p, W) or not _mul_ok(S, w_p):
			return _fail_overflow("e_p numer")
		var numer_inner: int = stock_p * W - S * w_p
		if numer_inner <= 0:
			continue
		if not _mul_ok(f_ppm, numer_inner) or not _mul_ok(W, ppm_scale):
			return _fail_overflow("e_p")
		var denom: int = W * ppm_scale
		if denom <= 0:
			return {
				"ok": false,
				"error": "%s: e_p denom <= 0" % ERR_SYS23_03,
				"exports": {},
				"imports": {},
				"moves": [],
			}
		var e_p: int = (f_ppm * numer_inner) / denom
		if e_p > 0:
			## R9-65 B6／C-06: never clamp e_p to stock_p — math exceeding stock is an error.
			if e_p > stock_p:
				return {
					"ok": false,
					"error": (
						"%s: e_p %s exceeds stock_p %s at %s (no clamp)"
						% [ERR_SYS23_07, str(e_p), str(stock_p), pid2]
					),
					"exports": {},
					"imports": {},
					"moves": [],
				}
			exports[pid2] = e_p
			if not _add_ok(T, e_p):
				return _fail_overflow("T")
			T = T + e_p
	if T == 0:
		return empty

	var deficit_ports: Array = []
	var deficit_weights: Array = []
	for pid_v2 in port_ids:
		var pid3: String = String(pid_v2)
		var w_q: int = SimJsonInt.as_int(w_by[pid3], "w_q")
		if w_q <= 0:
			continue
		var stock_q: int = SimJsonInt.as_int(stock_by[pid3], "stock_q")
		if not _mul_ok(S, w_q) or not _mul_ok(stock_q, W):
			return _fail_overflow("d_q")
		var d_q: int = S * w_q - stock_q * W
		if d_q > 0:
			deficit_ports.append(pid3)
			deficit_weights.append(d_q)
	if deficit_ports.is_empty():
		return empty

	var alloc: Array = CashLedger.split_largest_remainder(T, deficit_weights)
	if alloc.is_empty() or alloc.size() != deficit_ports.size():
		return {
			"ok": false,
			"error": "%s: split_largest_remainder failed" % ERR_SYS23_07,
			"exports": exports,
			"imports": {},
			"moves": [],
		}
	var imports: Dictionary = {}
	for i in range(deficit_ports.size()):
		var a_i: int = SimJsonInt.as_int(alloc[i], "alloc")
		if a_i > 0:
			imports[String(deficit_ports[i])] = a_i

	## ⑦ Pair: surplus／deficit each port_id ascending, dual pointer.
	var surplus_ports: Array = exports.keys()
	surplus_ports.sort()
	var import_ports: Array = imports.keys()
	import_ports.sort()
	var moves: Array = []
	var si: int = 0
	var di: int = 0
	var s_left: Dictionary = exports.duplicate()
	var d_left: Dictionary = imports.duplicate()
	while si < surplus_ports.size() and di < import_ports.size():
		var sp: String = String(surplus_ports[si])
		var dp: String = String(import_ports[di])
		var s_rem: int = SimJsonInt.as_int(s_left.get(sp, 0), "s_rem")
		var d_rem: int = SimJsonInt.as_int(d_left.get(dp, 0), "d_rem")
		if s_rem <= 0:
			si = si + 1
			continue
		if d_rem <= 0:
			di = di + 1
			continue
		var qty: int = s_rem if s_rem < d_rem else d_rem
		moves.append({"from": sp, "to": dp, "qty": qty})
		s_left[sp] = s_rem - qty
		d_left[dp] = d_rem - qty
		if SimJsonInt.as_int(s_left[sp], "s_left") <= 0:
			si = si + 1
		if SimJsonInt.as_int(d_left[dp], "d_left") <= 0:
			di = di + 1

	return {
		"ok": true,
		"error": "",
		"exports": exports,
		"imports": imports,
		"moves": moves,
	}


## Apply FRM-SYS23-04 for all goods (good_id ascending). Returns {ok, error, move_count}.
static func run_day(f_ppm: int, ppm_scale: int, acc: SimTransferAcc = null) -> Dictionary:
	if not GoodsLedger.is_sim_relocate_enabled():
		return {
			"ok": false,
			"error": "%s: SIM_RELOCATE not enabled" % ERR_SYS23_07,
			"move_count": 0,
		}
	var goods: PackedStringArray = GoodCatalog.all_ids()
	var ports: PackedStringArray = PortRegistry.all_ids()
	var move_count: int = 0
	for gi in range(goods.size()):
		var good_s: String = String(goods[gi])
		var stocks: Dictionary = {}
		var pots: Dictionary = {}
		for pi in range(ports.size()):
			var pid: String = String(ports[pi])
			var mkt: Dictionary = GoodsLedger.make_market(pid)
			stocks[pid] = GoodsLedger.get_qty(mkt, StringName(good_s))
			pots[pid] = DemandModel.weekly_potential_demand(StringName(pid), StringName(good_s))
		var plan: Dictionary = plan_one_good(stocks, pots, f_ppm, ppm_scale)
		if not bool(plan.get("ok", false)):
			return {
				"ok": false,
				"error": String(plan.get("error", ERR_SYS23_07)),
				"move_count": move_count,
			}
		for mv_v in plan["moves"]:
			var mv: Dictionary = mv_v
			var qty: int = SimJsonInt.as_int(mv["qty"], "move_qty")
			if qty <= 0:
				continue
			var from_c: Dictionary = GoodsLedger.make_market(String(mv["from"]))
			var to_c: Dictionary = GoodsLedger.make_market(String(mv["to"]))
			var seq: int = GoodsLedger.transfer(
				from_c,
				to_c,
				StringName(good_s),
				qty,
				GoodsLedger.REASON_SIM_RELOCATE,
				REQUESTER_SYS23
			)
			if seq <= 0:
				var le: Dictionary = GoodsLedger.last_error()
				return {
					"ok": false,
					"error": "%s: transfer failed %s" % [ERR_SYS23_07, str(le)],
					"move_count": move_count,
				}
			move_count = move_count + 1
			if acc != null:
				acc.note_relocate(String(mv["from"]), String(mv["to"]), good_s, qty)
	return {"ok": true, "error": "", "move_count": move_count}


static func _fail_overflow(field: String) -> Dictionary:
	return {
		"ok": false,
		"error": "%s: C-10 overflow at %s" % [ERR_SYS23_07, field],
		"exports": {},
		"imports": {},
		"moves": [],
	}


static func _as_nonneg_int(v: Variant, _label: String) -> int:
	return SimJsonInt.as_int(v, "relocator")


static func _mul_ok(a: int, b: int) -> bool:
	## C-10: same check style as CashLedger._mul_checked (no wrap reliance).
	if a == 0 or b == 0:
		return true
	var product: int = a * b
	return product / a == b


static func _add_ok(a: int, b: int) -> bool:
	if b == 0:
		return true
	if b > 0:
		return a <= a + b
	return a >= a + b
