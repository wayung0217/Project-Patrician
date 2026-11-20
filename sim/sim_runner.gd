extends SceneTree
## SYS-23 batch entry — 03_Systems 9.5 B / WP-26 layer 1.
## Usage: godot --headless --path . -s res://sim/sim_runner.gd -- --scenario <path>
##
## Multi-combo isolation: each combo×seed runs in a **child process** so Autoload
## state is never shared (avoids private SimLoop reset; see WP-26 gap note).


const ARG_SCENARIO := "--scenario"
const ARG_JOB := "--job"
const ARG_PORTS_DIR := "--ports-dir"


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scenario_path: String = _arg_value(args, ARG_SCENARIO)
	var job_path: String = _arg_value(args, ARG_JOB)
	var ports_dir: String = _arg_value(args, ARG_PORTS_DIR)
	if not job_path.is_empty():
		var rc: int = _run_job_file(job_path)
		quit(rc)
		return
	if scenario_path.is_empty():
		push_error("sim_runner: require --scenario <path> or --job <path>")
		quit(1)
		return
	var rc2: int = _run_scenario_orchestrator(scenario_path, ports_dir)
	quit(rc2)


func _run_scenario_orchestrator(scenario_path: String, ports_dir: String) -> int:
	var validated: Dictionary = SimScenarioValidator.validate_file(scenario_path, ports_dir)
	if not bool(validated["ok"]):
		for e in validated["errors"]:
			push_error(String(e))
		print("sim_runner: scenario validation failed (%s errors)" % str((validated["errors"] as PackedStringArray).size()))
		return 1
	var scenario: Dictionary = validated["scenario"]
	if bool((scenario.get("layers", {}) as Dictionary).get("RELOCATE", false)):
		push_error("sim_runner: WP-26 supports layer1 ISOLATED only (RELOCATE=false)")
		return 1

	var jobs: Array = SimGridExpand.expand(
		scenario[SimScenarioValidator.KEY_GRID],
		scenario[SimScenarioValidator.KEY_SEEDS]
	)
	print(
		"sim_runner: scenario_id=%s jobs=%s"
		% [String(scenario[SimScenarioValidator.KEY_SCENARIO_ID]), str(jobs.size())]
	)

	## Clear prior outputs for this scenario_id.
	var out_d: String = SimCsvOut.ensure_dir(String(scenario[SimScenarioValidator.KEY_SCENARIO_ID]))
	_wipe_dir(out_d)

	var exe: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var summaries: Array = []
	var all_sampler := SimSampler.new()
	all_sampler.acc = SimTransferAcc.new()

	for job_v in jobs:
		var job: Dictionary = job_v
		var job_file: String = "user://sim_jobs/job_%d.json" % int(job["run_id"])
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://sim_jobs/")
		)
		var payload := {
			"scenario": scenario,
			"job": job,
			"ports_dir": ports_dir,
			"result_path": "user://sim_jobs/result_%d.json" % int(job["run_id"]),
		}
		var jf := FileAccess.open(job_file, FileAccess.WRITE)
		jf.store_string(JSON.stringify(payload))
		jf.close()
		var cmd_args: PackedStringArray = PackedStringArray([
			"--headless",
			"--path",
			project_path,
			"-s",
			"res://sim/sim_runner.gd",
			"--",
			ARG_JOB,
			job_file,
		])
		var output: Array = []
		var exit_code: int = OS.execute(exe, cmd_args, output, true, false)
		if exit_code != 0:
			push_error("sim_runner: job run_id=%s exit=%s" % [str(job["run_id"]), str(exit_code)])
		var result_path: String = String(payload["result_path"])
		if FileAccess.file_exists(result_path):
			var res_raw: String = FileAccess.get_file_as_string(result_path)
			var res_v: Variant = JSON.parse_string(res_raw)
			if typeof(res_v) == TYPE_DICTIONARY:
				var res: Dictionary = res_v
				if res.has("summary"):
					summaries.append(res["summary"])
				if res.has("season_cells"):
					all_sampler.season_cells.append_array(res["season_cells"])
				if res.has("season_ports"):
					all_sampler.season_ports.append_array(res["season_ports"])
				if res.has("daily_rows"):
					var dr: Dictionary = res["daily_rows"]
					for pid_v in dr.keys():
						var pid: String = String(pid_v)
						if not all_sampler.daily_rows.has(pid):
							all_sampler.daily_rows[pid] = []
						(all_sampler.daily_rows[pid] as Array).append_array(dr[pid])

	var combo_rows: Array = SimMetrics.aggregate_combos(summaries)
	var sid: String = String(scenario[SimScenarioValidator.KEY_SCENARIO_ID])
	SimCsvOut.write_all(
		sid,
		all_sampler,
		summaries,
		combo_rows,
		scenario[SimScenarioValidator.KEY_DAILY_PORTS]
	)
	print("sim_runner: wrote outputs under %s" % SimCsvOut.out_dir(sid))
	return 0


func _run_job_file(job_path: String) -> int:
	if not FileAccess.file_exists(job_path):
		push_error("sim_runner: job file missing %s" % job_path)
		return 1
	var raw: String = FileAccess.get_file_as_string(job_path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("sim_runner: bad job JSON")
		return 1
	var payload: Dictionary = parsed
	var scenario: Dictionary = payload["scenario"]
	var job: Dictionary = payload["job"]
	var ports_dir: String = String(payload.get("ports_dir", ""))
	var engine := SimEngine.new()
	if not ports_dir.is_empty():
		engine.ports_dir = ports_dir
	## Single job in fresh process — no session_reset needed.
	var one: Dictionary = engine.run_one_job(
		scenario,
		job,
		scenario[SimScenarioValidator.KEY_OVERRIDES],
		scenario[SimScenarioValidator.KEY_DAILY_PORTS]
	)
	var out := {
		"summary": one.get("summary", {}),
		"season_cells": [],
		"season_ports": [],
		"daily_rows": {},
	}
	if one.has("sampler"):
		var sm: SimSampler = one["sampler"]
		out["season_cells"] = sm.season_cells
		out["season_ports"] = sm.season_ports
		out["daily_rows"] = sm.daily_rows
	var result_path: String = String(payload["result_path"])
	var rf := FileAccess.open(result_path, FileAccess.WRITE)
	rf.store_string(JSON.stringify(out))
	rf.close()
	return 0


func _arg_value(args: PackedStringArray, key: String) -> String:
	for i in range(args.size()):
		if String(args[i]) == key and i + 1 < args.size():
			return String(args[i + 1])
	return ""


func _wipe_dir(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if not d.current_is_dir():
			d.remove(fname)
		fname = d.get_next()
	d.list_dir_end()
