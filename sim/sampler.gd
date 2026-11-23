class_name SimSampler
extends RefCounted
## FRM-SYS23-06 season／daily sampling — public queries only (WP-26 / D-47b).
##
## A33／N-04: stock_weeks comes only from MarketPricer.stock_weeks (single formula site).
## Do not recompute weeks here. Cite: D-34d／D-52b／03_Systems FRM-SYS04-01／09.
## D-110(d)(i): queue_state、各階 sat／cap、PF 流量、最缺 3 貨；excess_consumed；trader_summary.


## Header strings — 9.9 + D-110(d)(i).
const HDR_SEASON_CELLS := (
	"run_id,seed,season_index,port_id,good_id,stock,mid_li,stock_weeks,band,"
	+ "produced,consumed,relocated_in,relocated_out,excess_consumed"
)
const HDR_SEASON_PORTS := (
	"run_id,seed,season_index,port_id,rich,citizen,poor,beggar,sat_weighted,"
	+ "workplaces,beds,city_balance_li,queue_position,"
	+ "land_rent_li,vacancy_tax_li,city_spend_json,"
	+ "queue_state,sat_poor,sat_citizen,sat_rich,job_cap,cap_sat_up1,cap_sat_up2,"
	+ "pf1,pf2,pf3,pf4,pf5,pf6,"
	+ "unmet_poor_top3,unmet_citizen_top3,unmet_rich_top3"
)
const HDR_DAILY := (
	"run_id,seed,day,good_id,stock,mid_li,stock_weeks,band,"
	+ "produced,consumed,relocated_in,relocated_out"
)
## D-110(d): trader_summary（Lane A fills TraderRegistry; zeros until then）.
const HDR_TRADER_SUMMARY := (
	"run_id,seed,season_index,port_id,sail_count,ships_in_port,frozen_traders,"
	+ "cargo_dan_json,avg_daily_margin_li"
)


var acc: SimTransferAcc = null
var season_cells: Array = [] ## Dictionary rows
var season_ports: Array = []
var daily_rows: Dictionary = {} ## port_id -> Array of rows
var conservation_hits: int = 0
## WP-27 OBS-04／05 long-table rows (not part of 9.9 five CSV).
var obs_ext_rows: Array = []
## D-110(d): trader_summary rows（per season × port）.
var trader_summary_rows: Array = []
## D-110(i): season unmet accum port|good → int（from DemandModel.demand_unmet）.
var _unmet_season: Dictionary = {}
var _unmet_connected: bool = false


func reset_run() -> void:
	season_cells.clear()
	season_ports.clear()
	daily_rows.clear()
	obs_ext_rows.clear()
	trader_summary_rows.clear()
	_unmet_season.clear()
	conservation_hits = 0
	if acc != null:
		acc.reset_counters()


func connect_unmet() -> void:
	## D-110(i): accumulate DemandModel.demand_unmet across the season.
	if _unmet_connected:
		return
	if DemandModel.demand_unmet.is_connected(_on_demand_unmet):
		_unmet_connected = true
		return
	DemandModel.demand_unmet.connect(_on_demand_unmet)
	_unmet_connected = true


func disconnect_unmet() -> void:
	if _unmet_connected and DemandModel.demand_unmet.is_connected(_on_demand_unmet):
		DemandModel.demand_unmet.disconnect(_on_demand_unmet)
	_unmet_connected = false


func on_conservation(_good_id: StringName, _expected: int, _actual: int) -> void:
	conservation_hits = conservation_hits + 1


func sample_season(run_id: int, seed: int, season_index: int) -> void:
	var ports: PackedStringArray = PortRegistry.all_ids()
	var goods: PackedStringArray = GoodCatalog.all_ids()
	for i in range(ports.size()):
		var port_s: String = String(ports[i])
		_sample_port_row(run_id, seed, season_index, port_s)
		_sample_trader_row(run_id, seed, season_index, port_s)
		for j in range(goods.size()):
			var good_s: String = String(goods[j])
			season_cells.append(_cell_row(run_id, seed, season_index, -1, port_s, good_s, true))
	## Reset transfer counters + unmet after season sample so next season is independent.
	_unmet_season.clear()
	if acc != null:
		acc.reset_counters()


func sample_daily(run_id: int, seed: int, day: int, port_id: String) -> void:
	if not daily_rows.has(port_id):
		daily_rows[port_id] = []
	var goods: PackedStringArray = GoodCatalog.all_ids()
	for j in range(goods.size()):
		var good_s: String = String(goods[j])
		(daily_rows[port_id] as Array).append(
			_cell_row(run_id, seed, -1, day, port_id, good_s, false)
		)


func _sample_port_row(run_id: int, seed: int, season_index: int, port_s: String) -> void:
	var poor: int = PopulationModel.population(StringName(port_s), PopulationModel.CLASS_POOR)
	var citizen: int = PopulationModel.population(StringName(port_s), PopulationModel.CLASS_CITIZEN)
	var rich: int = PopulationModel.population(StringName(port_s), PopulationModel.CLASS_RICH)
	var beggar: int = PopulationModel.beggars(StringName(port_s))
	var sat_w: int = PopulationModel.weighted_avg_sat(port_s)
	var workplaces: int = BuildingEconomy.workplaces(StringName(port_s)).size()
	var beds: int = PopulationModel.housing_capacity(StringName(port_s))
	var city_id: StringName = CashLedger.make_city_id(port_s)
	var bal: int = CashLedger.balance(city_id)
	## WP-67／D-97(e) OBS-05: public queries only when BuildingEconomy loaded.
	var pid: StringName = StringName(port_s)
	var land_rent := -1
	var vac_tax := -1
	var spend_json := "{}"
	var queue_state := ""
	var sat_poor := 0
	var sat_citizen := 0
	var sat_rich := 0
	var job_cap := 0
	var cap_sat_up1 := 0
	var cap_sat_up2 := 0
	if BuildingEconomy.is_loaded():
		land_rent = BuildingEconomy.season_land_rent_li(pid, season_index)
		vac_tax = BuildingEconomy.season_vacancy_tax_li(pid, season_index)
		var spend: Dictionary = BuildingEconomy.city_spend_by_category(pid, season_index)
		spend_json = "{}" if spend.is_empty() else JSON.stringify(spend)
		if BuildingEconomy.has_method("city_queue_state"):
			queue_state = String(BuildingEconomy.city_queue_state(pid))
	if PopulationModel.is_loaded():
		sat_poor = PopulationModel.satisfaction(pid, PopulationModel.CLASS_POOR)
		sat_citizen = PopulationModel.satisfaction(pid, PopulationModel.CLASS_CITIZEN)
		sat_rich = PopulationModel.satisfaction(pid, PopulationModel.CLASS_RICH)
		job_cap = PopulationModel.job_capacity(pid)
	## D-110(d) 各階 cap：升階門檻（現值＝sat_*）.
	if Params.is_loaded():
		if Params.has_prm("PRM-SYS07-SAT_UP1_MIN"):
			cap_sat_up1 = Params.get_int("PRM-SYS07-SAT_UP1_MIN")
		if Params.has_prm("PRM-SYS07-SAT_UP2_MIN"):
			cap_sat_up2 = Params.get_int("PRM-SYS07-SAT_UP2_MIN")
	## D-110(i): Lane B owns season_flow_counts; read when present.
	var flows: Dictionary = _read_season_flows(pid, season_index)
	var unmet_p: String = _top3_unmet_for_class(port_s, PopulationModel.CLASS_POOR)
	var unmet_c: String = _top3_unmet_for_class(port_s, PopulationModel.CLASS_CITIZEN)
	var unmet_r: String = _top3_unmet_for_class(port_s, PopulationModel.CLASS_RICH)
	season_ports.append({
		"run_id": run_id,
		"seed": seed,
		"season_index": season_index,
		"port_id": port_s,
		"rich": rich,
		"citizen": citizen,
		"poor": poor,
		"beggar": beggar,
		"sat_weighted": sat_w,
		"workplaces": workplaces,
		"beds": beds,
		"city_balance_li": bal,
		"queue_position": BuildingEconomy.city_queue_position(StringName(port_s)),
		"land_rent_li": land_rent,
		"vacancy_tax_li": vac_tax,
		"city_spend_json": spend_json,
		"queue_state": queue_state,
		"sat_poor": sat_poor,
		"sat_citizen": sat_citizen,
		"sat_rich": sat_rich,
		"job_cap": job_cap,
		"cap_sat_up1": cap_sat_up1,
		"cap_sat_up2": cap_sat_up2,
		"pf1": int(flows.get("PF-1", 0)),
		"pf2": int(flows.get("PF-2", 0)),
		"pf3": int(flows.get("PF-3", 0)),
		"pf4": int(flows.get("PF-4", 0)),
		"pf5": int(flows.get("PF-5", 0)),
		"pf6": int(flows.get("PF-6", 0)),
		"unmet_poor_top3": unmet_p,
		"unmet_citizen_top3": unmet_c,
		"unmet_rich_top3": unmet_r,
	})


func _sample_trader_row(run_id: int, seed: int, season_index: int, port_s: String) -> void:
	## D-110(d) trader_summary — TraderRegistry public queries when Lane A present.
	var sail := 0
	var in_port := 0
	var frozen := 0
	var cargo_json := "{}"
	var avg_margin := 0
	var tre: Object = _trader_registry()
	if tre != null:
		if tre.has_method("season_sail_count"):
			sail = int(tre.call("season_sail_count", StringName(port_s), season_index))
		if tre.has_method("ships_in_port_count"):
			in_port = int(tre.call("ships_in_port_count", StringName(port_s)))
		if tre.has_method("frozen_trader_count"):
			frozen = int(tre.call("frozen_trader_count", StringName(port_s)))
		if tre.has_method("season_cargo_dan"):
			var cargo: Variant = tre.call("season_cargo_dan", StringName(port_s), season_index)
			if typeof(cargo) == TYPE_DICTIONARY:
				var cd: Dictionary = cargo
				cargo_json = "{}" if cd.is_empty() else JSON.stringify(cd)
		if tre.has_method("season_avg_daily_margin_li"):
			avg_margin = int(tre.call("season_avg_daily_margin_li", StringName(port_s), season_index))
	trader_summary_rows.append({
		"run_id": run_id,
		"seed": seed,
		"season_index": season_index,
		"port_id": port_s,
		"sail_count": sail,
		"ships_in_port": in_port,
		"frozen_traders": frozen,
		"cargo_dan_json": cargo_json,
		"avg_daily_margin_li": avg_margin,
	})


func _trader_registry() -> Object:
	## Autoload may be absent until Lane A; Engine.has_singleton avoids hard fail.
	if Engine.has_singleton("TraderRegistry"):
		return Engine.get_singleton("TraderRegistry") as Object
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var n: Node = (tree as SceneTree).root.get_node_or_null("TraderRegistry")
		return n
	return null


func _read_season_flows(port_id: StringName, season_index: int) -> Dictionary:
	## Lane B implements PopulationModel.season_flow_counts; empty until merged.
	if not PopulationModel.has_method("season_flow_counts"):
		return {}
	var v: Variant = PopulationModel.call("season_flow_counts", port_id, season_index)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return v as Dictionary


func _on_demand_unmet(port_id: StringName, good_id: StringName, shortfall: int) -> void:
	if shortfall <= 0:
		return
	var k: String = "%s|%s" % [String(port_id), String(good_id)]
	_unmet_season[k] = int(_unmet_season.get(k, 0)) + shortfall


func _top3_unmet_for_class(port_s: String, clazz: StringName) -> String:
	## D-110(i): among goods with sat weight for class, top 3 by season unmet shortfall.
	if not DemandModel.is_loaded():
		return ""
	var items: Array = []
	var goods: PackedStringArray = GoodCatalog.all_ids() if GoodCatalog.is_loaded() else PackedStringArray()
	for g_v in goods:
		var g: String = String(g_v)
		var w: int = DemandModel.sat_weight_pct(clazz, StringName(g))
		if w <= 0:
			continue
		var amt: int = int(_unmet_season.get("%s|%s" % [port_s, g], 0))
		if amt <= 0:
			continue
		items.append({"good": g, "amt": amt})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["amt"]) == int(b["amt"]):
			return String(a["good"]) < String(b["good"])
		return int(a["amt"]) > int(b["amt"])
	)
	var parts: PackedStringArray = PackedStringArray()
	var n: int = mini(3, items.size())
	for i in range(n):
		var it: Dictionary = items[i]
		parts.append("%s:%d" % [String(it["good"]), int(it["amt"])])
	return "|".join(parts)


func _cell_row(
	run_id: int,
	seed: int,
	season_index: int,
	day: int,
	port_s: String,
	good_s: String,
	is_season: bool
) -> Dictionary:
	var market: Dictionary = GoodsLedger.make_market(port_s)
	var stock: int = GoodsLedger.get_qty(market, StringName(good_s))
	var mid: float = MarketPricer.mid_price(StringName(port_s), StringName(good_s))
	var mid_li: int = floori(mid)
	## A33／N-04: single weeks formula via MarketPricer.stock_weeks (null when no offtake).
	var weeks_v: Variant = MarketPricer.stock_weeks(StringName(port_s), StringName(good_s))
	var stock_weeks_s: String = ""
	var band: int = MarketPricer.BAND_EQUILIBRIUM
	if weeks_v != null:
		stock_weeks_s = str(weeks_v)
		var good: GoodDef = GoodCatalog.get_good(good_s)
		var anchor: int = good.base_price_li
		var ratio: float = 0.0
		if anchor > 0:
			ratio = mid / float(anchor)
		band = MarketPricer.indicator_band(ratio)
	var produced: int = 0
	var consumed: int = 0
	var reloc_in: int = 0
	var reloc_out: int = 0
	var excess: int = 0
	if acc != null:
		produced = acc.produced(port_s, good_s)
		consumed = acc.consumed(port_s, good_s)
		reloc_in = acc.relocated_in(port_s, good_s)
		reloc_out = acc.relocated_out(port_s, good_s)
		if acc.has_method("excess_consumed"):
			excess = int(acc.call("excess_consumed", port_s, good_s))
	## WP-27／WP-64 OBS-04: weekly potential at sample time (not written to 9.9 CSV).
	var potential: int = 0
	if DemandModel.is_loaded():
		potential = DemandModel.weekly_potential_demand(StringName(port_s), StringName(good_s))
	var row := {
		"run_id": run_id,
		"seed": seed,
		"port_id": port_s,
		"good_id": good_s,
		"stock": stock,
		"mid_li": mid_li,
		"stock_weeks": stock_weeks_s,
		"band": band,
		"produced": produced,
		"consumed": consumed,
		"relocated_in": reloc_in,
		"relocated_out": reloc_out,
		"excess_consumed": excess,
		"_weekly_potential": potential,
	}
	if is_season:
		row["season_index"] = season_index
	else:
		row["day"] = day
	return row
