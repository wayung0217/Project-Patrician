class_name SimEngine
extends RefCounted
## SYS-23 layer-1 runner core (WP-26). No RELOCATE. Does not touch autoload private state;
## caller supplies session_reset Callable between combos (tests／CLI).


const ERR_SYS23_07 := "ERR-SYS23-07"
const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const MERGED_PARAMS_DIR := "user://sim_merged/"

## Boot path bundle (formal defaults; tests override with fixtures).
var params_formal_path: String = SimParamsMerge.FORMAL_PARAMS_PATH
var goods_dir: String = GoodCatalog.GOODS_DIR
var ports_dir: String = PortRegistry.PORTS_DIR
var curve_path: String = MarketPricer.CURVE_PATH
var sea_nodes_dir: String = SeaLanes.NODES_DIR
var sea_regions_dir: String = SeaLanes.REGIONS_DIR
var sea_lanes_dir: String = SeaLanes.LANES_DIR
var demand_tables_path: String = DemandModel.TABLES_PATH

## Optional: called before each combo boot to clear Autoload session (must not live in sim/).
var session_reset: Callable = Callable()
## Optional test hook: called as (combo_index, day) before each tick_day.
var before_day: Callable = Callable()


func run_scenario_dict(scenario: Dictionary) -> Dictionary:
	## scenario must already be validated／normalized.
	## Returns {ok, errors, summaries, combo_rows, sampler, out}.
	var errors: PackedStringArray = PackedStringArray()
	if bool((scenario.get("layers", {}) as Dictionary).get("RELOCATE", false)):
		errors.append("WP-26 layer1: layers.RELOCATE must be false (WP-27)")
		return {"ok": false, "errors": errors}

	var seeds: Array = scenario[SimScenarioValidator.KEY_SEEDS]
	var grid: Dictionary = scenario[SimScenarioValidator.KEY_GRID]
	var overrides: Dictionary = scenario[SimScenarioValidator.KEY_OVERRIDES]
	var jobs: Array = SimGridExpand.expand(grid, seeds)
	## Print combo count (紅隊-42 visibility).
	print(
		"sim_engine: combos=%s seeds=%s jobs=%s"
		% [str(_combo_count(grid)), str(seeds.size()), str(jobs.size())]
	)

	var summaries: Array = []
	## Aggregate season samples across all runs into one sampler for CSV write.
	var all_sampler := SimSampler.new()
	all_sampler.acc = SimTransferAcc.new()
	var daily_ports: Array = scenario[SimScenarioValidator.KEY_DAILY_PORTS]

	for job_v in jobs:
		var job: Dictionary = job_v
		if session_reset.is_valid():
			session_reset.call()
		var one: Dictionary = _run_one_job(scenario, job, overrides, daily_ports)
		if one.has("summary"):
			summaries.append(one["summary"])
		## Merge sampled rows into all_sampler for combined CSV.
		if one.has("sampler"):
			var sm: SimSampler = one["sampler"]
			all_sampler.season_cells.append_array(sm.season_cells)
			all_sampler.season_ports.append_array(sm.season_ports)
			for pid_v in sm.daily_rows.keys():
				var pid: String = String(pid_v)
				if not all_sampler.daily_rows.has(pid):
					all_sampler.daily_rows[pid] = []
				(all_sampler.daily_rows[pid] as Array).append_array(sm.daily_rows[pid])

	var combo_rows: Array = SimMetrics.aggregate_combos(summaries)
	var sid: String = String(scenario[SimScenarioValidator.KEY_SCENARIO_ID])
	var written: Dictionary = SimCsvOut.write_all(
		sid, all_sampler, summaries, combo_rows, daily_ports
	)
	return {
		"ok": true,
		"errors": errors,
		"summaries": summaries,
		"combo_rows": combo_rows,
		"sampler": all_sampler,
		"out": written,
		"jobs": jobs,
	}


func run_one_job(
	scenario: Dictionary, job: Dictionary, overrides: Dictionary, daily_ports: Array
) -> Dictionary:
	return _run_one_job(scenario, job, overrides, daily_ports)


func _run_one_job(
	scenario: Dictionary, job: Dictionary, overrides: Dictionary, daily_ports: Array
) -> Dictionary:
	## 乙：job 可能經 JSON roundtrip（CLI 子行程）→ floori 還原整數。
	var run_id: int = _job_int(job["run_id"])
	var combo_index: int = _job_int(job["combo_index"])
	var seed: int = _job_int(job["seed"])
	var combo: Dictionary = job["combo"]
	var t0: int = Time.get_ticks_msec()

	var merged_path: String = "%srun_%d.json" % [MERGED_PARAMS_DIR, run_id]
	var merge_res: Dictionary = SimParamsMerge.merge_to_user(
		params_formal_path, overrides, combo, merged_path
	)
	if not bool(merge_res["ok"]):
		return {
			"summary": _abort_summary(
				run_id, combo_index, seed, combo, str(merge_res["errors"]), t0
			)
		}

	var sampler := SimSampler.new()
	var acc := SimTransferAcc.new()
	sampler.acc = acc
	acc.connect_ledger()
	if not GoodsLedger.conservation_violated.is_connected(sampler.on_conservation):
		GoodsLedger.conservation_violated.connect(sampler.on_conservation)

	# D-60f／D-63b: sim expects successful boot → inject deny-all fixtures（not formal always-allow）.
	if not IntelLedger.has_broker_provider():
		IntelLedger.set_broker_provider(SimBrokerFixture.new())
	# Allow re-inject after a prior boot left TradeDesk._loaded true without providers.
	if not TradeDesk.has_qualification_provider() or not TradeDesk.has_trade_observers():
		TradeDesk.mark_unloaded()
	if not TradeDesk.has_qualification_provider():
		TradeDesk.set_qualification_provider(SimQualificationFixture.new())
	if not TradeDesk.has_trade_observers():
		TradeDesk.set_trade_observers([SimTradeObserverFixture.new()])
	var boot_errors: Array = SimLoop.boot(
		String(merge_res["path"]),
		goods_dir,
		ports_dir,
		curve_path,
		sea_nodes_dir,
		sea_regions_dir,
		sea_lanes_dir,
		demand_tables_path
	)
	if not boot_errors.is_empty() or not SimLoop.is_booted():
		acc.disconnect_ledger()
		var reason: String = "%s: boot failed: %s" % [ERR_SYS23_07, str(boot_errors)]
		return {
			"summary": _abort_summary(run_id, combo_index, seed, combo, reason, t0),
			"sampler": sampler,
		}

	PopulationModel.set_master_seed(seed)
	Clock.set_paused(false)

	var years: int = SimScenarioValidator.as_int(scenario[SimScenarioValidator.KEY_YEARS])
	var days_per_season: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var seasons_y: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	var total_days: int = years * seasons_y * days_per_season

	var aborted := false
	var abort_reason := ""
	## FRM-SYS23-06: sample after season_cutoff is emitted (SimLoop step 6).
	var on_cutoff := func(season_index: int) -> void:
		sampler.sample_season(run_id, seed, season_index)
	if not Clock.season_cutoff.is_connected(on_cutoff):
		Clock.season_cutoff.connect(on_cutoff)

	for day_i in range(total_days):
		var day_num: int = day_i + 1 ## first advance yields day=1
		if before_day.is_valid():
			before_day.call(combo_index, day_num)
		var _day_errors: Array = SimLoop.tick_day()
		if sampler.conservation_hits > 0:
			aborted = true
			abort_reason = "%s: conservation violated" % ERR_SYS23_07
			break
		## Daily detail after day's writes／signals.
		for pid_v in daily_ports:
			sampler.sample_daily(run_id, seed, Clock.day, String(pid_v))

	if Clock.season_cutoff.is_connected(on_cutoff):
		Clock.season_cutoff.disconnect(on_cutoff)
	acc.disconnect_ledger()
	if GoodsLedger.conservation_violated.is_connected(sampler.on_conservation):
		GoodsLedger.conservation_violated.disconnect(sampler.on_conservation)

	var elapsed: int = Time.get_ticks_msec() - t0
	var summary: Dictionary = SimMetrics.compute(
		sampler,
		SimScenarioValidator.as_int(scenario[SimScenarioValidator.KEY_WARMUP]),
		years,
		scenario[SimScenarioValidator.KEY_THRESHOLDS],
		aborted,
		abort_reason,
		elapsed,
		run_id,
		combo_index,
		seed,
		combo
	)
	return {"summary": summary, "sampler": sampler}


func _abort_summary(
	run_id: int, combo_index: int, seed: int, combo: Dictionary, reason: String, t0: int
) -> Dictionary:
	## No-value MET → blank (not 0.0). MET-06 blank when no measured conservation hits.
	return {
		"run_id": run_id,
		"combo_index": combo_index,
		"seed": seed,
		"combo": JSON.stringify(combo),
		"aborted": 1,
		"abort_reason": reason,
		"MET-01": "",
		"MET-01_pass": SimMetrics.PASS_NA,
		"MET-02": "",
		"MET-02_pass": SimMetrics.PASS_NA,
		"MET-03": "",
		"MET-03_pass": SimMetrics.PASS_NA,
		"MET-04": "",
		"MET-04_pass": SimMetrics.PASS_NA,
		"MET-05a": "",
		"MET-05a_pass": SimMetrics.PASS_NA,
		"MET-05b": "",
		"MET-05b_pass": SimMetrics.PASS_NA,
		"MET-06": "",
		"MET-06_pass": SimMetrics.PASS_NA,
		"OBS-01": "",
		"OBS-02": "",
		"OBS-03": "",
		"elapsed_ms": Time.get_ticks_msec() - t0,
	}


func _combo_count(grid: Dictionary) -> int:
	if grid.is_empty():
		return 1
	var n: int = 1
	for k_v in grid.keys():
		n = n * (grid[k_v] as Array).size()
	return n


static func _job_int(v: Variant) -> int:
	## C-06：JSON／Variant 整數還原；非整數報錯（不靜默 floori）。
	return SimJsonInt.as_int(v, "job_int")
