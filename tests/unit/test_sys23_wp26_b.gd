extends GutTest
## TD-18: split shard B of test_sys23_wp26.gd (pure file split; test names unchanged).
## WP-26 SYS-23 layer1 — TST-SYS23-01..04, 08..11 (fixtures only).


const CsvImport := preload("res://tools/csv_import.gd")
## G3: ParamsFixtures.path_demo() = baseline + non-zero START_CASH (boot requires genesis_grant).
const PARAMS_FORMAL := "res://data/params/params.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const SEA_CSV := "res://tests/fixtures/wp29_sea_ok/"
const OPENING_CSV := "res://tests/fixtures/sim_loop_opening/"
const DEMAND_CSV_OK := "res://tests/fixtures/demand/ok/"
const DEMAND_OUT := "res://tests/fixtures/demand/out_sys23/"

const GOODS_ROOT := "user://sys23_goods/"
const PORTS_ROOT := "user://sys23_ports/"
const SEA_ROOT := "user://sys23_sea/"

## WP-69／D-114(d): formal dirs read-only; do not wipe／copy fixtures into them.
const FORMAL_ZONES := "res://data/zones/"
const FORMAL_BUILDINGS := "res://data/buildings/"
const FORMAL_OPENING := "res://data/opening/"
const FORMAL_BUILD_QUEUE := "res://data/build_queue/"
const FORMAL_CITY_CENTER := "res://data/city_center/"
const FORMAL_OPENING_PUBLIC := "res://data/opening_public/"
const FORMAL_OPENING_POP := "res://data/opening_population/"

const SCENARIO_UNKNOWN := "res://tests/fixtures/sys23/scenario_bad_unknown_key.json"
const SCENARIO_MISSING := "res://tests/fixtures/sys23/scenario_bad_missing_required.json"
const SCENARIO_CLASH := "res://tests/fixtures/sys23/scenario_bad_override_grid_clash.json"

## FNV vectors (TST-SYS23-08 / FRM-SYS23-10) — same bit-patterns as test_rng_wp25.
const FNV_EMPTY := -3750763034362895579
const FNV_A := -5808556873153909620


func before_each() -> void:
	_wipe_dir(GOODS_ROOT)
	_wipe_dir(PORTS_ROOT)
	_wipe_dir(SEA_ROOT)
	_wipe_dir(DEMAND_OUT)
	# WP-69／D-114(d): never wipe res://data.
	_session_reset()


func test_WP58_A34_write_failure_reports_ok_false() -> void:
	## A34／L10: SimCsvOut.write_all must not return ok:true when a path cannot be written.
	var sampler := SimSampler.new()
	sampler.acc = SimTransferAcc.new()
	## Point scenario_id at a path segment that cannot be a directory write target:
	## create a FILE where the output directory should be.
	var sid := "wp58_a34_block"
	var blocked_dir: String = ProjectSettings.globalize_path(SimCsvOut.out_dir(sid)).trim_suffix("/")
	## Parent user://sim_out must exist; place a file named as the scenario folder.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://sim_out/"))
	## Remove prior dir if present, then create a file at blocked_dir path.
	var abs_blocked: String = blocked_dir
	if DirAccess.dir_exists_absolute(abs_blocked):
		_wipe_dir(SimCsvOut.out_dir(sid))
		DirAccess.remove_absolute(abs_blocked)
	if FileAccess.file_exists(abs_blocked):
		DirAccess.remove_absolute(abs_blocked)
	var blocker := FileAccess.open("user://sim_out/%s" % sid, FileAccess.WRITE)
	assert_ne(blocker, null)
	blocker.store_string("not-a-dir")
	blocker.close()
	## ensure_dir may fail to create nested dir under a file; write_all should report failure.
	var written: Dictionary = SimCsvOut.write_all(sid, sampler, [], [], [])
	print("WP58_A34 write_all=%s" % str(written))
	assert_false(bool(written.get("ok", true)), "A34: ok must be false on write failure")
	assert_gt((written.get("failed_paths", PackedStringArray()) as PackedStringArray).size(), 0)
	## Six CSV writers each push_error once (season_cells/ports/summary/combos/obs_ext＋trader_summary D-110d).
	assert_push_error_count(6)
	## Cleanup blocker file.
	DirAccess.remove_absolute(abs_blocked)


func test_WP26_evidence_bad_triple_all_at_once() -> void:
	## Y3／C-06: missing required + unknown key + type error → all listed (tight asserts).
	var path := "res://tests/fixtures/sys23/scenario_bad_triple.json"
	var r: Dictionary = SimScenarioValidator.validate_file(path)
	assert_false(r["ok"])
	var errs: PackedStringArray = r["errors"]
	print("bad_triple errors (%s):\n%s" % [str(errs.size()), "\n".join(errs)])
	var joined: String = " ".join(errs)
	assert_true(joined.find("ERR-SYS23-02: unknown scenario key 'extra_forbidden'") >= 0, joined)
	assert_true(joined.find("ERR-SYS23-02: missing required key 'warmup_years'") >= 0, joined)
	assert_true(joined.find("ERR-SYS23-03: years must be int") >= 0, joined)


func test_WP26_evidence_ERR_SYS23_01_missing_file() -> void:
	var path := "res://tests/fixtures/sys23/DOES_NOT_EXIST_scenario.json"
	var r: Dictionary = SimScenarioValidator.validate_file(path)
	assert_false(r["ok"])
	print("ERR-01 errors:\n%s" % "\n".join(r["errors"]))
	assert_true(" ".join(r["errors"]).find("ERR-SYS23-01") >= 0)


func test_WP26_evidence_ERR_SYS23_03_type() -> void:
	var r: Dictionary = SimScenarioValidator.validate_file(
		"res://tests/fixtures/sys23/scenario_bad_err03_type.json"
	)
	assert_false(r["ok"])
	print("ERR-03 errors:\n%s" % "\n".join(r["errors"]))
	assert_true(" ".join(r["errors"]).find("ERR-SYS23-03") >= 0)


func test_WP26_evidence_ERR_SYS23_05_unknown_port() -> void:
	var r: Dictionary = SimScenarioValidator.validate_file(
		"res://tests/fixtures/sys23/scenario_bad_err05_unknown_port.json"
	)
	assert_false(r["ok"])
	print("ERR-05 errors:\n%s" % "\n".join(r["errors"]))
	assert_true(" ".join(r["errors"]).find("ERR-SYS23-05") >= 0)


func test_WP26_evidence_ERR_SYS23_06_relocate_f() -> void:
	var r: Dictionary = SimScenarioValidator.validate_file(
		"res://tests/fixtures/sys23/scenario_bad_err06_relocate_f.json"
	)
	assert_false(r["ok"])
	print("ERR-06 errors:\n%s" % "\n".join(r["errors"]))
	assert_true(" ".join(r["errors"]).find("ERR-SYS23-06") >= 0)


func test_WP26_evidence_accounts_after_boot_layer1() -> void:
	## Print all CashLedger accounts; genesis_grant → ACT-PLAYER.
	## Snapshot player balance at first day (post-boot) vs after 1 year.
	## Note: opening player kontor/ship incur mandatory SYS-08/13 charges — balance
	## may fall; arrears stay 0. No voluntary player trade in layer1.
	## end_balance = after years=1 complete (last day of last season); season_index 0..3.
	var scenario: Dictionary = _fast_scenario("sys23_acct_dump")
	scenario["years"] = 1
	scenario["warmup_years"] = 0
	var engine := _make_engine()
	engine.session_reset = _session_reset
	var bal_day1: Array = [-1]
	var arr_day1: Array = [-1]
	var xfer_log: Array = [] ## {season, day, id, delta, reason, balance}
	var player_seen_reasons: Dictionary = {} ## reason -> true when ACT-PLAYER moved
	var on_cash := func(
		id: StringName, new_balance: int, delta: int, reason: StringName
	) -> void:
		var id_s: String = String(id)
		var reason_s: String = String(reason)
		if id_s == String(CashLedger.ACCOUNT_PLAYER):
			player_seen_reasons[reason_s] = true
		## Keep ACT-PLAYER + any account sharing a reason that touched ACT-PLAYER this run,
		## plus SINK／CITY always (counterparties for mandatory charges).
		var keep := (
			id_s == String(CashLedger.ACCOUNT_PLAYER)
			or id_s == String(CashLedger.ID_SINK)
			or id_s.begins_with("CITY-")
			or player_seen_reasons.has(reason_s)
		)
		if not keep:
			return
		var season_i: int = 0
		if Clock.is_loaded():
			var dps: int = Params.get_int("PRM-SYS00-DAYS_PER_SEASON")
			season_i = int((Clock.day - 1) / dps) if Clock.day > 0 else 0
		xfer_log.append({
			"season": season_i,
			"day": Clock.day if Clock.is_loaded() else -1,
			"id": id_s,
			"delta": delta,
			"reason": reason_s,
			"balance": new_balance,
		})
	engine.set_before_day_hook(func(combo_index: int, day: int) -> void:
		if combo_index == 0 and day == 1 and bal_day1[0] < 0:
			if not CashLedger.cash_changed.is_connected(on_cash):
				CashLedger.cash_changed.connect(on_cash)
			bal_day1[0] = CashLedger.balance(CashLedger.ACCOUNT_PLAYER)
			arr_day1[0] = CashLedger.arrears(CashLedger.ACCOUNT_PLAYER)
			print(
				"post_boot_day1 player_balance=%s arrears=%s start_cash=%s"
				% [
					str(bal_day1[0]),
					str(arr_day1[0]),
					str(Params.get_int("PRM-SYS05-START_CASH")),
				]
			)
			print(
				"xfer season=-1 day=0 account=ACT-PLAYER delta_li=%s reason=GENESIS_CASH balance_after=%s counterparty=SOURCE emitting=CashLedger.genesis_grant/PRM-SYS05-START_CASH"
				% [str(bal_day1[0]), str(bal_day1[0])]
			)
	)
	var result: Dictionary = engine.run_scenario_dict(scenario)
	if CashLedger.cash_changed.is_connected(on_cash):
		CashLedger.cash_changed.disconnect(on_cash)
	assert_true(result["ok"])
	assert_eq(int((result["summaries"][0] as Dictionary)["aborted"]), 0)
	var ids: Array = CashLedger._accounts.keys()
	ids.sort()
	print("WP26_ACCOUNTS_BEGIN")
	for id_v in ids:
		var id_s: String = String(id_v)
		var acc: Account = CashLedger._accounts[id_s]
		print(
			"account id=%s kind=%s balance=%s arrears=%s arrears_seasons=%s"
			% [id_s, str(acc.kind), str(acc.balance), str(acc.arrears), str(acc.arrears_seasons)]
		)
	print("WP26_ACCOUNTS_END")
	print("WP26_PLAYER_TRANSFERS_BEGIN")
	for row_v in xfer_log:
		var row: Dictionary = row_v
		print(
			"xfer season=%s day=%s account=%s delta_li=%s reason=%s balance_after=%s"
			% [
				str(row["season"]), str(row["day"]), str(row["id"]),
				str(row["delta"]), str(row["reason"]), str(row["balance"]),
			]
		)
	print("WP26_PLAYER_TRANSFERS_END count=%s" % str(xfer_log.size()))
	var player_bal: int = CashLedger.balance(CashLedger.ACCOUNT_PLAYER)
	var start_cash: int = Params.get_int("PRM-SYS05-START_CASH")
	print(
		"genesis_grant target=%s start_cash=%s day1_balance=%s end_balance=%s end_arrears=%s end_season_note=after_years=1_last_day"
		% [
			String(CashLedger.ACCOUNT_PLAYER),
			str(start_cash),
			str(bal_day1[0]),
			str(player_bal),
			str(CashLedger.arrears(CashLedger.ACCOUNT_PLAYER)),
		]
	)
	## Y2: regression — day-1 genesis, player account present, layer1 ends with arrears 0.
	assert_eq(int(bal_day1[0]), start_cash)
	assert_eq(int(arr_day1[0]), 0)
	assert_true(CashLedger.has_account(CashLedger.ACCOUNT_PLAYER))
	var found_player := false
	for id_v in ids:
		if String(id_v) == String(CashLedger.ACCOUNT_PLAYER):
			found_player = true
			break
	assert_true(found_player, "ACT-PLAYER must appear in account dump")
	assert_eq(CashLedger.arrears(CashLedger.ACCOUNT_PLAYER), 0)
	assert_eq(CashLedger.arrears_seasons(CashLedger.ACCOUNT_PLAYER), 0)
	assert_gt(xfer_log.size(), 0, "layer1 must record at least one cash move (charges／genesis)")


func test_WP26_abort_summary_mets_blank() -> void:
	## Abort path MET-01..05b blank (not 0.0); pass N/A; MET-06 blank when no hits.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var eng := SimEngine.new()
	var s: Dictionary = eng._abort_summary(0, 0, 1, {}, "ERR-SYS23-07: boot failed: []", Time.get_ticks_msec())
	for k in ["MET-01", "MET-02", "MET-03", "MET-04", "MET-05a", "MET-05b", "MET-06"]:
		assert_eq(String(s[k]), "", "abort %s must be blank" % k)
		assert_ne(str(s[k]), "0")
		assert_ne(str(s[k]), "0.0")
	for k in ["MET-01_pass", "MET-02_pass", "MET-03_pass", "MET-04_pass", "MET-05a_pass", "MET-05b_pass", "MET-06_pass"]:
		assert_eq(String(s[k]), SimMetrics.PASS_NA)
	## aggregate: aborted excluded; all-aborted → blanks.
	var rows: Array = SimMetrics.aggregate_combos([s, s])
	assert_eq(rows.size(), 1)
	var row: Dictionary = rows[0]
	print("ABORT_AGGREGATE_ALL_ABORTED %s" % str(row))
	for met_id in ["MET-01", "MET-02", "MET-03", "MET-04", "MET-05a", "MET-05b", "MET-06"]:
		assert_eq(String(row["%s_avg" % met_id]), "")
		assert_eq(String(row["%s_min" % met_id]), "")
		assert_eq(String(row["%s_max" % met_id]), "")
	assert_eq(String(row["combo_pass"]), SimMetrics.PASS_NA)
	## Mixed: one aborted + one alive → avg from alive only.
	var alive: Dictionary = SimMetrics.compute(SimSampler.new(), 0, 1, {}, false, "", 1, 0, 0, 1, {})
	var mix: Array = SimMetrics.aggregate_combos([s, alive])
	print("ABORT_AGGREGATE_MIXED %s" % str(mix[0]))
	assert_eq(float(mix[0]["MET-06_avg"]), float(alive["MET-06"]))
	## CSV integers: run_id/combo_index/seed/aborted have no '.'
	var sid := "sys23_abort_blank"
	var sampler := SimSampler.new()
	SimCsvOut.write_all(sid, sampler, [s], mix, [])
	var sum_text: String = FileAccess.get_file_as_string(SimCsvOut.out_dir(sid) + "summary.csv")
	print("ABORT_SUMMARY_CSV\n%s" % sum_text)
	var cols: PackedStringArray = sum_text.strip_edges().split("\n")[1].split(",")
	## run_id,combo_index,seed,aborted = indices 0,1,2,4
	for idx in [0, 1, 2, 4]:
		assert_eq(String(cols[idx]).find("."), -1, "int col %s has dot: %s" % [str(idx), cols[idx]])


func test_WP26_csv_integer_columns_no_dot() -> void:
	## run_id/combo_index/seed/aborted strings contain no '.'
	var scenario: Dictionary = _fast_scenario("sys23_int_csv")
	scenario["years"] = 1
	scenario["warmup_years"] = 0
	var result: Dictionary = _run_full(scenario)
	assert_true(result["ok"])
	var d: String = SimCsvOut.out_dir(String(scenario["scenario_id"]))
	var sum: String = FileAccess.get_file_as_string(d + "summary.csv")
	var combos: String = FileAccess.get_file_as_string(d + "combos.csv")
	var ports: String = FileAccess.get_file_as_string(d + "season_ports.csv")
	print("INT_CSV_SUMMARY\n%s" % sum)
	print("INT_CSV_COMBOS\n%s" % combos)
	## season_ports first data row int-ish cols
	var plines: PackedStringArray = ports.strip_edges().split("\n")
	print("INT_CSV_SEASON_PORTS_HEADER\n%s" % plines[0])
	if plines.size() > 1:
		print("INT_CSV_SEASON_PORTS_ROW1\n%s" % plines[1])
	var scols: PackedStringArray = sum.strip_edges().split("\n")[1].split(",")
	for idx in [0, 1, 2, 4]:
		assert_eq(String(scols[idx]).find("."), -1, "summary int col dotted: %s" % scols[idx])
	var ccols: PackedStringArray = combos.strip_edges().split("\n")[1].split(",")
	assert_eq(String(ccols[0]).find("."), -1, "combos combo_index dotted")


func test_WP26_evidence_years10_player_arrears() -> void:
	## Temp years=10: season-end ACT-PLAYER balance/arrears/arrears_seasons.
	var scenario: Dictionary = _fast_scenario("sys23_y10")
	scenario["years"] = 10
	scenario["warmup_years"] = 0
	var engine := _make_engine()
	engine.session_reset = _session_reset
	var bankrupt_lim: Array = [-1]
	var season_rows: Array = []
	var hit_zero: Array = [false]
	var hit_bankrupt: Array = [false]
	var on_cutoff := func(season_index: int) -> void:
		## Clock emits season_cutoff AFTER close_season path in SimLoop — sample here.
		var bal: int = CashLedger.balance(CashLedger.ACCOUNT_PLAYER)
		var arr: int = CashLedger.arrears(CashLedger.ACCOUNT_PLAYER)
		var arr_s: int = CashLedger.arrears_seasons(CashLedger.ACCOUNT_PLAYER)
		season_rows.append({
			"season_index": season_index,
			"balance": bal,
			"arrears": arr,
			"arrears_seasons": arr_s,
		})
		print(
			"Y10_SEASON_END season=%s balance=%s arrears=%s arrears_seasons=%s bankrupt_lim=%s"
			% [str(season_index), str(bal), str(arr), str(arr_s), str(bankrupt_lim[0])]
		)
		if bal == 0:
			hit_zero[0] = true
		if bankrupt_lim[0] >= 0 and arr_s >= bankrupt_lim[0]:
			hit_bankrupt[0] = true
	engine.set_before_day_hook(func(combo_index: int, day: int) -> void:
		if combo_index == 0 and day == 1:
			bankrupt_lim[0] = Params.get_int("PRM-SYS05-ARREARS_SEASONS_TO_BANKRUPT")
			if not Clock.season_cutoff.is_connected(on_cutoff):
				Clock.season_cutoff.connect(on_cutoff)
	)
	var result: Dictionary = engine.run_scenario_dict(scenario)
	if Clock.is_loaded() and Clock.season_cutoff.is_connected(on_cutoff):
		Clock.season_cutoff.disconnect(on_cutoff)
	assert_true(result["ok"])
	var summary: Dictionary = result["summaries"][0]
	var seasons_y: int = Params.get_int("PRM-SYS00-SEASONS_PER_YEAR")
	var expect_seasons: int = 10 * seasons_y
	print(
		"Y10_DONE seasons_logged=%s expect=%s hit_zero=%s hit_bankrupt=%s aborted=%s reason=%s MET-06=%s"
		% [
			str(season_rows.size()),
			str(expect_seasons),
			str(hit_zero[0]),
			str(hit_bankrupt[0]),
			str(summary.get("aborted")),
			str(summary.get("abort_reason")),
			str(summary.get("MET-06")),
		]
	)
	print(
		"Y10_BANKRUPTCY_CODE cash_ledger.gd close_season: arrears_seasons >= bankrupt_lim → bankruptcy_referred.emit — no sim abort/ERR-SYS23 (GAP: bankruptcy-unhandled)"
	)
	## Y2: real regression — full 10y season cutoffs logged; layer1 does not abort on bankruptcy_referred.
	assert_eq(season_rows.size(), expect_seasons)
	assert_eq(int(summary.get("aborted")), 0)
	assert_eq(String(summary.get("abort_reason", "")), "")
	## GAP bankruptcy-unhandled: even if arrears hit threshold, SimEngine does not abort.
	if hit_bankrupt[0]:
		assert_eq(int(summary.get("aborted")), 0, "bankruptcy_referred must not abort sim (gap)")


func test_TST_SYS23_09_print_summary_csv() -> void:
	## Companion to TST-09: dump summary.csv full for aborted+ok combo (9.10 ERR-SYS23-07 當日狀態).
	var scenario: Dictionary = _fast_scenario("sys23_tst09_csv")
	scenario["grid"] = {"PRM-SYS05-MIN_CASH_UNIT": [1, 1]}
	scenario["seeds"] = [1]
	var engine := _make_engine()
	engine.session_reset = _session_reset
	engine.set_before_day_hook(func(combo_index: int, day: int) -> void:
		if combo_index == 1 and day == 1 and GoodCatalog.is_loaded() and GoodsLedger.is_loaded():
			var good: StringName = StringName(GoodCatalog.all_ids()[0])
			var key: String = String(
				GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), "PT-01")
			)
			if not GoodsLedger._stock.has(key):
				GoodsLedger._stock[key] = {}
			var bucket: Dictionary = GoodsLedger._stock[key]
			bucket[String(good)] = int(bucket.get(String(good), 0)) + 1
			GoodsLedger._stock[key] = bucket
	)
	var result: Dictionary = engine.run_scenario_dict(scenario)
	assert_true(result["ok"])
	var path: String = SimCsvOut.out_dir(String(scenario["scenario_id"])) + "summary.csv"
	var text: String = FileAccess.get_file_as_string(path)
	print("TST09_SUMMARY_CSV_BEGIN\n%sTST09_SUMMARY_CSV_END" % text)
	print(
		"TST09_ERR07_STATE_NOTE: ERR-SYS23-07 abort_reason lands in summary.abort_reason; season/daily rows sampled before abort remain in CSVs; MET-01..05b blank on aborted row; MET-06=conservation hits"
	)
	## Y2: aborted+ok summaries; CSV carries ERR-SYS23-07 (combo JSON may contain commas).
	var summaries: Array = result["summaries"]
	assert_eq(summaries.size(), 2)
	var aborted_rows := 0
	var ok_rows := 0
	for s_v in summaries:
		var s: Dictionary = s_v
		if int(s["aborted"]) == 1:
			aborted_rows = aborted_rows + 1
			assert_true(String(s["abort_reason"]).find("ERR-SYS23-07") >= 0, str(s["abort_reason"]))
		else:
			ok_rows = ok_rows + 1
	assert_eq(aborted_rows, 1)
	assert_eq(ok_rows, 1)
	assert_eq(text.strip_edges().split("\n").size(), 3, "header + 2 summary rows")
	assert_true(text.find("ERR-SYS23-07") >= 0, text)
	assert_push_error_count(1)


func test_WP26_evidence_cli_twice_cmp() -> void:
	## WP-69: CLI uses committed formal data (no fixture copy into res://data).
	## Params fixture still loaded for scenario overrides; goods／ports／demand = formal.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0, "params_all_keys")
	var scenario: Dictionary = _fast_scenario("sys23_cli_cmp")
	scenario["years"] = 1
	scenario["warmup_years"] = 0
	scenario["daily_detail_ports"] = ["PT-01"]
	var v: Dictionary = SimScenarioValidator.validate_dict(scenario, PortRegistry.PORTS_DIR)
	assert_true(v["ok"], str(v["errors"]))
	var scen_path := "user://sys23_cli_scenario.json"
	var sf := FileAccess.open(scen_path, FileAccess.WRITE)
	sf.store_string(JSON.stringify(v["scenario"]))
	sf.close()
	var scen_abs: String = ProjectSettings.globalize_path(scen_path)
	var exe: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var argv: PackedStringArray = PackedStringArray([
		"--headless", "--path", project_path, "-s", "res://sim/sim_runner.gd",
		"--", "--scenario", scen_abs,
	])
	print("CLI_ARGV: %s %s" % [exe, " ".join(argv)])
	_wipe_dir(SimCsvOut.out_dir("sys23_cli_cmp"))
	var out_a: Array = []
	var rc_a: int = OS.execute(exe, argv, out_a, true, false)
	print("CLI_RUN_A rc=%s\n%s" % [str(rc_a), "\n".join(PackedStringArray(out_a))])
	assert_eq(rc_a, 0)
	var snap_a: Dictionary = _snapshot_outputs_five("sys23_cli_cmp")
	assert_gt(String(snap_a["summary.csv"]).length(), 1)
	## Y3: assert success row aborted=0 (not tautology on header "aborted,").
	var sum_body: String = String(snap_a["summary.csv"])
	assert_true(sum_body.find("boot failed") < 0, "CLI must boot successfully")
	var sum_hdr: PackedStringArray = sum_body.get_slice("\n", 0).split(",")
	var sum_row: PackedStringArray = sum_body.get_slice("\n", 1).split(",")
	var abort_i := -1
	var obs03_i := -1
	for i in range(sum_hdr.size()):
		if String(sum_hdr[i]) == "aborted":
			abort_i = i
		elif String(sum_hdr[i]) == "OBS-03":
			obs03_i = i
	assert_gt(abort_i, -1)
	assert_eq(String(sum_row[abort_i]), "0", "CLI success row must have aborted=0")
	## Must not be an aborted-only empty run: expect season rows.
	assert_gt(String(snap_a["season_cells.csv"]).split("\n").size(), 1)
	assert_gt(obs03_i, -1)
	assert_eq(String(sum_row[obs03_i]), "", "CLI summary OBS-03 must be blank")
	_wipe_dir(SimCsvOut.out_dir("sys23_cli_cmp"))
	var out_b: Array = []
	var rc_b: int = OS.execute(exe, argv, out_b, true, false)
	print("CLI_RUN_B rc=%s\n%s" % [str(rc_b), "\n".join(PackedStringArray(out_b))])
	assert_eq(rc_b, 0)
	var snap_b: Dictionary = _snapshot_outputs_five("sys23_cli_cmp")
	for fname in snap_a.keys():
		var a: String = String(snap_a[fname])
		var b: String = String(snap_b[fname])
		if String(fname) == "summary.csv":
			print("CLI_CMP summary: stripping elapsed_ms column before cmp")
			a = _strip_elapsed(a)
			b = _strip_elapsed(b)
			print("CLI_CMP summary_stripped_a:\n%s" % a)
			print("CLI_CMP summary_stripped_b:\n%s" % b)
		print(
			"CLI_CMP %s equal=%s bytes_a=%s bytes_b=%s"
			% [fname, str(a == b), str(a.length()), str(b.length())]
		)
		assert_eq(a, b, "CLI cmp mismatch %s" % fname)
	print("CLI_CMP all five outputs match (elapsed stripped on summary)")


func test_WP26_layer1_two_years_headers_and_counts() -> void:
	var scenario: Dictionary = _fast_scenario("sys23_l1_2y")
	scenario["daily_detail_ports"] = ["PT-01"]
	var result: Dictionary = _run_full(scenario)
	assert_true(result["ok"])
	_print_output_stats(String(scenario["scenario_id"]))
	var d: String = SimCsvOut.out_dir(String(scenario["scenario_id"]))
	assert_eq(_first_line(d + "season_cells.csv"), SimSampler.HDR_SEASON_CELLS)
	assert_eq(_first_line(d + "season_ports.csv"), SimSampler.HDR_SEASON_PORTS)
	assert_eq(_first_line(d + "summary.csv").substr(0, 10), "run_id,com")
	assert_eq(_first_line(d + "combos.csv").substr(0, 11), "combo_index")
	assert_eq(_first_line(d + "daily_PT-01.csv"), SimSampler.HDR_DAILY)


func test_WP26_json_int_rejects_non_integral() -> void:
	## C-06：非整數 float 不得被 floori 靜默吞；SimJsonInt 報錯並回 0。
	assert_true(SimJsonInt.is_json_int(3))
	assert_true(SimJsonInt.is_json_int(3.0))
	assert_false(SimJsonInt.is_json_int(3.7))
	assert_eq(SimJsonInt.as_int(3.0, "ok_float"), 3)
	assert_eq(SimJsonInt.as_int(3.7, "bad_float"), 0)
	assert_push_error("non-integral rejected for bad_float")
	## grid_expand skips non-integral seeds (no silent floori).
	var jobs: Array = SimGridExpand.expand({}, [1.5])
	assert_eq(jobs.size(), 0)
	assert_push_error("non-integral seed rejected")
	## transfer_acc produced／consumed 走 as_int。
	var acc := SimTransferAcc.new()
	acc._produced["PT-01|GD-001"] = 2.3
	assert_eq(acc.produced("PT-01", "GD-001"), 0)
	assert_push_error("non-integral rejected for produced")
	print("WP26_json_int_rejects_non_integral ok")


func test_WP26_empty_sample_mets_blank_not_zero() -> void:
	## D-52c／9.8：無評估樣本時 MET-01..05b／OBS-02 必須空白，不得寫 0。
	var empty := SimSampler.new()
	var summary: Dictionary = SimMetrics.compute(
		empty, 0, 1, {}, false, "", 1, 0, 0, 1, {}
	)
	print("EMPTY_SAMPLE_SUMMARY %s" % str(summary))
	for k in ["MET-01", "MET-02", "MET-03", "MET-04", "MET-05a", "MET-05b"]:
		assert_eq(String(summary[k]), "", "empty-sample %s must be blank" % k)
		assert_ne(str(summary[k]), "0")
		assert_ne(str(summary[k]), "0.0")
		assert_eq(String(summary["%s_pass" % k]), SimMetrics.PASS_NA)
	## MET-06 hits==0 是實測 0，不是無樣本。
	assert_eq(float(summary["MET-06"]), 0.0)
	assert_eq(String(summary["MET-06_pass"]), "1")
	## OBS-02 無港樣本 → 空白；OBS-03 一律空白。
	assert_eq(String(summary["OBS-02"]), "")
	assert_eq(String(summary["OBS-03"]), "")
	print("WP26_empty_sample_mets_blank_not_zero ok")


# --- helpers ---


func _fast_scenario(scenario_id: String) -> Dictionary:
	## years／warmup from fixture JSON (schema locks DAYS_PER_SEASON＝90; no calendar shrink).
	var meta_raw: String = FileAccess.get_file_as_string(
		"res://tests/fixtures/sys23/scenario_run_meta.json"
	)
	var meta: Dictionary = JSON.parse_string(meta_raw)
	var all_raw: String = FileAccess.get_file_as_string(ParamsFixtures.path_demo())
	var all_params: Dictionary = JSON.parse_string(all_raw)
	return {
		"scenario_id": scenario_id,
		"years": int(meta["years"]),
		"warmup_years": int(meta["warmup_years"]),
		"seeds": meta["seeds"],
		"layers": {"RELOCATE": false},
		"overrides": all_params,
		"grid": {},
		"daily_detail_ports": [],
		"thresholds": {},
	}


func _run_full(scenario: Dictionary) -> Dictionary:
	var engine := _make_engine()
	engine.session_reset = _session_reset
	return engine.run_scenario_dict(scenario)


func _make_engine() -> SimEngine:
	_prepare_world()
	var engine := SimEngine.new()
	engine.params_formal_path = ParamsFixtures.path_demo()
	engine.goods_dir = GOODS_ROOT + "base/"
	engine.ports_dir = PORTS_ROOT + "base/"
	engine.curve_path = CURVE_FIXTURE
	var sea: Dictionary = _install_sea()
	engine.sea_nodes_dir = sea["nodes"]
	engine.sea_regions_dir = sea["regions"]
	engine.sea_lanes_dir = sea["lanes"]
	engine.demand_tables_path = DEMAND_OUT
	return engine


func _prepare_world() -> void:
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0, "params_all_keys")
	_build_goods(GOODS_ROOT + "base/")
	var gerr: Array = GoodCatalog.load_and_validate(GOODS_ROOT + "base/")
	assert_eq(gerr.size(), 0, str(gerr))
	_build_ports(PORTS_ROOT + "base/")
	_install_opening()
	_install_demand()


func _session_reset() -> void:
	## Mirror test_sim_loop reboot helper (private Autoload fields; test-side only).
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.set_consumption_provider(null)
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	DemandModel._clear_state()
	SeaLanes._loaded = false
	ShipRegistry._loaded = false
	## Clear sailor pool so SimLoop can re-inject on next boot.
	if ShipRegistry.has_method("set_sailor_pool_provider"):
		## set_sailor_pool_provider ignored when _loaded; we cleared _loaded above.
		pass


func _install_sea() -> Dictionary:
	var nodes_dir: String = SEA_ROOT + "nodes/"
	var regions_dir: String = SEA_ROOT + "regions/"
	var lanes_dir: String = SEA_ROOT + "lanes/"
	_wipe_dir(nodes_dir)
	_wipe_dir(regions_dir)
	_wipe_dir(lanes_dir)
	var result: Dictionary = CsvImport.run_batch_wp29(SEA_CSV, nodes_dir, regions_dir, lanes_dir)
	assert_true(result["ok"], str(result.get("errors", [])))
	return {"nodes": nodes_dir, "regions": regions_dir, "lanes": lanes_dir}


func _install_opening() -> void:
	## WP-69／D-114(d): no-op — SimEngine／SimLoop.boot use committed formal opening.
	pass


func _install_demand() -> void:
	## Scales from Params (C-03); Params already loaded in _prepare_world.
	var rate_scale: int = Params.get_int("PRM-SYS06-RATE_SCALE")
	var ppm_scale: int = Params.get_int("PRM-SYS06-PPM_SCALE")
	var weight_sum: int = Params.get_int("PRM-SYS06-WEIGHT_SUM")
	var result: Dictionary = CsvImport.run_batch_demand(
		DEMAND_CSV_OK,
		DEMAND_OUT.path_join("rates/"),
		DEMAND_OUT.path_join("weights/"),
		DEMAND_OUT.path_join("substitutions/"),
		rate_scale,
		ppm_scale,
		weight_sum
	)
	assert_true(result["ok"], str(result.get("errors", [])))


func _build_goods(dir: String) -> void:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	## WP-69: match committed formal good count so BE opening workshops resolve.
	var count: int = maxi(Params.get_int("PRM-SYS01-GOOD_COUNT_MIN"), _count_formal_goods())
	var staples: Array = [
		{"id": "GD-001", "name": "米", "build": false},
		{"id": "GD-002", "name": "鹽", "build": false},
		{"id": "GD-003", "name": "木材", "build": true},
		{"id": "GD-004", "name": "魚乾", "build": false},
	]
	var written: int = 0
	for s in staples:
		ResourceSaver.save(_make_good(s["id"], s["name"], 1, true, s["build"]), dir + "%s.tres" % s["id"])
		written += 1
	var n: int = 5
	while written < count:
		var gid := "GD-%03d" % n
		ResourceSaver.save(_make_good(gid, "填料%d" % n, 1, false, false), dir + "%s.tres" % gid)
		written += 1
		n += 1


func _build_ports(dir: String) -> void:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var port_count: int = Params.get_int("PRM-SYS02-PORT_COUNT_MAX")
	var free_count: int = _valid_free_count(port_count)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	for i in range(port_count):
		var n: int = i + 1
		var port_id := "PT-%02d" % n
		var def := PortDef.new()
		def.port_id = port_id
		def.name_zh = "港%d" % n
		def.is_free_port = i < free_count
		def.draft_limit_class = 0
		def.regime_id = "RG-TEST"
		def.role_cells = {}
		for g_v in good_ids:
			var cell := RoleCell.new()
			cell.role = PortRegistry.ROLE_TERMINAL
			cell.base_output_per_season = 0
			if i == 0:
				cell.role = PortRegistry.ROLE_PRODUCER
				cell.base_output_per_season = 1
			def.role_cells[String(g_v)] = cell
		ResourceSaver.save(def, dir + "%s.tres" % port_id)


func _make_good(id: String, name_zh: String, tier: int, staple: bool, build: bool) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = staple
	def.is_build_material = build
	def.is_strategic = false
	def.base_price_li = 1000
	def.season_mask = (1 << Params.get_int("PRM-SYS00-SEASONS_PER_YEAR")) - 1
	return def


func _valid_free_count(port_count: int) -> int:
	var ratio_min: float = Params.get_float("PRM-SYS02-FREE_PORT_RATIO_MIN")
	var ratio_max: float = Params.get_float("PRM-SYS02-FREE_PORT_RATIO_MAX")
	var free_count: int = 0
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return free_count
		free_count += 1
	return 0


func _snapshot_outputs(scenario_id: String) -> Dictionary:
	var d: String = SimCsvOut.out_dir(scenario_id)
	var out := {}
	for fname in ["season_cells.csv", "season_ports.csv", "summary.csv", "combos.csv"]:
		var p: String = d + fname
		if FileAccess.file_exists(p):
			out[fname] = FileAccess.get_file_as_string(p)
	return out


func _snapshot_outputs_five(scenario_id: String) -> Dictionary:
	var d: String = SimCsvOut.out_dir(scenario_id)
	var out := {}
	for fname in [
		"season_cells.csv", "season_ports.csv", "summary.csv", "combos.csv", "daily_PT-01.csv"
	]:
		var p: String = d + fname
		assert_true(FileAccess.file_exists(p), "missing output %s" % p)
		out[fname] = FileAccess.get_file_as_string(p)
	return out


func _install_formal_from_fixtures() -> void:
	## WP-69／D-114(d): deleted — CLI／formal boot use committed res://data (no fixture copy-in).
	pass


func _strip_elapsed(summary_csv: String) -> String:
	var lines: PackedStringArray = summary_csv.strip_edges().split("\n")
	var out: PackedStringArray = PackedStringArray()
	for i in range(lines.size()):
		var line: String = String(lines[i])
		if i == 0:
			out.append(line)
			continue
		var parts: PackedStringArray = line.split(",")
		if parts.size() > 0:
			## Drop last column elapsed_ms.
			var kept: PackedStringArray = PackedStringArray()
			for j in range(parts.size() - 1):
				kept.append(parts[j])
			out.append(",".join(kept))
	return "\n".join(out)


func _print_output_stats(scenario_id: String) -> void:
	var d: String = SimCsvOut.out_dir(scenario_id)
	for fname in [
		"season_cells.csv", "season_ports.csv", "summary.csv", "combos.csv", "daily_PT-01.csv"
	]:
		var p: String = d + fname
		if not FileAccess.file_exists(p):
			print("%s: (missing)" % fname)
			continue
		var text: String = FileAccess.get_file_as_string(p)
		var lines: PackedStringArray = text.strip_edges().split("\n")
		print("%s header=%s rows=%s" % [fname, lines[0], str(lines.size())])


func _first_line(path: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	return String(text.split("\n")[0])


func _wipe_formal_opening() -> void:
	## WP-69／D-114(d): deleted wipe of res://data opening trees.
	pass


func _wipe_formal_demand() -> void:
	## WP-69／D-114(d): deleted wipe of res://data/demand.
	pass


func _count_formal_goods() -> int:
	## Read-only count of committed res://data/goods/*.tres (WP-69; no writes).
	var n := 0
	var d := DirAccess.open(GoodCatalog.GOODS_DIR)
	if d == null:
		return 0
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".tres"):
			n += 1
		fn = d.get_next()
	d.list_dir_end()
	return n


func _wipe_dir(dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if d.current_is_dir():
			if fn != "." and fn != "..":
				_wipe_dir(dir.path_join(fn))
		else:
			d.remove(fn)
		fn = d.get_next()
	d.list_dir_end()
