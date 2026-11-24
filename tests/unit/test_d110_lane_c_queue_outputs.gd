extends GutTest
## Lane C／D-110(b)(d)(i): city_queue_material_shortfall、queue_state、sim headers.
## New tests: fixtures／user:// only；no res://data writes；no git (D-114(d)).


const PORT := "PT-10"


func before_each() -> void:
	BuildingEconomy._loaded = false
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	CashLedger._loaded = false
	Params._loaded = false
	PopulationModel._loaded = false
	DemandModel._loaded = false


func test_D110b_unknown_port_empty_plus_last_error() -> void:
	_boot_min()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._slots_by_port[PORT] = []
	var out: Dictionary = BuildingEconomy.city_queue_material_shortfall(StringName("PT-NOPE"))
	assert_eq(out.size(), 0)
	assert_eq(
		String(BuildingEconomy.last_error().get("code", "")),
		String(BuildingEconomy.ERR_SYS08_08)
	)
	for e in get_errors():
		e.handled = true


func test_D110b_not_waiting_material_returns_empty() -> void:
	## EX-08-25-03／04: BUILDING or not-ordered → empty shortfall.
	_boot_min()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._slots_by_port[PORT] = []
	BuildingEconomy._buildings_by_port[PORT] = []
	BuildingEconomy.set_build_queue(PORT, [_step(PORT, 0, "CB-01", 2)])
	## No WAITING_MATERIAL city public → empty.
	var out: Dictionary = BuildingEconomy.city_queue_material_shortfall(StringName(PORT))
	assert_eq(out.size(), 0)
	assert_eq(BuildingEconomy.city_queue_state(StringName(PORT)), BuildingEconomy.QUEUE_STATE_CASH)


func test_D110b_waiting_material_shortfall_sorted() -> void:
	## EX-08-25-01 shape: WAITING_MATERIAL + missing_materials → shortfall dict asc keys.
	_boot_min()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._slots_by_port[PORT] = []
	var city: StringName = CashLedger.make_city_id(PORT)
	CashLedger.create_account(city, Account.Kind.CITY)
	var bld := Building.new()
	bld.building_id = &"BLD-C-WAIT"
	bld.type = &"CB-04"
	bld.cb_id = &"CB-04"
	bld.build_class = BuildingEconomy.CLASS_PUBLIC
	bld.owner = city
	bld.port_id = PORT
	bld.level = 2
	bld.state = Building.State.WAITING_MATERIAL
	bld.missing_materials = {"GD-013": 400, "GD-012": 1000} ## brick／wood ids may vary; keys sorted
	bld.locked_materials = {"GD-013": 200}
	BuildingEconomy._buildings[String(bld.building_id)] = bld
	BuildingEconomy._buildings_by_port[PORT] = [bld]
	BuildingEconomy.set_build_queue(PORT, [_step(PORT, 0, "CB-04", 2)])
	BuildingEconomy._queue_pos[PORT] = 1 ## started → pos advanced
	var out: Dictionary = BuildingEconomy.city_queue_material_shortfall(StringName(PORT))
	assert_eq(out.size(), 2)
	var keys: Array = out.keys()
	keys.sort()
	assert_eq(String(keys[0]), "GD-012")
	assert_eq(String(keys[1]), "GD-013")
	assert_eq(int(out["GD-012"]), 1000)
	assert_eq(int(out["GD-013"]), 400)
	assert_eq(BuildingEconomy.city_queue_state(StringName(PORT)), BuildingEconomy.QUEUE_STATE_MAT)


func test_D110d_queue_state_building_and_done() -> void:
	_boot_min()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._slots_by_port[PORT] = []
	var city: StringName = CashLedger.make_city_id(PORT)
	CashLedger.create_account(city, Account.Kind.CITY)
	var bld := Building.new()
	bld.building_id = &"BLD-C-BUILD"
	bld.type = &"CB-01"
	bld.cb_id = &"CB-01"
	bld.build_class = BuildingEconomy.CLASS_PUBLIC
	bld.owner = city
	bld.port_id = PORT
	bld.level = 1
	bld.state = Building.State.BUILDING
	bld.days_left = 5
	BuildingEconomy._buildings[String(bld.building_id)] = bld
	BuildingEconomy._buildings_by_port[PORT] = [bld]
	BuildingEconomy.set_build_queue(PORT, [_step(PORT, 0, "CB-01", 1), _step(PORT, 1, "CB-02", 1)])
	BuildingEconomy._queue_pos[PORT] = 1
	assert_eq(BuildingEconomy.city_queue_state(StringName(PORT)), BuildingEconomy.QUEUE_STATE_BUILD)
	## Finished queue.
	BuildingEconomy._queue_pos[PORT] = 2
	BuildingEconomy._buildings_by_port[PORT] = []
	assert_eq(BuildingEconomy.city_queue_state(StringName(PORT)), BuildingEconomy.QUEUE_STATE_DONE)


func test_D110d_season_headers_include_queue_and_flows() -> void:
	## Headers only — no full sim boot（Lane B／A fill pf／trader at int）.
	assert_true(SimSampler.HDR_SEASON_PORTS.find("queue_state") >= 0)
	assert_true(SimSampler.HDR_SEASON_PORTS.find("pf1") >= 0)
	assert_true(SimSampler.HDR_SEASON_PORTS.find("unmet_poor_top3") >= 0)
	assert_true(SimSampler.HDR_SEASON_PORTS.find("sat_poor") >= 0)
	assert_true(SimSampler.HDR_SEASON_PORTS.find("job_cap") >= 0)
	assert_true(SimSampler.HDR_SEASON_PORTS.find("city_auto_housing") >= 0)
	assert_true(SimSampler.HDR_SEASON_CELLS.find("excess_consumed") >= 0)
	assert_true(SimSampler.HDR_TRADER_SUMMARY.find("sail_count") >= 0)


func test_D110d_csv_out_writes_new_columns_and_trader_summary() -> void:
	var sampler := SimSampler.new()
	sampler.acc = SimTransferAcc.new()
	sampler.season_ports.append({
		"run_id": 0, "seed": 1, "season_index": 0, "port_id": PORT,
		"rich": 1, "citizen": 2, "poor": 3, "beggar": 0, "sat_weighted": 500,
		"workplaces": 1, "beds": 100, "city_balance_li": 10,
		"queue_position": 0, "land_rent_li": -1, "vacancy_tax_li": -1,
		"city_spend_json": "{}",
		"queue_state": BuildingEconomy.QUEUE_STATE_CASH,
		"sat_poor": 400, "sat_citizen": 500, "sat_rich": 600, "job_cap": 40,
		"cap_sat_up1": 600, "cap_sat_up2": 700,
		"pf1": 0, "pf2": 0, "pf3": 0, "pf4": 0, "pf5": 0, "pf6": 0,
		"unmet_poor_top3": "", "unmet_citizen_top3": "", "unmet_rich_top3": "",
		"city_auto_housing": 0,
	})
	sampler.season_cells.append({
		"run_id": 0, "seed": 1, "season_index": 0, "port_id": PORT, "good_id": "GD-001",
		"stock": 1, "mid_li": 1, "stock_weeks": "1", "band": 0,
		"produced": 0, "consumed": 0, "relocated_in": 0, "relocated_out": 0,
		"excess_consumed": 7,
	})
	sampler.trader_summary_rows.append({
		"run_id": 0, "seed": 1, "season_index": 0, "port_id": PORT,
		"sail_count": 0, "ships_in_port": 0, "frozen_traders": 0,
		"cargo_dan_json": "{}", "avg_daily_margin_li": 0,
	})
	var sid := "lane_c_d110_hdr"
	var written: Dictionary = SimCsvOut.write_all(sid, sampler, [], [], [])
	assert_true(bool(written.get("ok", false)), str(written.get("failed_paths", [])))
	var d: String = SimCsvOut.out_dir(sid)
	var ports_hdr: String = _first_line(d + "season_ports.csv")
	assert_eq(ports_hdr, SimSampler.HDR_SEASON_PORTS)
	var cells_hdr: String = _first_line(d + "season_cells.csv")
	assert_eq(cells_hdr, SimSampler.HDR_SEASON_CELLS)
	var trader_hdr: String = _first_line(d + "trader_summary.csv")
	assert_eq(trader_hdr, SimSampler.HDR_TRADER_SUMMARY)
	var cell_row: String = _second_line(d + "season_cells.csv")
	assert_true(cell_row.ends_with(",7") or cell_row.find(",7\n") >= 0 or cell_row.split(",")[-1] == "7")


func test_D110d_transfer_acc_excess_consumed() -> void:
	var acc := SimTransferAcc.new()
	## Simulate EXCESS_CONSUME without needing GoodsLedger reason const.
	acc._add(acc._excess_consumed, PORT, "GD-001", 11)
	assert_eq(acc.excess_consumed(PORT, "GD-001"), 11)
	assert_eq(acc.consumed(PORT, "GD-001"), 0)


func _boot_min() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)


func _step(port_id: String, step_n: int, cb: String, target: int) -> BuildStep:
	var s := BuildStep.new()
	s.port_id = port_id
	s.step = step_n
	s.cb_id = cb
	s.target_level = target
	return s


func _first_line(path: String) -> String:
	var raw: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = raw.split("\n")
	return String(lines[0]) if lines.size() > 0 else ""


func _second_line(path: String) -> String:
	var raw: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = raw.split("\n")
	return String(lines[1]) if lines.size() > 1 else ""
