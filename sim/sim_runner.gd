extends SceneTree
## SYS-23 batch entry — 03_Systems 9.5 B / WP-26 layer 1.
## Usage: godot --headless --path . -s res://sim/sim_runner.gd -- --scenario <path>
##
## Multi-combo isolation: each combo×seed runs in a **child process** so Autoload
## state is never shared (avoids private SimLoop reset; see WP-26 gap note).
## 17-60: `--inline` runs jobs in-process (Windows Owner / progress); subprocess
## kept for Linux parallel. `--job` stays `user://…` (no spaces in argv).
##
## Entry: SceneTree `_process(delta)` first frame runs `_main` once (bool re-entry
## guard), then quit. Autoload `_ready` (e.g. GoodCatalog RegEx.compile) has run
## before the first `_process`. No call_deferred／await／Timer／signal ordering.
## Do not reference Autoload identifiers at parse time — load() modules in _main.


const ARG_SCENARIO := "--scenario"
const ARG_JOB := "--job"
const ARG_PORTS_DIR := "--ports-dir"
const ARG_INLINE := "--inline"
const ARG_DAYS := "--days"
const ARG_OUT_DIR := "--out-dir"
const ARG_SEASON_PROGRESS := "--season-progress"

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
	var days_raw: String = _arg_value(args, ARG_DAYS)
	var out_dir: String = _arg_value(args, ARG_OUT_DIR)
	var inline_mode: bool = _arg_flag(args, ARG_INLINE)
	var season_progress: bool = _arg_flag(args, ARG_SEASON_PROGRESS) or inline_mode
	if not job_path.is_empty():
		## W1: accept user:// or absolute; resolve via globalize_path when user://.
		var resolved_job: String = _resolve_path(job_path)
		var rc: int = _run_job_file(resolved_job, season_progress, days_raw)
		quit(rc)
		return
	if scenario_path.is_empty():
		## W2: missing argv → full argv + reason, nonzero (C-06).
		push_error(
			"sim_runner: argv=[%s] reason=require --scenario <path> or --job <path>"
			% _argv_join(args)
		)
		quit(1)
		return
	if _arg_missing_value(args, ARG_SCENARIO):
		push_error(
			"sim_runner: argv=[%s] reason=--scenario requires a path value"
			% _argv_join(args)
		)
		quit(1)
		return
	var rc2: int = _run_scenario_orchestrator(
		scenario_path, ports_dir, inline_mode, season_progress, days_raw, out_dir
	)
	quit(rc2)


func _run_scenario_orchestrator(
	scenario_path: String,
	ports_dir: String,
	inline_mode: bool,
	season_progress: bool,
	days_raw: String,
	out_dir: String
) -> int:
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
	if not days_raw.is_empty():
		if not days_raw.is_valid_int() or int(days_raw) < 1:
			push_error(
				"sim_runner: argv days=%s reason=--days must be int ≥ 1" % days_raw
			)
			return 1
		scenario["days_override"] = int(days_raw)
	## WP-27: layers.RELOCATE true runs FRM-SYS23-04 via SimEngine (child process).

	## Key strings match SimScenarioValidator.KEY_* (avoid class_name at -s parse time).
	var jobs: Array = SimGridExpand.expand(scenario["grid"], scenario["seeds"])
	print(
		"sim_runner: scenario_id=%s jobs=%s inline=%s"
		% [String(scenario["scenario_id"]), str(jobs.size()), str(inline_mode)]
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
		## W1: job path stays user:// (no spaces); one argv element.
		var job_file: String = "user://sim_jobs/job_%d.json" % rid
		var log_file: String = "user://sim_jobs/job_%d.log" % rid
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://sim_jobs/")
		)
		var payload := {
			"scenario": scenario,
			"job": job,
			"ports_dir": ports_dir,
			"result_path": "user://sim_jobs/result_%d.json" % rid,
			"season_progress": season_progress,
		}
		var jf := FileAccess.open(job_file, FileAccess.WRITE)
		if jf == null:
			push_error("sim_runner: cannot write job file %s" % job_file)
			return 1
		jf.store_string(JSON.stringify(payload))
		jf.close()

		var exit_code: int = 0
		if inline_mode:
			## W4: same-process job (Owner Windows; progress visible).
			print("sim_runner_inline_job: %s" % job_file)
			exit_code = _run_job_file(
				ProjectSettings.globalize_path(job_file), season_progress, days_raw
			)
		else:
			## W1 argv: one element per arg; --job = user:// path (no spaces).
			## W3: --log-file on engine side (absolute; engine flag before --).
			## Do not capture child stdout into an Array (read_stdout=false): with
			## TRADERS on, pipe fill / huge buffers crash Godot OS.execute
			## (cowdata p_size<0 / SIGSEGV). Diagnostics come from --log-file.
			var log_abs: String = ProjectSettings.globalize_path(log_file)
			var cmd_args: PackedStringArray = PackedStringArray([
				"--headless",
				"--path",
				project_path,
				"--log-file",
				log_abs,
				"-s",
				"res://sim/sim_runner.gd",
				"--",
				ARG_JOB,
				job_file,
			])
			if season_progress:
				cmd_args.append(ARG_SEASON_PROGRESS)
			## Evidence (d): one actual argv line for subprocess launch.
			print("sim_runner_child_argv: %s %s" % [exe, " ".join(cmd_args)])
			## Prove --job value is a single array element (W1 tests).
			print("sim_runner_job_argv_elem: %s" % job_file)
			var child_output: Array = []
			exit_code = OS.execute(exe, cmd_args, child_output, false, false)
			if exit_code != 0:
				## W3: print last 40 log lines; synthesize abort in summary path below.
				_print_log_tail(log_abs, 40)
				push_error(
					"sim_runner: job run_id=%s exit=%s" % [str(job["run_id"]), str(exit_code)]
				)
				var abort_summary := {
					"run_id": rid,
					"combo_index": job.get("combo_index", 0),
					"seed": job.get("seed", 0),
					"combo": JSON.stringify(job.get("combo", {})),
					"aborted": 1,
					"abort_reason": "exit code %s" % str(exit_code),
					"elapsed_ms": 0,
				}
				summaries.append(abort_summary)
				## Stop; do not emit partial as success (A32／M18).
				var sid_abort: String = String(scenario["scenario_id"])
				var written_abort: Dictionary = SimCsvOut.write_all(
					sid_abort,
					all_sampler,
					summaries,
					SimMetrics.aggregate_combos(summaries),
					scenario["daily_detail_ports"]
				)
				if not out_dir.is_empty():
					_copy_outputs(sid_abort, out_dir)
				return exit_code if exit_code != 0 else 1

		var result_path: String = String(payload["result_path"])
		if not FileAccess.file_exists(result_path):
			push_error(
				"sim_runner: job run_id=%s missing result %s" % [str(job["run_id"]), result_path]
			)
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
		if inline_mode and exit_code != 0:
			return exit_code if exit_code != 0 else 1

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
	if not out_dir.is_empty():
		if not _copy_outputs(sid, out_dir):
			push_error("sim_runner: --out-dir copy failed dest=%s" % out_dir)
			return 1
	return 0


func _run_job_file(job_path: String, season_progress: bool = false, days_raw: String = "") -> int:
	## job_path may be user:// or absolute (W1 child globalize_path).
	var path: String = job_path
	if path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(job_path):
		push_error(
			"sim_runner: argv=[%s] reason=job file missing %s"
			% [_argv_join(OS.get_cmdline_user_args()), job_path]
		)
		return 1
	var read_path: String = path if FileAccess.file_exists(path) else job_path
	var raw: String = FileAccess.get_file_as_string(read_path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error(
			"sim_runner: argv=[%s] reason=bad job JSON path=%s"
			% [_argv_join(OS.get_cmdline_user_args()), job_path]
		)
		return 1
	var SimEngine: GDScript = load(PATH_ENGINE) as GDScript
	var payload: Dictionary = parsed
	var scenario: Dictionary = payload["scenario"]
	if not days_raw.is_empty() and days_raw.is_valid_int():
		scenario["days_override"] = int(days_raw)
	elif payload.get("scenario", {}).get("days_override", null) != null:
		pass
	var job: Dictionary = payload["job"]
	var ports_dir: String = String(payload.get("ports_dir", ""))
	var want_progress: bool = season_progress or bool(payload.get("season_progress", false))
	var engine: RefCounted = SimEngine.new()
	if not ports_dir.is_empty():
		engine.set("ports_dir", ports_dir)
	engine.set("print_season_progress", want_progress)
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
	## Nonzero when job aborted (W3 summary aborted=1 already in summary).
	var summary: Dictionary = out.get("summary", {})
	if int(summary.get("aborted", 0)) == 1:
		return 1
	return 0


func _arg_value(args: PackedStringArray, key: String) -> String:
	for i in range(args.size()):
		if String(args[i]) == key and i + 1 < args.size():
			return String(args[i + 1])
	return ""


func _arg_flag(args: PackedStringArray, key: String) -> bool:
	for i in range(args.size()):
		if String(args[i]) == key:
			return true
	return false


func _arg_missing_value(args: PackedStringArray, key: String) -> bool:
	for i in range(args.size()):
		if String(args[i]) == key:
			return i + 1 >= args.size() or String(args[i + 1]).begins_with("--")
	return false


func _argv_join(args: PackedStringArray) -> String:
	return " ".join(args)


func _resolve_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _print_log_tail(log_path: String, n: int) -> void:
	## W3: on nonzero child, print last n log lines.
	if not FileAccess.file_exists(log_path):
		push_error("sim_runner: log file missing %s" % log_path)
		return
	var text: String = FileAccess.get_file_as_string(log_path)
	var lines: PackedStringArray = text.split("\n")
	var start: int = maxi(0, lines.size() - n)
	print("sim_runner_log_tail begin path=%s lines=%s" % [log_path, str(mini(n, lines.size()))])
	for i in range(start, lines.size()):
		print("log: %s" % String(lines[i]))
	print("sim_runner_log_tail end")


func _copy_outputs(scenario_id: String, dest_dir: String) -> bool:
	var SimCsvOut: GDScript = load(PATH_CSV) as GDScript
	var src: String = SimCsvOut.out_dir(scenario_id)
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var d := DirAccess.open(src)
	if d == null:
		return false
	var ok := true
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if not d.current_is_dir():
			var from_p: String = ProjectSettings.globalize_path(src + fname)
			var to_p: String = dest_dir.rstrip("/\\") + "/" + fname
			var data: PackedByteArray = FileAccess.get_file_as_bytes(from_p)
			var wf := FileAccess.open(to_p, FileAccess.WRITE)
			if wf == null:
				ok = false
			else:
				wf.store_buffer(data)
				wf.close()
		fname = d.get_next()
	d.list_dir_end()
	print("sim_runner: copied outputs to %s" % dest_dir)
	return ok


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
