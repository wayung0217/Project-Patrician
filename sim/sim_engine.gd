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
## 17-59／17-60 W5: print-only season progress (no state change; golden identical).
var print_season_progress: bool = false
## 17-85 B: print-only per-day progress (default off; no Time.*／sampler／ledger).
var print_day_progress: bool = false
## Wall-clock start for ETA lines (set at job start).
var _progress_t0_msec: int = 0


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
			all_sampler.trader_summary_rows.append_array(sm.trader_summary_rows)
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
	sampler.connect_unmet()
	if not GoodsLedger.conservation_violated.is_connected(sampler.on_conservation):
		GoodsLedger.conservation_violated.connect(sampler.on_conservation)

	var layers: Dictionary = scenario.get("layers", {}) as Dictionary
	var relocate_on: bool = bool(layers.get("RELOCATE", false))
	var f_ppm: int = 0
	## D-97(b): layers.RELOCATE is the only switch; no GoodsLedger enable API.

	## F1／D-120(b)①: TRADERS／QUAL_OPEN before SimLoop.boot (TraderRegistry.load gates on is_enabled).
	var traders_on: bool = bool(layers.get(SimScenarioValidator.KEY_TRADERS, false))
	var qual_open: bool = bool(layers.get(SimScenarioValidator.KEY_QUAL_OPEN, false))
	TraderRegistry.set_layers(traders_on, qual_open)
	## F3／FRM-SYS23-03／FRM-SYS17-04: explore seed = scenario seed (no module-fixed seed).
	TraderRegistry.set_rng_seed(seed)
	## 17-63 Z2: gated diagnosis (env M1B_DIAG_Z=1); no behaviour change when off.
	var diag_z := M1bDiagZ.new()
	diag_z.begin_from_env()
	TraderRegistry.set_diag_z(diag_z if diag_z.is_active() else null)

	# D-60f／D-63b: sim expects successful boot → inject fixtures（not formal always-allow）.
	# D-120(f): QUAL_OPEN＝1 → SimQualificationOpenFixture (sim/ only); else deny-all.
	if not IntelLedger.has_broker_provider():
		IntelLedger.set_broker_provider(SimBrokerFixture.new())
	# Allow re-inject after a prior boot left TradeDesk._loaded true without providers.
	if not TradeDesk.has_qualification_provider() or not TradeDesk.has_trade_observers():
		TradeDesk.mark_unloaded()
	var qual_fixture_name := "SimQualificationFixture"
	if not TradeDesk.has_qualification_provider():
		if qual_open:
			TradeDesk.set_qualification_provider(SimQualificationOpenFixture.new())
			qual_fixture_name = "SimQualificationOpenFixture"
		else:
			TradeDesk.set_qualification_provider(SimQualificationFixture.new())
			qual_fixture_name = "SimQualificationFixture"
	elif TradeDesk.has_qualification_provider():
		## Already injected (tests); name best-effort from get_class if available.
		qual_fixture_name = "preinjected"
	diag_z.record_boot(traders_on, qual_open, qual_fixture_name)
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
		diag_z.record_roster_after_boot()
		diag_z.finish()
		TraderRegistry.set_diag_z(null)
		acc.disconnect_ledger()
		sampler.disconnect_unmet()
		var reason: String = "%s: boot failed: %s" % [ERR_SYS23_07, str(boot_errors)]
		return {
			"summary": _abort_summary(run_id, combo_index, seed, combo, reason, t0),
			"sampler": sampler,
		}
	diag_z.record_roster_after_boot()

	## D-115(a)／WP-68: layers.CITY_HOUSING → BuildingEconomy（default off）.
	var city_housing: bool = bool(layers.get(SimScenarioValidator.KEY_CITY_HOUSING, false))
	if BuildingEconomy.has_method("set_city_housing_layer"):
		BuildingEconomy.set_city_housing_layer(city_housing)

	## FRM-SYS07-18／D-109(g): layers.CLASS_CAP → PopulationModel（default off）.
	## Owner 2026-11-26: after set, assert effective == requested; mismatch → refuse run.
	var class_cap_requested: bool = bool(layers.get(SimScenarioValidator.KEY_CLASS_CAP, false))
	if PopulationModel.has_method("set_class_cap_layer"):
		PopulationModel.set_class_cap_layer(class_cap_requested)
	var class_cap_effective: bool = (
		PopulationModel.is_class_cap_on() if PopulationModel.has_method("is_class_cap_on") else false
	)
	## Diagnosis records 生效 state（not the request bit）.
	diag_z.record_class_cap_effective(class_cap_effective)
	if class_cap_effective != class_cap_requested:
		diag_z.finish()
		TraderRegistry.set_diag_z(null)
		acc.disconnect_ledger()
		sampler.disconnect_unmet()
		var cap_err: Dictionary = PopulationModel.last_error()
		var cap_detail: Dictionary = cap_err.get("detail", {}) as Dictionary
		var cap_msg: String = str(cap_detail.get("message", "CLASS_CAP effective != requested"))
		var cap_code: String = String(cap_err.get("code", "ERR-SYS07-10"))
		var cap_reason: String = (
			"%s: CLASS_CAP effective=%s requested=%s — %s"
			% [cap_code, str(class_cap_effective), str(class_cap_requested), cap_msg]
		)
		return {
			"summary": _abort_summary(run_id, combo_index, seed, combo, cap_reason, t0),
			"sampler": sampler,
		}

	if relocate_on:
		var conv: Dictionary = SimRelocator.f_to_ppm(
			float(scenario[SimScenarioValidator.KEY_RELOCATE_F]),
			Params.get_int(PRM_PPM_SCALE),
			Params.get_float(PRM_ROUND_EPS)
		)
		if not bool(conv.get("ok", false)):
			diag_z.finish()
			TraderRegistry.set_diag_z(null)
			acc.disconnect_ledger()
			sampler.disconnect_unmet()
			return {
				"summary": _abort_summary(
					run_id, combo_index, seed, combo, String(conv.get("error", ERR_SYS23_03)), t0
				),
				"sampler": sampler,
			}
		f_ppm = SimJsonInt.as_int(conv["f_ppm"], "f_ppm")

	PopulationModel.set_master_seed(seed)
	Clock.set_paused(false)

	var years: int = SimScenarioValidator.as_int(scenario[SimScenarioValidator.KEY_YEARS])
	var days_per_season: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var seasons_y: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	var total_days: int = years * seasons_y * days_per_season
	## 17-59 SmokeDays / --days: optional absolute day cap (metrics still use years).
	if scenario.has("days_override"):
		var d_ov: int = SimJsonInt.as_int(scenario["days_override"], "days_override")
		if d_ov >= 1:
			total_days = d_ov
	var ppm_scale: int = Params.get_int(PRM_PPM_SCALE)
	_progress_t0_msec = Time.get_ticks_msec()

	## R9-65 B1／C-04／2.3-06: no Clock.day_ticked lambda for relocate.
	## Daily step after SimLoop.tick_day (signals already flushed／emitted inside tick_day).
	var run_state := {"aborted": false, "abort_reason": ""}
	## FRM-SYS23-06: sample after season_cutoff is emitted (SimLoop step 6).
	var on_cutoff := func(season_index: int) -> void:
		sampler.sample_season(run_id, seed, season_index)
		if print_season_progress:
			_emit_season_progress(season_index, total_days, days_per_season, seasons_y, sampler)
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
		## Explicit SimEngine daily relocate step (after tick_day; R9-65 B1).
		if relocate_on and not bool(run_state["aborted"]):
			var rr: Dictionary = SimRelocator.run_day(f_ppm, ppm_scale, acc)
			if not bool(rr.get("ok", false)):
				run_state["aborted"] = true
				run_state["abort_reason"] = String(rr.get("error", ERR_SYS23_07))
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
		## Daily detail after day's writes／signals／relocate.
		for pid_v in daily_ports:
			sampler.sample_daily(run_id, seed, Clock.day, String(pid_v))
		## 17-85 B: after day's writes／signals／relocate／sample_daily — day+total only.
		if print_day_progress and not bool(run_state["aborted"]):
			_emit_day_progress(int(Clock.day), total_days)

	if Clock.season_cutoff.is_connected(on_cutoff):
		Clock.season_cutoff.disconnect(on_cutoff)
	## SmokeDays < one season never hits season_cutoff — still emit one ASCII PROGRESS.
	if print_season_progress:
		var si_final: int = int(Clock.season_index) if Clock != null else 0
		_emit_season_progress(si_final, total_days, days_per_season, seasons_y, sampler)
	diag_z.finish()
	TraderRegistry.set_diag_z(null)
	acc.disconnect_ledger()
	sampler.disconnect_unmet()
	if GoodsLedger.conservation_violated.is_connected(sampler.on_conservation):
		GoodsLedger.conservation_violated.disconnect(sampler.on_conservation)

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


func _emit_day_progress(day: int, total_days: int) -> void:
	## Print-only (17-85 B). ASCII for PS 5.1. day + total only — no Time.*／pop／ledger.
	## Format: DAY_PROGRESS day=<n> total=<N>
	print("DAY_PROGRESS day=%d total=%d" % [day, total_days])


func _emit_season_progress(
	season_index: int,
	total_days: int,
	days_per_season: int,
	seasons_y: int,
	sampler: SimSampler
) -> void:
	## Print-only (W5/H1). ASCII markers for PS 5.1 (no CJK in tools/*.ps1).
	## Format: PROGRESS pct=<job%> all_pct=<%> group=<i>/<n> <name> y=<y> q=<q> elapsed=<h:mm> eta=<h:mm> pop=<n> sails_cum=<n>
	var group_i: String = OS.get_environment("M1B_GROUP_I")
	var group_n: String = OS.get_environment("M1B_GROUP_N")
	var group_name: String = OS.get_environment("M1B_GROUP_NAME")
	var all_pct_env: String = OS.get_environment("M1B_ALL_PCT")
	if group_i.is_empty():
		group_i = "1"
	if group_n.is_empty():
		group_n = "1"
	if group_name.is_empty():
		group_name = "job"
	var y: int = int(season_index / seasons_y) + 1
	var q: int = int(season_index % seasons_y) + 1
	var days_done: int = (season_index + 1) * days_per_season
	if days_done > total_days:
		days_done = total_days
	var pct_job: float = 100.0 * float(days_done) / float(maxi(total_days, 1))
	var elapsed_ms: int = Time.get_ticks_msec() - _progress_t0_msec
	var elapsed_s: int = int(elapsed_ms / 1000)
	var eta_s: int = 0
	if days_done > 0 and days_done < total_days:
		eta_s = int(float(elapsed_s) * float(total_days - days_done) / float(days_done))
	var pop: int = 0
	for row_v in sampler.season_ports:
		var row: Dictionary = row_v
		if int(row.get("season_index", -1)) != season_index:
			continue
		pop += (
			int(row.get("rich", 0))
			+ int(row.get("citizen", 0))
			+ int(row.get("poor", 0))
			+ int(row.get("beggar", 0))
		)
	## Cumulative sails across seasons so far.
	var sails_cum: int = 0
	for row_v3 in sampler.trader_summary_rows:
		sails_cum += int((row_v3 as Dictionary).get("sail_count", 0))
	var all_pct: String = all_pct_env if not all_pct_env.is_empty() else ("%.0f" % pct_job)
	var line: String = (
		"PROGRESS pct=%.0f all_pct=%s group=%s/%s %s y=%d q=%d elapsed=%s eta=%s pop=%d sails_cum=%d"
		% [
			pct_job,
			all_pct,
			group_i,
			group_n,
			group_name,
			y,
			q,
			_fmt_hmm(elapsed_s),
			_fmt_hmm(eta_s),
			pop,
			sails_cum,
		]
	)
	print(line)


static func _fmt_hmm(total_s: int) -> String:
	var s: int = maxi(0, total_s)
	var h: int = int(s / 3600)
	var m: int = int((s % 3600) / 60)
	return "%d:%02d" % [h, m]
