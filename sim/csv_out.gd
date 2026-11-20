class_name SimCsvOut
extends RefCounted
## 9.9 five CSV writers under user://sim_out/<scenario_id>/.


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
	## Returns {ok, paths: PackedStringArray}.
	var d: String = ensure_dir(scenario_id)
	var paths: PackedStringArray = PackedStringArray()
	_write_season_cells(d + "season_cells.csv", sampler.season_cells)
	paths.append(d + "season_cells.csv")
	_write_season_ports(d + "season_ports.csv", sampler.season_ports)
	paths.append(d + "season_ports.csv")
	for pid_v in daily_ports:
		var pid: String = String(pid_v)
		var rows: Array = sampler.daily_rows.get(pid, [])
		var path: String = d + "daily_%s.csv" % pid
		_write_daily(path, rows)
		paths.append(path)
	_write_summary(d + "summary.csv", summaries)
	paths.append(d + "summary.csv")
	_write_combos(d + "combos.csv", combo_rows)
	paths.append(d + "combos.csv")
	return {"ok": true, "paths": paths}


static func _write_season_cells(path: String, rows: Array) -> void:
	var lines: PackedStringArray = PackedStringArray([SimSampler.HDR_SEASON_CELLS])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				r["run_id"], r["seed"], r["season_index"], r["port_id"], r["good_id"],
				r["stock"], r["mid_li"], r["stock_weeks"], r["band"],
				r["produced"], r["consumed"], r["relocated_in"], r["relocated_out"],
			]
		)
	_store(path, lines)


static func _write_season_ports(path: String, rows: Array) -> void:
	var lines: PackedStringArray = PackedStringArray([SimSampler.HDR_SEASON_PORTS])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				r["run_id"], r["seed"], r["season_index"], r["port_id"],
				r["rich"], r["citizen"], r["poor"], r["beggar"], r["sat_weighted"],
				r["workplaces"], r["beds"], r["city_balance_li"],
			]
		)
	_store(path, lines)


static func _write_daily(path: String, rows: Array) -> void:
	var lines: PackedStringArray = PackedStringArray([SimSampler.HDR_DAILY])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				r["run_id"], r["seed"], r["day"], r["good_id"],
				r["stock"], r["mid_li"], r["stock_weeks"], r["band"],
				r["produced"], r["consumed"], r["relocated_in"], r["relocated_out"],
			]
		)
	_store(path, lines)


static func _write_summary(path: String, rows: Array) -> void:
	var lines: PackedStringArray = PackedStringArray([HDR_SUMMARY])
	for r_v in rows:
		var r: Dictionary = r_v
		var combo_esc: String = _csv_escape(String(r["combo"]))
		var reason_esc: String = _csv_escape(String(r["abort_reason"]))
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				r["run_id"], r["combo_index"], r["seed"], combo_esc,
				r["aborted"], reason_esc,
				r["MET-01"], r["MET-01_pass"], r["MET-02"], r["MET-02_pass"],
				r["MET-03"], r["MET-03_pass"], r["MET-04"], r["MET-04_pass"],
				r["MET-05a"], r["MET-05a_pass"], r["MET-05b"], r["MET-05b_pass"],
				r["MET-06"], r["MET-06_pass"],
				_csv_escape(String(r["OBS-01"])), r["OBS-02"], r["OBS-03"],
				r["elapsed_ms"],
			]
		)
	_store(path, lines)


static func _write_combos(path: String, rows: Array) -> void:
	var lines: PackedStringArray = PackedStringArray([HDR_COMBOS])
	for r_v in rows:
		var r: Dictionary = r_v
		lines.append(
			"%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				r["combo_index"], _csv_escape(String(r["combo"])),
				r["MET-01_avg"], r["MET-01_min"], r["MET-01_max"],
				r["MET-02_avg"], r["MET-02_min"], r["MET-02_max"],
				r["MET-03_avg"], r["MET-03_min"], r["MET-03_max"],
				r["MET-04_avg"], r["MET-04_min"], r["MET-04_max"],
				r["MET-05a_avg"], r["MET-05a_min"], r["MET-05a_max"],
				r["MET-05b_avg"], r["MET-05b_min"], r["MET-05b_max"],
				r["MET-06_avg"], r["MET-06_min"], r["MET-06_max"],
				r["combo_pass"],
			]
		)
	_store(path, lines)


static func _csv_escape(s: String) -> String:
	if s.find(",") >= 0 or s.find("\"") >= 0 or s.find("\n") >= 0:
		return "\"%s\"" % s.replace("\"", "\"\"")
	return s


static func _store(path: String, lines: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SimCsvOut: cannot write %s" % path)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
