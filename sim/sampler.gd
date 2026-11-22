class_name SimSampler
extends RefCounted
## FRM-SYS23-06 season／daily sampling — public queries only (WP-26 / D-47b).
##
## A33／N-04: stock_weeks comes only from MarketPricer.stock_weeks (single formula site).
## Do not recompute weeks here. Cite: D-34d／D-52b／03_Systems FRM-SYS04-01／09.


## Header strings — 9.9 verbatim.
const HDR_SEASON_CELLS := (
	"run_id,seed,season_index,port_id,good_id,stock,mid_li,stock_weeks,band,"
	+ "produced,consumed,relocated_in,relocated_out"
)
const HDR_SEASON_PORTS := (
	"run_id,seed,season_index,port_id,rich,citizen,poor,beggar,sat_weighted,"
	+ "workplaces,beds,city_balance_li,"
	+ "land_rent_li,vacancy_tax_li,city_spend_json"
)
const HDR_DAILY := (
	"run_id,seed,day,good_id,stock,mid_li,stock_weeks,band,"
	+ "produced,consumed,relocated_in,relocated_out"
)


var acc: SimTransferAcc = null
var season_cells: Array = [] ## Dictionary rows
var season_ports: Array = []
var daily_rows: Dictionary = {} ## port_id -> Array of rows
var conservation_hits: int = 0
## WP-27 OBS-04／05 long-table rows (not part of 9.9 five CSV).
var obs_ext_rows: Array = []


func reset_run() -> void:
	season_cells.clear()
	season_ports.clear()
	daily_rows.clear()
	obs_ext_rows.clear()
	conservation_hits = 0
	if acc != null:
		acc.reset_counters()


func on_conservation(_good_id: StringName, _expected: int, _actual: int) -> void:
	conservation_hits = conservation_hits + 1


func sample_season(run_id: int, seed: int, season_index: int) -> void:
	var ports: PackedStringArray = PortRegistry.all_ids()
	var goods: PackedStringArray = GoodCatalog.all_ids()
	for i in range(ports.size()):
		var port_s: String = String(ports[i])
		_sample_port_row(run_id, seed, season_index, port_s)
		for j in range(goods.size()):
			var good_s: String = String(goods[j])
			season_cells.append(_cell_row(run_id, seed, season_index, -1, port_s, good_s, true))
	## Reset transfer counters after season sample so next season is independent.
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
	## WP-67／D-97(e) OBS-05: public queries only.
	var pid: StringName = StringName(port_s)
	var land_rent: int = BuildingEconomy.season_land_rent_li(pid, season_index)
	var vac_tax: int = BuildingEconomy.season_vacancy_tax_li(pid, season_index)
	var spend: Dictionary = BuildingEconomy.city_spend_by_category(pid, season_index)
	var spend_json: String = "{}" if spend.is_empty() else JSON.stringify(spend)
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
		"land_rent_li": land_rent,
		"vacancy_tax_li": vac_tax,
		"city_spend_json": spend_json,
	})


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
	if acc != null:
		produced = acc.produced(port_s, good_s)
		consumed = acc.consumed(port_s, good_s)
		reloc_in = acc.relocated_in(port_s, good_s)
		reloc_out = acc.relocated_out(port_s, good_s)
	## WP-27 OBS-04: capture weekly potential at sample time (not written to 9.9 CSV).
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
		"_weekly_potential": potential,
	}
	if is_season:
		row["season_index"] = season_index
	else:
		row["day"] = day
	return row
