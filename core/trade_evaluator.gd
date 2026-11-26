class_name TradeEvaluator
extends RefCounted
## D-44g／FRM-SYS17-02／FRM-SYS18-02: pure trade evaluation core (SYS-17／18 shared).
## No Autoload; no module state. Callers pass all inputs (N-04／C-07).
## D-110(g): sell revenue via batch-area along FRM-SYS04 curve (same trapezoid as MarketPricer).
## Gap C-05: MarketPricer.batch_area is private — this file owns the shared pure copy until
## MarketPricer exposes a public batch_area (then both must call one site).

const PHASE_NONE := &"NONE"
const PHASE_OUTBOUND := &"OUTBOUND"
const PHASE_SELL := &"SELL"

const TRAPEZOID_DENOM := 2.0


## FRM-SYS17-02／EX-17-02-01: daily marginal profit (li／day), floori.
## sell_revenue_li = estimated sell income (D-110(g) depth area, or mid×q for EX-17-02-01).
## tax_li = 0 until WP-39 (D-109(b)). voyage_days ≥ 1.
static func daily_marginal_profit(
	sell_revenue_li: int, buy_cost_li: int, tax_li: int, voyage_days: int
) -> int:
	if voyage_days < 1:
		return 0
	return floori((sell_revenue_li - buy_cost_li - tax_li) / float(voyage_days))


## D-110(g)／EX-17-02-02／03: estimated sell revenue from weeks path.
## w0 = destination board consensus weeks; weekly_potential > 0; q > 0.
## Area = anchor × weekly × |G(w0+Δw) − G(w0)| with Δw = q／weekly (FRM-SYS04-04).
static func estimate_sell_revenue_li(
	anchor_li: int,
	weekly_potential: float,
	w0: float,
	qty: int,
	weeks: PackedFloat64Array,
	mults: PackedFloat64Array
) -> int:
	if qty <= 0 or weekly_potential <= 0.0 or anchor_li <= 0:
		return 0
	var delta_w: float = float(qty) / weekly_potential
	var w1: float = w0 + delta_w
	var area: float = float(anchor_li) * weekly_potential * absf(_G(w1, weeks, mults) - _G(w0, weeks, mults))
	return floori(area)


## Equivalent stock-path form (N-04 mirror of MarketPricer._batch_area).
static func batch_area_li(
	anchor_li: int,
	weekly_basis: float,
	stock_before: int,
	stock_after: int,
	weeks: PackedFloat64Array,
	mults: PackedFloat64Array
) -> int:
	var q: int = stock_after - stock_before
	if q < 0:
		q = 0 - q
	var w_before: Variant = _stock_weeks_raw(stock_before, weekly_basis)
	var w_after: Variant = _stock_weeks_raw(stock_after, weekly_basis)
	if w_before == null or w_after == null:
		return floori(float(anchor_li) * _floor_mult(mults) * float(q))
	var delta_g: float = _G(float(w_after), weeks, mults) - _G(float(w_before), weeks, mults)
	if delta_g < 0.0:
		delta_g = 0.0 - delta_g
	return floori(float(anchor_li) * weekly_basis * delta_g)


## FRM-SYS17-03／EX-17-03-*: decide sail vs idle given best candidate profit and idle streak.
## Returns {sail: bool, idle_days_after: int}.
static func decide_sail_or_idle(
	best_daily_profit_li: int,
	best_buy_cost_li: int,
	best_sell_revenue_li: int,
	idle_days: int,
	profit_min_li: int,
	idle_days_max: int,
	loss_tol_ppm: int,
	ppm_scale: int
) -> Dictionary:
	var sail := false
	if best_daily_profit_li >= profit_min_li:
		sail = true
	elif idle_days >= idle_days_max and best_buy_cost_li > 0:
		var expected_loss: int = best_buy_cost_li - best_sell_revenue_li
		if expected_loss < 0:
			expected_loss = 0
		var tol: int = floori(float(best_buy_cost_li) * float(loss_tol_ppm) / float(ppm_scale))
		if expected_loss <= tol:
			sail = true
	var idle_after: int = 0 if sail else idle_days + 1
	return {"sail": sail, "idle_days_after": idle_after}


## FRM-SYS17-09: pick best candidate; ties → (port_id, good_id) ascending.
## candidates: Array[{port_id, good_id, daily_profit_li, ...}]
static func pick_best_candidate(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	var best: Dictionary = candidates[0]
	for i in range(1, candidates.size()):
		var c: Dictionary = candidates[i]
		var bp: int = int(best.get("daily_profit_li", 0))
		var cp: int = int(c.get("daily_profit_li", 0))
		if cp > bp:
			best = c
			continue
		if cp < bp:
			continue
		var bport := String(best.get("port_id", ""))
		var cport := String(c.get("port_id", ""))
		if cport < bport:
			best = c
			continue
		if cport > bport:
			continue
		var bgood := String(best.get("good_id", ""))
		var cgood := String(c.get("good_id", ""))
		if cgood < bgood:
			best = c
	return best


## Coarse rank key for D-104(c)⑤ mid×q − rough buy; higher is better.
static func coarse_score(mid_li: int, qty: int, rough_buy_li: int, voyage_days: int) -> int:
	if voyage_days < 1 or qty < 1:
		return -9223372036854775807
	return floori((float(mid_li) * float(qty) - float(rough_buy_li)) / float(voyage_days))


static func empty_plan() -> Dictionary:
	return {
		"phase": PHASE_NONE,
		"from_port": &"",
		"to_port": &"",
		"good_id": &"",
		"qty": 0,
		"expected_profit_li": 0,
	}


static func _stock_weeks_raw(stock: int, weekly: float) -> Variant:
	if stock == 0:
		return 0.0
	if weekly <= 0.0:
		return null
	return float(stock) / weekly


static func _floor_mult(mults: PackedFloat64Array) -> float:
	if mults.is_empty():
		return 0.0
	return float(mults[mults.size() - 1])


static func _G(x: float, weeks: PackedFloat64Array, mults: PackedFloat64Array) -> float:
	## FRM-SYS04-04 trapezoid integral of m(w) — mirror MarketPricer._G.
	if x <= 0.0 or weeks.is_empty() or mults.is_empty():
		return 0.0
	var n: int = mini(weeks.size(), mults.size())
	var last_i: int = n - 1
	var total: float = 0.0
	var i: int = 0
	while i < last_i:
		var w_a: float = weeks[i]
		var w_b: float = weeks[i + 1]
		var m_a: float = mults[i]
		var m_b: float = mults[i + 1]
		var e: float = x
		if e < w_a:
			e = w_a
		if e > w_b:
			e = w_b
		var m_e: float = m_a + (m_b - m_a) * (e - w_a) / (w_b - w_a)
		total = total + (e - w_a) * (m_a + m_e) / TRAPEZOID_DENOM
		i = i + 1
	var w_n: float = weeks[last_i]
	if x > w_n:
		total = total + (x - w_n) * mults[last_i]
	return total
