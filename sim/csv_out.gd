class_name SimCsvOut
extends RefCounted
## 9.9 five CSV writers under user://sim_out/<scenario_id>/.
## A34／L10: write failures set ok=false and list failed_paths (never silent ok:true).


const HDR_SUMMARY := (
	"run_id,combo_index,seed,combo,aborted,abort_reason,"
	+ "MET-01,MET-01_pass,MET-02,MET-02_pass,MET-03,MET-03_pass,"
	+ "MET-04,MET-04_pass,MET-05a,MET-05a_pass,MET-05b,MET-05b_pass,"
	+ "MET-06,MET-06_pass,OBS-01,OBS-02,OBS-03,elapsed_ms"
)
const HDR_COMBOS := (
	"combo_index,combo,"
	+ "MET-01_avg,MET-01_min,MET-01_max,"
	+ "MET-02_avg,MET-02_min,MET-02_max,"
	+ "MET-03_avg,MET-03_min,MET-03_max,"
	+ "MET-04_avg,MET-04_min,MET-04_max,"
	+ "MET-05a_avg,MET-05a_min,MET-05a_max,"
	+ "MET-05b_avg,MET-05b_min,MET-05b_max,"
	+ "MET-06_avg,MET-06_min,MET-06_max,combo_pass"
)


static func out_dir(scenario_id: String) -> String:
	return "user://sim_out/%s/" % scenario_id


static func ensure_dir(scenario_id: String) -> String:
	var d: String = out_dir(scenario_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	return d


static func write_all(
	scenario_id: String,
	sampler: SimSampler,
	summaries: Array,
	combo_rows: Array,
	daily_ports: Array
) -> Dictionary:
	## Returns {ok, paths: PackedStringArray, failed_paths: PackedStringArray}.
	var d: String = ensure_dir(scenario_id)
	var paths: PackedStringArray = PackedStringArray()
	var failed: PackedStringArray = PackedStringArray()
	var cell_path: String = d + "season_cells.csv"
	if _write_season_cells(cell_path, sampler.season_cells):
		paths.append(cell_path)
	else:
		failed.append(cell_path)
	var ports_path: String = d + "season_ports.csv"
	if _write_season_ports(ports_path, sampler.season_ports):
		paths.append(ports_path)
	else:
		failed.append(ports_path)
	for pid_v in daily_ports:
		var pid: String = String(pid_v)
		var rows: Array = sampler.daily_rows.get(pid, [])
		var path: String = d + "daily_%s.csv" % pid
		if _write_daily(path, rows):
			paths.append(path)
		else:
			failed.append(path)
	var sum_path: String = d + "summary.csv"
	if _write_summary(sum_path, summaries):
		paths.append(sum_path)
	else:
		failed.append(sum_path)
	var combo_path: String = d + "combos.csv"
	if _write_combos(combo_path, combo_rows):
		paths.append(combo_path)
	else:
		failed.append(combo_path)
	return {
		"ok": failed.is_empty(),
		"paths": paths,
		"failed_paths": failed,
	}


static func _write_season_cells(path: String, rows: Array) -> bool:
	var lines: PackedStringArray = PackedStringArray([SimSampler.HDR_SEASON_CELLS])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				_fmt(r["run_id"]), _fmt(r["seed"]), _fmt(r["season_index"]),
				r["port_id"], r["good_id"],
				_fmt(r["stock"]), _fmt(r["mid_li"]), _fmt(r["stock_weeks"]), _fmt(r["band"]),
				_fmt(r["produced"]), _fmt(r["consumed"]),
				_fmt(r["relocated_in"]), _fmt(r["relocated_out"]),
			]
		)
	return _store(path, lines)


static func _write_season_ports(path: String, rows: Array) -> bool:
	var lines: PackedStringArray = PackedStringArray([SimSampler.HDR_SEASON_PORTS])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				_fmt(r["run_id"]), _fmt(r["seed"]), _fmt(r["season_index"]), r["port_id"],
				_fmt(r["rich"]), _fmt(r["citizen"]), _fmt(r["poor"]), _fmt(r["beggar"]),
				_fmt(r["sat_weighted"]), _fmt(r["workplaces"]), _fmt(r["beds"]),
				_fmt(r["city_balance_li"]),
			]
		)
	return _store(path, lines)


static func _write_daily(path: String, rows: Array) -> bool:
	var lines: PackedStringArray = PackedStringArray([SimSampler.HDR_DAILY])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				_fmt(r["run_id"]), _fmt(r["seed"]), _fmt(r["day"]), r["good_id"],
				_fmt(r["stock"]), _fmt(r["mid_li"]), _fmt(r["stock_weeks"]), _fmt(r["band"]),
				_fmt(r["produced"]), _fmt(r["consumed"]),
				_fmt(r["relocated_in"]), _fmt(r["relocated_out"]),
			]
		)
	return _store(path, lines)


static func _write_summary(path: String, rows: Array) -> bool:
	var lines: PackedStringArray = PackedStringArray([HDR_SUMMARY])
	for r_v in rows:
		var r: Dictionary = r_v
		var combo_esc: String = _csv_escape(String(r["combo"]))
		var reason_esc: String = _csv_escape(String(r["abort_reason"]))
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				_fmt(r["run_id"]), _fmt(r["combo_index"]), _fmt(r["seed"]), combo_esc,
				_fmt(r["aborted"]), reason_esc,
				_fmt(r["MET-01"]), r["MET-01_pass"], _fmt(r["MET-02"]), r["MET-02_pass"],
				_fmt(r["MET-03"]), r["MET-03_pass"], _fmt(r["MET-04"]), r["MET-04_pass"],
				_fmt(r["MET-05a"]), r["MET-05a_pass"], _fmt(r["MET-05b"]), r["MET-05b_pass"],
				_fmt(r["MET-06"]), r["MET-06_pass"],
				_csv_escape(String(r["OBS-01"])), _fmt(r["OBS-02"]), _fmt(r["OBS-03"]),
				_fmt(r["elapsed_ms"]),
			]
		)
	return _store(path, lines)


static func _write_combos(path: String, rows: Array) -> bool:
	var lines: PackedStringArray = PackedStringArray([HDR_COMBOS])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				_fmt(r["combo_index"]), _csv_escape(String(r["combo"])),
				_fmt(r["MET-01_avg"]), _fmt(r["MET-01_min"]), _fmt(r["MET-01_max"]),
				_fmt(r["MET-02_avg"]), _fmt(r["MET-02_min"]), _fmt(r["MET-02_max"]),
				_fmt(r["MET-03_avg"]), _fmt(r["MET-03_min"]), _fmt(r["MET-03_max"]),
				_fmt(r["MET-04_avg"]), _fmt(r["MET-04_min"]), _fmt(r["MET-04_max"]),
				_fmt(r["MET-05a_avg"]), _fmt(r["MET-05a_min"]), _fmt(r["MET-05a_max"]),
				_fmt(r["MET-05b_avg"]), _fmt(r["MET-05b_min"]), _fmt(r["MET-05b_max"]),
				_fmt(r["MET-06_avg"]), _fmt(r["MET-06_min"]), _fmt(r["MET-06_max"]),
				r["combo_pass"],
			]
		)
	return _store(path, lines)


static func _fmt(v: Variant) -> String:
	## Integers emit without ".0". Blank string stays blank.
	## Integral floats (JSON 乙) → decimal int via floori; fractional floats kept.
	if typeof(v) == TYPE_NIL:
		return ""
	if typeof(v) == TYPE_STRING:
		return String(v)
	if typeof(v) == TYPE_BOOL:
		return "1" if bool(v) else "0"
	if typeof(v) == TYPE_INT:
		return "%d" % v
	if typeof(v) == TYPE_FLOAT:
		var f: float = float(v)
		if is_equal_approx(f, roundf(f)):
			return "%d" % floori(f)
		return str(f)
	return str(v)


static func _csv_escape(s: String) -> String:
	if s.find(",") >= 0 or s.find("\"") >= 0 or s.find("\n") >= 0:
		return "\"%s\"" % s.replace("\"", "\"\"")
	return s


static func _store(path: String, lines: PackedStringArray) -> bool:
	## A34: return false on open／write failure (caller sets ok=false).
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SimCsvOut: cannot write %s err=%s" % [path, str(FileAccess.get_open_error())])
		return false
	f.store_string("\n".join(lines) + "\n")
	f.close()
	return true
