class_name SimEngine
extends RefCounted
## SYS-23 runner core (WP-26 layer-1; WP-27 layer-2 RELOCATE). Does not touch autoload
## private state; caller supplies session_reset Callable between combos (tests／CLI).


const ERR_SYS23_03 := "ERR-SYS23-03"
const ERR_SYS23_07 := "ERR-SYS23-07"
const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_PPM_SCALE := "PRM-SYS06-PPM_SCALE"
const PRM_ROUND_EPS := "PRM-SYS04-ROUND_EPS"
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
## R9-54 Y5 formal inject (WP-59): optional hook (combo_index, day) before each tick_day.
## Prefer set_before_day_hook／clear_before_day_hook over writing the field.
## WP-58 Y1 still injects TradeDesk day errors into the buffer drained by public
## take_day_errors (SimLoop step 6); do not reintroduce private _day_errors writes
## when a public inject path exists.
var _before_day: Callable = Callable()


func set_before_day_hook(hook: Callable) -> void:
	## R9-54 Y5: formal test／CLI inject before each day tick.
	_before_day = hook


func clear_before_day_hook() -> void:
	_before_day = Callable()


func run_scenario_dict(scenario: Dictionary) -> Dictionary:
	## scenario must already be validated／normalized.
	## Returns {ok, errors, summaries, combo_rows, sampler, out}.
	var errors: PackedStringArray = PackedStringArray()

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
			all_sampler.obs_ext_rows.append_array(sm.obs_ext_rows)
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
	## A34: write failure → ok false (do not claim success with incomplete CSV).
	var write_ok: bool = bool(written.get("ok", false))
	if not write_ok:
		errors.append("SimCsvOut.write_all failed: %s" % str(written.get("failed_paths", [])))
	return {
		"ok": write_ok,
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

	var relocate_on: bool = bool(
		(scenario.get("layers", {}) as Dictionary).get("RELOCATE", false)
	)
	var f_ppm: int = 0
	## FRM-SYS23-05: enable SIM_RELOCATE before boot when layer 2 on (survives load_and_validate).
	GoodsLedger.set_sim_relocate_enabled(relocate_on)

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
		GoodsLedger.set_sim_relocate_enabled(false)
		var reason: String = "%s: boot failed: %s" % [ERR_SYS23_07, str(boot_errors)]
		return {
			"summary": _abort_summary(run_id, combo_index, seed, combo, reason, t0),
			"sampler": sampler,
		}

	if relocate_on:
		var conv: Dictionary = SimRelocator.f_to_ppm(
			float(scenario[SimScenarioValidator.KEY_RELOCATE_F]),
			Params.get_int(PRM_PPM_SCALE),
			Params.get_float(PRM_ROUND_EPS)
		)
		if not bool(conv.get("ok", false)):
			acc.disconnect_ledger()
			GoodsLedger.set_sim_relocate_enabled(false)
			return {
				"summary": _abort_summary(
					run_id, combo_index, seed, combo, String(conv.get("error", ERR_SYS23_03)), t0
				),
				"sampler": sampler,
			}
		f_ppm = int(conv["f_ppm"])

	PopulationModel.set_master_seed(seed)
	Clock.set_paused(false)

	var years: int = SimScenarioValidator.as_int(scenario[SimScenarioValidator.KEY_YEARS])
	var days_per_season: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var seasons_y: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	var total_days: int = years * seasons_y * days_per_season
	var ppm_scale: int = Params.get_int(PRM_PPM_SCALE)

	## Holder so day_ticked lambda can flag abort (GDScript closure).
	var run_state := {"aborted": false, "abort_reason": ""}
	## FRM-SYS23-04: relocate on day_ticked (before season_cutoff sample in same step 6).
	var on_day := func(_day: int) -> void:
		if bool(run_state["aborted"]) or not relocate_on:
			return
		var rr: Dictionary = SimRelocator.run_day(f_ppm, ppm_scale, acc)
		if not bool(rr.get("ok", false)):
			run_state["aborted"] = true
			run_state["abort_reason"] = String(rr.get("error", ERR_SYS23_07))
	## FRM-SYS23-06: sample after season_cutoff is emitted (SimLoop step 6).
	var on_cutoff := func(season_index: int) -> void:
		sampler.sample_season(run_id, seed, season_index)
	if not Clock.day_ticked.is_connected(on_day):
		Clock.day_ticked.connect(on_day)
	if not Clock.season_cutoff.is_connected(on_cutoff):
		Clock.season_cutoff.connect(on_cutoff)

	for day_i in range(total_days):
		var day_num: int = day_i + 1 ## first advance yields day=1
		if _before_day.is_valid():
			_before_day.call(combo_index, day_num)
		## A31／H8／ERR-SYS23-07: collect tick_day errors; do not discard.
		var day_errors: Array = SimLoop.tick_day()
		if bool(run_state["aborted"]):
			break
		if sampler.conservation_hits > 0:
			run_state["aborted"] = true
			run_state["abort_reason"] = "%s: conservation violated" % ERR_SYS23_07
			break
		## G／ERR-SYS23-07: any system ERR aborts this combo (WRN does not).
		var fatal: Array = _fatal_day_errors(day_errors)
		if not fatal.is_empty():
			run_state["aborted"] = true
			run_state["abort_reason"] = "%s: day_errors: %s" % [
				ERR_SYS23_07, _format_day_errors(fatal)
			]
			break
		## Daily detail after day's writes／signals (includes same-day relocate).
		for pid_v in daily_ports:
			sampler.sample_daily(run_id, seed, Clock.day, String(pid_v))

	if Clock.day_ticked.is_connected(on_day):
		Clock.day_ticked.disconnect(on_day)
	if Clock.season_cutoff.is_connected(on_cutoff):
		Clock.season_cutoff.disconnect(on_cutoff)
	acc.disconnect_ledger()
	if GoodsLedger.conservation_violated.is_connected(sampler.on_conservation):
		GoodsLedger.conservation_violated.disconnect(sampler.on_conservation)
	GoodsLedger.set_sim_relocate_enabled(false)

	var elapsed: int = Time.get_ticks_msec() - t0
	var sid: String = String(scenario.get(SimScenarioValidator.KEY_SCENARIO_ID, ""))
	var aborted: bool = bool(run_state["aborted"])
	var abort_reason: String = String(run_state["abort_reason"])
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
		combo,
		sid
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


static func _fatal_day_errors(day_errors: Array) -> Array:
	## Severity gate (WP-58 A31): ERR-* aborts; empty／WRN-* continue.
	var fatal: Array = []
	for err_v in day_errors:
		if typeof(err_v) != TYPE_DICTIONARY:
			fatal.append(err_v)
			continue
		var err: Dictionary = err_v
		var code: String = String(err.get(ErrorInfoUtil.KEY_CODE, err.get("code", "")))
		if code.is_empty() or code.begins_with("ERR-"):
			fatal.append(err)
	return fatal


static func _format_day_errors(fatal: Array) -> String:
	## Compact abort_reason payload for summary.csv (ERR-SYS23-07).
	var parts: PackedStringArray = PackedStringArray()
	for err_v in fatal:
		if typeof(err_v) != TYPE_DICTIONARY:
			parts.append(str(err_v))
			continue
		var err: Dictionary = err_v
		var code: String = String(err.get(ErrorInfoUtil.KEY_CODE, err.get("code", "")))
		var detail: Variant = err.get(ErrorInfoUtil.KEY_DETAIL, err.get("detail", {}))
		var msg: String = ""
		if typeof(detail) == TYPE_DICTIONARY:
			msg = String((detail as Dictionary).get(ErrorInfoUtil.DETAIL_MESSAGE, ""))
		if msg.is_empty():
			parts.append(code if not code.is_empty() else str(err))
		else:
			parts.append("%s (%s)" % [code, msg])
	return "; ".join(parts)
