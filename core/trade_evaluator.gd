class_name TradeEvaluator
extends RefCounted
## D-44g／FRM-SYS17-02／FRM-SYS18-02: pure trade evaluation core (SYS-17／18 shared).
## No Autoload module state except F4③ sell-revenue → MarketPricer.batch_area (N-04／D-120(b)④).

const PHASE_NONE := &"NONE"
const PHASE_OUTBOUND := &"OUTBOUND"
const PHASE_SELL := &"SELL"


## FRM-SYS17-02／EX-17-02-01: daily marginal profit (li／day), floori.
## sell_revenue_li = estimated sell income (D-110(g) depth area, or mid×q for EX-17-02-01).
## tax_li = 0 until WP-39 (D-109(b)). voyage_days ≥ 1.
static func daily_marginal_profit(
	sell_revenue_li: int, buy_cost_li: int, tax_li: int, voyage_days: int
) -> int:
	if voyage_days < 1:
		return 0
	return floori((sell_revenue_li - buy_cost_li - tax_li) / float(voyage_days))


## D-110(g)／EX-17-02-02／03／F4③: estimated sell revenue via MarketPricer.batch_area.
## w0 = destination board consensus weeks; weekly_potential > 0; q > 0.
## stock_before = roundi(w0 × weekly); stock_after = stock_before + qty (sell into market).
static func estimate_sell_revenue_li(
	anchor_li: int,
	weekly_potential: float,
	w0: float,
	qty: int
) -> int:
	if qty <= 0 or weekly_potential <= 0.0 or anchor_li <= 0:
		return 0
	if not MarketPricer.is_loaded():
		return 0
	var stock_before: int = roundi(w0 * weekly_potential)
	if stock_before < 0:
		stock_before = 0
	var stock_after: int = stock_before + qty
	return floori(MarketPricer.batch_area(anchor_li, weekly_potential, stock_before, stock_after))


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
		## F4① (ppm path): integer multiply then floori divide (no float(n)*rate+1e-9).
		var tol: int = 0
		if ppm_scale > 0:
			tol = floori(float(best_buy_cost_li * loss_tol_ppm) / float(ppm_scale))
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
