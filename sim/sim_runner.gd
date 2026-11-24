extends SceneTree
## SYS-23 batch entry — 03_Systems 9.5 B / WP-26 layer 1.
## Usage: godot --headless --path . -s res://sim/sim_runner.gd -- --scenario <path>
##
## Multi-combo isolation: each combo×seed runs in a **child process** so Autoload
## state is never shared (avoids private SimLoop reset; see WP-26 gap note).
##
## Entry: SceneTree `_process(delta)` first frame runs `_main` once (bool re-entry
## guard), then quit. Autoload `_ready` (e.g. GoodCatalog RegEx.compile) has run
## before the first `_process`. No call_deferred／await／Timer／signal ordering.
## Do not reference Autoload identifiers at parse time — load() modules in _main.


const ARG_SCENARIO := "--scenario"
const ARG_JOB := "--job"
const ARG_PORTS_DIR := "--ports-dir"

const PATH_VALIDATOR := "res://sim/scenario_validator.gd"
const PATH_GRID := "res://sim/grid_expand.gd"
const PATH_CSV := "res://sim/csv_out.gd"
const PATH_SAMPLER := "res://sim/sampler.gd"
const PATH_TRANSFER := "res://sim/transfer_acc.gd"
const PATH_METRICS := "res://sim/metrics.gd"
const PATH_ENGINE := "res://sim/sim_engine.gd"
const PATH_JSON_INT := "res://sim/json_int.gd"

var _main_started: bool = false


func _process(_delta: float) -> bool:
	## MainLoop._process returns bool (Godot 4.7); false = keep processing until quit.
	if _main_started:
		return false
	_main_started = true
	_main()
	return false


func _main() -> void:
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
	var SimScenarioValidator: GDScript = load(PATH_VALIDATOR) as GDScript
	var SimGridExpand: GDScript = load(PATH_GRID) as GDScript
	var SimCsvOut: GDScript = load(PATH_CSV) as GDScript
	var SimSampler: GDScript = load(PATH_SAMPLER) as GDScript
	var SimTransferAcc: GDScript = load(PATH_TRANSFER) as GDScript
	var SimMetrics: GDScript = load(PATH_METRICS) as GDScript

	var validated: Dictionary = SimScenarioValidator.validate_file(scenario_path, ports_dir)
	if not bool(validated["ok"]):
		for e in validated["errors"]:
			push_error(String(e))
		print(
			"sim_runner: scenario validation failed (%s errors)"
			% str((validated["errors"] as PackedStringArray).size())
		)
		return 1
	var scenario: Dictionary = validated["scenario"]
	## WP-27: layers.RELOCATE true runs FRM-SYS23-04 via SimEngine (child process).

	## Key strings match SimScenarioValidator.KEY_* (avoid class_name at -s parse time).
	var jobs: Array = SimGridExpand.expand(scenario["grid"], scenario["seeds"])
	print(
		"sim_runner: scenario_id=%s jobs=%s"
		% [String(scenario["scenario_id"]), str(jobs.size())]
	)

	var out_d: String = SimCsvOut.ensure_dir(String(scenario["scenario_id"]))
	_wipe_dir(out_d)

	var exe: String = OS.get_executable_path()
	var project_path: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var summaries: Array = []
	var all_sampler: RefCounted = SimSampler.new()
	all_sampler.set("acc", SimTransferAcc.new())
	var SimJsonInt: GDScript = load(PATH_JSON_INT) as GDScript

	for job_v in jobs:
		var job: Dictionary = job_v
		## C-06：run_id 須為整數；非整數報錯（不靜默 floori）。
		if not bool(SimJsonInt.is_json_int(job["run_id"])):
			push_error("sim_runner: non-integral run_id rejected: %s" % str(job["run_id"]))
			return 1
		var rid: int = SimJsonInt.as_int(job["run_id"], "job.run_id")
		var job_file: String = "user://sim_jobs/job_%d.json" % rid
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://sim_jobs/")
		)
		var payload := {
			"scenario": scenario,
			"job": job,
			"ports_dir": ports_dir,
			"result_path": "user://sim_jobs/result_%d.json" % rid,
		}
		var jf := FileAccess.open(job_file, FileAccess.WRITE)
		if jf == null:
			push_error("sim_runner: cannot write job file %s" % job_file)
			return 1
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
			ProjectSettings.globalize_path(job_file),
		])
		## Evidence (d): one actual argv line for subprocess launch.
		print("sim_runner_child_argv: %s %s" % [exe, " ".join(cmd_args)])
		var output: Array = []
		var exit_code: int = OS.execute(exe, cmd_args, output, true, false)
		## A32／M18: child failure must not return 0 (stop; do not emit partial as success).
		if exit_code != 0:
			push_error("sim_runner: job run_id=%s exit=%s" % [str(job["run_id"]), str(exit_code)])
			for line in output:
				print("child: %s" % str(line))
			return exit_code if exit_code != 0 else 1
		var result_path: String = String(payload["result_path"])
		if not FileAccess.file_exists(result_path):
			push_error("sim_runner: job run_id=%s missing result %s" % [str(job["run_id"]), result_path])
			return 1
		var res_raw: String = FileAccess.get_file_as_string(result_path)
		var res_v: Variant = JSON.parse_string(res_raw)
		if typeof(res_v) != TYPE_DICTIONARY:
			push_error("sim_runner: job run_id=%s bad result JSON" % str(job["run_id"]))
			return 1
		var res: Dictionary = res_v
		if res.has("summary"):
			summaries.append(res["summary"])
		if res.has("season_cells"):
			(all_sampler.get("season_cells") as Array).append_array(res["season_cells"])
		if res.has("season_ports"):
			(all_sampler.get("season_ports") as Array).append_array(res["season_ports"])
		if res.has("obs_ext_rows"):
			(all_sampler.get("obs_ext_rows") as Array).append_array(res["obs_ext_rows"])
		if res.has("trader_summary_rows"):
			(all_sampler.get("trader_summary_rows") as Array).append_array(res["trader_summary_rows"])
		if res.has("daily_rows"):
			var dr: Dictionary = res["daily_rows"]
			var daily: Dictionary = all_sampler.get("daily_rows")
			for pid_v in dr.keys():
				var pid: String = String(pid_v)
				if not daily.has(pid):
					daily[pid] = []
				(daily[pid] as Array).append_array(dr[pid])
			all_sampler.set("daily_rows", daily)

	var combo_rows: Array = SimMetrics.aggregate_combos(summaries)
	var sid: String = String(scenario["scenario_id"])
	var written: Dictionary = SimCsvOut.write_all(
		sid, all_sampler, summaries, combo_rows, scenario["daily_detail_ports"]
	)
	## A34: CSV write failure → non-zero exit.
	if not bool(written.get("ok", false)):
		push_error("sim_runner: write_all failed paths=%s" % str(written.get("failed_paths", [])))
		return 1
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
	var SimEngine: GDScript = load(PATH_ENGINE) as GDScript
	var payload: Dictionary = parsed
	var scenario: Dictionary = payload["scenario"]
	var job: Dictionary = payload["job"]
	var ports_dir: String = String(payload.get("ports_dir", ""))
	var engine: RefCounted = SimEngine.new()
	if not ports_dir.is_empty():
		engine.set("ports_dir", ports_dir)
	var one: Dictionary = engine.call(
		"run_one_job",
		scenario,
		job,
		scenario["overrides"],
		scenario["daily_detail_ports"]
	)
	var out := {
		"summary": one.get("summary", {}),
		"season_cells": [],
		"season_ports": [],
		"daily_rows": {},
		"obs_ext_rows": [],
		"trader_summary_rows": [],
	}
	if one.has("sampler"):
		var sm: RefCounted = one["sampler"]
		out["season_cells"] = sm.get("season_cells")
		out["season_ports"] = sm.get("season_ports")
		out["daily_rows"] = sm.get("daily_rows")
		out["obs_ext_rows"] = sm.get("obs_ext_rows")
		out["trader_summary_rows"] = sm.get("trader_summary_rows")
	var result_path: String = String(payload["result_path"])
	var rf := FileAccess.open(result_path, FileAccess.WRITE)
	## A34／A32: result write failure → non-zero (parent must not treat as success).
	if rf == null:
		push_error("sim_runner: cannot write result %s" % result_path)
		return 1
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
	## R9-64 中-3／C-08: sort directory listing before mutation.
	var names: PackedStringArray = PackedStringArray()
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if not d.current_is_dir():
			names.append(fname)
		fname = d.get_next()
	d.list_dir_end()
	names.sort()
	for i in range(names.size()):
		d.remove(names[i])
