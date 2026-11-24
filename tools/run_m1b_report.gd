extends SceneTree
## 17-59 H3: read out/m1b (or --in) → report.md tables ①–⑤. Missing group = 未跑.
## Usage: godot --headless --path . -s res://tools/run_m1b_report.gd -- --in out/m1b


## Not const PackedStringArray([...]) — Godot 4.7 rejects that as non-constant.
var _GROUPS: Array = [
	"Za_G0_A0",
	"Za_G0_A250",
	"Za_G1_A0",
	"Za_G1_A250",
	"Za_G2_A0",
	"Za_G2_A250",
	"Zb_G0_notrader",
	"Zc_G0H_A0",
	"Zd_G0_seed2",
]

const RICH_LO := 0.03
const RICH_HI := 0.08
const CIT_LO := 0.20
const CIT_HI := 0.40
const POOR_MIN := 0.45
const BEGGAR_MAX := 0.10
const OPENING_TOTAL := 34200
const POP_FLOOR := 0.90
## Y5 end = season_index 19 when years=5, seasons_per_year=4.
const Y5_SEASON := 19


var _main_started: bool = false


func _process(_delta: float) -> bool:
	if _main_started:
		return false
	_main_started = true
	_main()
	return false


func _main() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var in_dir: String = _arg_value(args, "--in")
	if in_dir.is_empty():
		in_dir = "out/m1b"
	var abs_in: String = ProjectSettings.globalize_path(in_dir) if in_dir.begins_with("res://") or in_dir.begins_with("user://") else in_dir
	if not abs_in.is_absolute_path():
		abs_in = ProjectSettings.globalize_path("res://").trim_suffix("/").path_join(in_dir)
	var report_path: String = abs_in.path_join("report.md")
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# M1b report")
	lines.append("")
	lines.append("Input: `%s`" % abs_in)
	lines.append("")
	lines.append("## ① Class shares (Y5 season %d / draft_class_test C)" % Y5_SEASON)
	lines.append("")
	lines.append("| Group | status | rich% | cit% | poor% | beg% | pop | class |")
	lines.append("|-------|--------|-------|------|-------|------|-----|-------|")
	var rows1: Array = []
	for g in _GROUPS:
		var gdir: String = abs_in.path_join(g)
		var st: Dictionary = _analyze_group(g, gdir)
		rows1.append(st)
		lines.append(
			"| %s | %s | %s | %s | %s | %s | %s | %s |" % [
				g,
				st["status"],
				st["rich_pct"],
				st["cit_pct"],
				st["poor_pct"],
				st["beg_pct"],
				st["pop"],
				st["class_ok"],
			]
		)
	lines.append("")
	lines.append("## ② Floor/ceiling band cells ≤30% (Y5)")
	lines.append("")
	lines.append("| Group | status | band0+4%% | pass |")
	lines.append("|-------|--------|----------|------|")
	for st_v in rows1:
		var st2: Dictionary = st_v
		lines.append(
			"| %s | %s | %s | %s |" % [
				st2["group"], st2["status"], st2["band04_pct"], st2["band_ok"]
			]
		)
	lines.append("")
	lines.append("## ③ Three-tier ratio order vs opening")
	lines.append("")
	lines.append("| Group | status | order | pass |")
	lines.append("|-------|--------|-------|------|")
	for st_v2 in rows1:
		var st3: Dictionary = st_v2
		lines.append(
			"| %s | %s | %s | %s |" % [
				st3["group"], st3["status"], st3["tier_order"], st3["tier_ok"]
			]
		)
	lines.append("")
	lines.append("## ④ City cash not monotonically rising")
	lines.append("")
	lines.append("| Group | status | mono_ports | ports | pass |")
	lines.append("|-------|--------|------------|-------|------|")
	for st_v3 in rows1:
		var st4: Dictionary = st_v3
		lines.append(
			"| %s | %s | %s | %s | %s |" % [
				st4["group"], st4["status"], st4["cash_mono"], st4["cash_ports"], st4["cash_ok"]
			]
		)
	lines.append("")
	lines.append("## ⑤ Timing / traders / abort")
	lines.append("")
	lines.append("| Group | status | duration_s | aborted | abort_reason | sail_sum | cargo_dan_sum |")
	lines.append("|-------|--------|------------|---------|--------------|----------|---------------|")
	for st_v4 in rows1:
		var st5: Dictionary = st_v4
		lines.append(
			"| %s | %s | %s | %s | %s | %s | %s |" % [
				st5["group"],
				st5["status"],
				st5["duration_s"],
				st5["aborted"],
				st5["abort_reason"],
				st5["sail_sum"],
				st5["cargo_dan_sum"],
			]
		)
	lines.append("")
	## D-123(c)／K3: per-group trader totals + per-season sail counts.
	lines.append("## ⑥ Trader sail / cargo (D-123)")
	lines.append("")
	lines.append("| Group | status | sail_sum | cargo_dan_sum | season_sails |")
	lines.append("|-------|--------|----------|---------------|--------------|")
	for st_v5 in rows1:
		var st6: Dictionary = st_v5
		lines.append(
			"| %s | %s | %s | %s | %s |" % [
				st6["group"],
				st6["status"],
				st6["sail_sum"],
				st6["cargo_dan_sum"],
				st6["season_sails"],
			]
		)
	lines.append("")
	var body: String = "\n".join(lines) + "\n"
	DirAccess.make_dir_recursive_absolute(abs_in)
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f == null:
		push_error("run_m1b_report: cannot write %s" % report_path)
		quit(1)
		return
	f.store_string(body)
	f.close()
	print("run_m1b_report: wrote %s" % report_path)
	print(body)
	quit(0)


func _analyze_group(group: String, gdir: String) -> Dictionary:
	## 17-64 T3: missing data → N/A (never blank PASS/FAIL).
	var out := {
		"group": group,
		"status": "未跑",
		"rich_pct": "N/A",
		"cit_pct": "N/A",
		"poor_pct": "N/A",
		"beg_pct": "N/A",
		"pop": "N/A",
		"class_ok": "N/A",
		"band04_pct": "N/A",
		"band_ok": "N/A",
		"tier_order": "N/A",
		"tier_ok": "N/A",
		"cash_mono": "N/A",
		"cash_ports": "N/A",
		"cash_ok": "N/A",
		"duration_s": "N/A",
		"aborted": "N/A",
		"abort_reason": "N/A",
		"sail_sum": "N/A",
		"cargo_dan_sum": "N/A",
		"season_sails": "N/A",
	}
	if not DirAccess.dir_exists_absolute(gdir):
		return out
	var ports_path: String = gdir.path_join("season_ports.csv")
	var cells_path: String = gdir.path_join("season_cells.csv")
	var summary_path: String = gdir.path_join("summary.csv")
	var trader_path: String = gdir.path_join("trader_summary.csv")
	var timing_path: String = gdir.path_join("timing.txt")
	if not FileAccess.file_exists(ports_path):
		out["status"] = "未跑"
		return out
	out["status"] = "ok"
	if FileAccess.file_exists(timing_path):
		for line in FileAccess.get_file_as_string(timing_path).split("\n"):
			var s: String = String(line).strip_edges()
			if s.begins_with("duration_s="):
				out["duration_s"] = s.trim_prefix("duration_s=")
			if s.begins_with("status=") and s.trim_prefix("status=") == "fail":
				out["status"] = "fail"
	var ports: Array = _read_csv(ports_path)
	## 17-64 T2: SmokeDays < 1 season (no Y5) → sample last season row if any;
	## if season_ports empty (short --days never hit cutoff), metrics stay N/A (T3).
	var y5: Array = []
	var used_last_season := false
	for r_v in ports:
		var r: Dictionary = r_v
		if int(float(String(r.get("season_index", "-1")))) == Y5_SEASON:
			y5.append(r)
	if y5.is_empty():
		var max_si := -1
		for r2_v in ports:
			max_si = maxi(max_si, int(float(String((r2_v as Dictionary).get("season_index", "-1")))))
		if max_si >= 0:
			used_last_season = true
			for r3_v in ports:
				if int(float(String((r3_v as Dictionary).get("season_index", "-1")))) == max_si:
					y5.append(r3_v)
	var rich := 0
	var cit := 0
	var poor := 0
	var beg := 0
	for r4_v in y5:
		var rr: Dictionary = r4_v
		rich += _as_int(rr.get("rich", 0))
		cit += _as_int(rr.get("citizen", 0))
		poor += _as_int(rr.get("poor", 0))
		beg += _as_int(rr.get("beggar", 0))
	var total: int = rich + cit + poor + beg
	## 17-64 T4: prefer live pop from progress.log (PopulationModel at emit), not a
	## stale/empty season-sample sum when short smoke never wrote season_ports.
	var live_pop := _live_pop_from_progress(gdir)
	if live_pop >= 0:
		out["pop"] = str(live_pop)
	elif total > 0:
		out["pop"] = str(total)
	else:
		out["pop"] = "N/A"
	## 17-64 T3: no data → N/A (never PASS/FAIL).
	if total <= 0 or y5.is_empty():
		out["rich_pct"] = "N/A"
		out["cit_pct"] = "N/A"
		out["poor_pct"] = "N/A"
		out["beg_pct"] = "N/A"
		out["class_ok"] = "N/A"
		out["tier_order"] = "N/A"
		out["tier_ok"] = "N/A"
	else:
		var rs: float = float(rich) / float(total)
		var cs: float = float(cit) / float(total)
		var ps: float = float(poor) / float(total)
		var bs: float = float(beg) / float(total)
		out["rich_pct"] = "%.2f" % (rs * 100.0)
		out["cit_pct"] = "%.2f" % (cs * 100.0)
		out["poor_pct"] = "%.2f" % (ps * 100.0)
		out["beg_pct"] = "%.2f" % (bs * 100.0)
		## Last-season smoke sample: still score, but only against available rows.
		var class_ok: bool = (
			rs >= RICH_LO and rs <= RICH_HI
			and cs >= CIT_LO and cs <= CIT_HI
			and ps >= POOR_MIN
			and bs <= BEGGAR_MAX
			and total >= int(OPENING_TOTAL * POP_FLOOR)
		)
		out["class_ok"] = "PASS" if class_ok else "FAIL"
		var tier_ok: bool = ps >= cs and cs >= rs
		out["tier_order"] = "poor≥cit≥rich"
		out["tier_ok"] = "PASS" if tier_ok else "FAIL"
		if used_last_season:
			out["tier_order"] = "poor≥cit≥rich (last season)"
	## Cash mono across seasons per port.
	var by_port: Dictionary = {}
	for r5_v in ports:
		var rp: Dictionary = r5_v
		var pid: String = String(rp.get("port_id", ""))
		if not by_port.has(pid):
			by_port[pid] = []
		(by_port[pid] as Array).append(_as_int(rp.get("city_balance_li", 0)))
	var mono_n := 0
	var port_n: int = by_port.size()
	for pid_v in by_port.keys():
		var series: Array = by_port[pid_v]
		var rising := true
		for i in range(series.size() - 1):
			if int(series[i]) > int(series[i + 1]):
				rising = false
				break
		if rising and series.size() > 1:
			mono_n += 1
	out["cash_mono"] = str(mono_n) if port_n > 0 else "N/A"
	out["cash_ports"] = str(port_n) if port_n > 0 else "N/A"
	if port_n <= 0 or ports.is_empty():
		out["cash_ok"] = "N/A"
	else:
		out["cash_ok"] = "PASS" if mono_n < port_n else "FAIL"
	## Band floor+ceil.
	if FileAccess.file_exists(cells_path):
		var cells: Array = _read_csv(cells_path)
		var y5c: Array = []
		for c_v in cells:
			if int(float(String((c_v as Dictionary).get("season_index", "-1")))) == Y5_SEASON:
				y5c.append(c_v)
		if y5c.is_empty():
			## T2 short smoke: last season_index present, else all rows.
			var max_c := -1
			for c0_v in cells:
				max_c = maxi(max_c, int(float(String((c0_v as Dictionary).get("season_index", "-1")))))
			if max_c >= 0:
				for c1_v in cells:
					if int(float(String((c1_v as Dictionary).get("season_index", "-1")))) == max_c:
						y5c.append(c1_v)
			else:
				y5c = cells
		var n: int = y5c.size()
		if n <= 0:
			out["band04_pct"] = "N/A"
			out["band_ok"] = "N/A"
		else:
			var edge := 0
			for c3_v in y5c:
				var bi2: int = _as_int((c3_v as Dictionary).get("band", -1))
				if bi2 == 0 or bi2 == 4:
					edge += 1
			var pct: float = 100.0 * float(edge) / float(maxi(n, 1))
			out["band04_pct"] = "%.1f" % pct
			out["band_ok"] = "PASS" if pct <= 30.0 else "FAIL"
	else:
		out["band04_pct"] = "N/A"
		out["band_ok"] = "N/A"
	if FileAccess.file_exists(summary_path):
		var sums: Array = _read_csv(summary_path)
		if not sums.is_empty():
			var s0: Dictionary = sums[0]
			out["aborted"] = String(s0.get("aborted", ""))
			out["abort_reason"] = String(s0.get("abort_reason", "")).replace("|", "/")
	if FileAccess.file_exists(trader_path):
		var sails := 0
		var cargo_sum := 0
		var by_season: Dictionary = {} ## season_index:String → sails
		for t_v in _read_csv(trader_path):
			var tr: Dictionary = t_v
			var sc: int = _as_int(tr.get("sail_count", 0))
			sails += sc
			var si: String = String(tr.get("season_index", ""))
			by_season[si] = int(by_season.get(si, 0)) + sc
			cargo_sum += _cargo_dan_total(String(tr.get("cargo_dan_json", "{}")))
		out["sail_sum"] = str(sails)
		out["cargo_dan_sum"] = str(cargo_sum)
		var season_keys: Array = by_season.keys()
		season_keys.sort_custom(func(a, b): return _as_int(a) < _as_int(b))
		var parts: PackedStringArray = PackedStringArray()
		for sk in season_keys:
			parts.append("%s:%d" % [String(sk), int(by_season[sk])])
		out["season_sails"] = ",".join(parts)
	else:
		if out["sail_sum"] == "" or out["sail_sum"] == "N/A":
			out["sail_sum"] = "N/A"
		if out["cargo_dan_sum"] == "" or out["cargo_dan_sum"] == "N/A":
			out["cargo_dan_sum"] = "N/A"
		if out["season_sails"] == "" or out["season_sails"] == "N/A":
			out["season_sails"] = "N/A"
	return out


## 17-64 T4: read last PROGRESS pop= from group or pack progress.log (live at emit).
func _live_pop_from_progress(gdir: String) -> int:
	var candidates: PackedStringArray = PackedStringArray([
		gdir.path_join("progress.log"),
		gdir.path_join("sim_runner.log"),
		gdir.get_base_dir().path_join("progress.log"),
	])
	var last_pop := -1
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var s: String = String(line)
			var idx: int = s.find("pop=")
			if idx < 0:
				continue
			var rest: String = s.substr(idx + 4)
			var num := ""
			for i in range(rest.length()):
				var ch: String = rest.substr(i, 1)
				if ch >= "0" and ch <= "9":
					num += ch
				else:
					break
			if not num.is_empty():
				last_pop = int(num)
	return last_pop


func _cargo_dan_total(raw: String) -> int:
	## cargo_dan_json is a compact JSON object good→dan; sum values. Empty/`{}` → 0.
	var s: String = raw.strip_edges()
	if s.is_empty() or s == "{}":
		return 0
	## CSV reader may leave quotes; strip one layer.
	if s.begins_with("\"") and s.ends_with("\"") and s.length() >= 2:
		s = s.substr(1, s.length() - 2).replace("\"\"", "\"")
	var parsed: Variant = JSON.parse_string(s)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for k in (parsed as Dictionary).keys():
		total += _as_int((parsed as Dictionary)[k])
	return total



func _read_csv(path: String) -> Array:
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = text.strip_edges().split("\n")
	if lines.is_empty():
		return []
	var hdr: PackedStringArray = String(lines[0]).split(",")
	var rows: Array = []
	for i in range(1, lines.size()):
		var cols: PackedStringArray = String(lines[i]).split(",")
		var row := {}
		for j in range(mini(hdr.size(), cols.size())):
			row[String(hdr[j])] = String(cols[j])
		rows.append(row)
	return rows


func _as_int(v: Variant) -> int:
	var s: String = String(v)
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return int(float(s))
	return 0


func _arg_value(args: PackedStringArray, key: String) -> String:
	for i in range(args.size()):
		if String(args[i]) == key and i + 1 < args.size():
			return String(args[i + 1])
	return ""
