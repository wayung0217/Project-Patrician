extends SceneTree
## 17-59 H3: read out/m1b (or --in) → report.md tables ①–⑤ + 17-69 SEED_NO_EFFECT / K3 cols.
## 17-71 ⑥: L5 base + L4 duration_s / per-season sails / cargo_dan_sum transplant.
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

## 17-69 5.1: seed-only pairs (same scenario; seed differs). Warning only — never flip PASS/FAIL.
var _SEED_PAIRS: Array = [
	["Za_G0_A0", "Zd_G0_seed2"],
]

## Metric keys compared for SEED_NO_EFFECT (①②③④ display values only).
var _SEED_METRIC_KEYS: Array = [
	"pop",
	"rich_pct",
	"cit_pct",
	"poor_pct",
	"beg_pct",
	"band04_pct",
	"tier_order",
	"cash_mono",
	"cash_ports",
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
	## 17-72 C／band 方向（MarketPricer.Band；數字越大越貴）：
	## band0＝VERY_LOW＝價格過低＝過剩／地板；band4＝VERY_HIGH＝價格過高＝缺貨／天花板.
	lines.append(
		"_Band direction (code): **band0** = price floor / oversupply (VERY_LOW); "
		+ "**band4** = price ceiling / shortage (VERY_HIGH). "
		+ "Edge% = (band0+band4)/n ≤ 30%._"
	)
	lines.append("")
	lines.append("| Group | status | band0 | band4 | band0+4%% | pass |")
	lines.append("|-------|--------|------:|------:|----------|------|")
	for st_v in rows1:
		var st2: Dictionary = st_v
		lines.append(
			"| %s | %s | %s | %s | %s | %s |" % [
				st2["group"], st2["status"],
				st2.get("band0_n", "N/A"), st2.get("band4_n", "N/A"),
				st2["band04_pct"], st2["band_ok"]
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
	## L4 transplant (D-123／K3): per-season sails from season_index + cargo_dan_sum.
	lines.append("## ⑤b Trader sail / cargo by season (L4 duration/sails/cargo)")
	lines.append("")
	lines.append("| Group | status | sail_sum | cargo_dan_sum | season_sails |")
	lines.append("|-------|--------|----------|---------------|--------------|")
	for st_v5b in rows1:
		var st5b: Dictionary = st_v5b
		lines.append(
			"| %s | %s | %s | %s | %s |" % [
				st5b["group"],
				st5b["status"],
				st5b["sail_sum"],
				st5b["cargo_dan_sum"],
				st5b["season_sails"],
			]
		)
	lines.append("")
	## 17-69 5.2: season_sail_count / season_cargo_dan columns — N/A if missing (T3; never PASS/FAIL).
	lines.append("## ⑥ season_sail_count / season_cargo_dan (column present?)")
	lines.append("")
	lines.append("| Group | status | season_sail_count | season_cargo_dan |")
	lines.append("|-------|--------|-------------------|------------------|")
	for st_v6 in rows1:
		var st6: Dictionary = st_v6
		lines.append(
			"| %s | %s | %s | %s |" % [
				st6["group"],
				st6["status"],
				st6["season_sail_count"],
				st6["season_cargo_dan"],
			]
		)
	lines.append("")
	## 17-69 5.3: per-group trader total sails + total cargo (from trader_summary).
	lines.append("## ⑦ Trader totals (sails + cargo_dan)")
	lines.append("")
	lines.append("| Group | status | trader_sails_total | trader_cargo_dan_total |")
	lines.append("|-------|--------|--------------------|------------------------|")
	for st_v7 in rows1:
		var st7: Dictionary = st_v7
		lines.append(
			"| %s | %s | %s | %s |" % [
				st7["group"],
				st7["status"],
				st7["trader_sails_total"],
				st7["trader_cargo_dan_total"],
			]
		)
	lines.append("")
	## 17-72 C-v：season_ports 待聘／空職／空床（有欄才計；缺欄＝N/A）.
	lines.append("## ⑧ C-v diagnostics (beggar_gt_10 / vacant)")
	lines.append("")
	lines.append(
		"| Group | status | ports_rows | beggar_gt_10_n | vacant_jobs_sum | vacant_beds_sum |"
	)
	lines.append(
		"|-------|--------|----------:|---------------:|----------------:|----------------:|"
	)
	for st_v8 in rows1:
		var st8: Dictionary = st_v8
		lines.append(
			"| %s | %s | %s | %s | %s | %s |" % [
				st8["group"],
				st8["status"],
				st8.get("cv_ports_rows", "N/A"),
				st8.get("cv_beggar_gt_10_n", "N/A"),
				st8.get("cv_vacant_jobs_sum", "N/A"),
				st8.get("cv_vacant_beds_sum", "N/A"),
			]
		)
	lines.append("")
	## 17-72 D1／D2（D-127 甲驗收門改寫）— 資料路徑；不調參.
	_append_d1_seed_gate(lines, rows1)
	_append_d2_trader_gate(lines, rows1)
	## 17-69 5.1 legacy SEED_NO_EFFECT warning kept for continuity.
	_append_seed_no_effect(lines, rows1)
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
		"band0_n": "N/A",
		"band4_n": "N/A",
		"band_ok": "N/A",
		"cv_ports_rows": "N/A",
		"cv_beggar_gt_10_n": "N/A",
		"cv_vacant_jobs_sum": "N/A",
		"cv_vacant_beds_sum": "N/A",
		"tier_order": "N/A",
		"tier_ok": "N/A",
		"cash_mono": "N/A",
		"cash_ports": "N/A",
		"cash_ok": "N/A",
		"duration_s": "N/A",
		"aborted": "N/A",
		"abort_reason": "N/A",
		"sail_sum": "N/A",
		## L4 transplant
		"cargo_dan_sum": "N/A",
		"season_sails": "N/A",
		## 17-69 5.2 / 5.3
		"season_sail_count": "N/A",
		"season_cargo_dan": "N/A",
		"trader_sails_total": "N/A",
		"trader_cargo_dan_total": "N/A",
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
			out["band0_n"] = "N/A"
			out["band4_n"] = "N/A"
			out["band_ok"] = "N/A"
		else:
			var edge := 0
			var b0 := 0
			var b4 := 0
			for c3_v in y5c:
				var bi2: int = _as_int((c3_v as Dictionary).get("band", -1))
				if bi2 == 0:
					b0 += 1
					edge += 1
				elif bi2 == 4:
					b4 += 1
					edge += 1
			var pct: float = 100.0 * float(edge) / float(maxi(n, 1))
			out["band04_pct"] = "%.1f" % pct
			out["band0_n"] = str(b0)
			out["band4_n"] = str(b4)
			out["band_ok"] = "PASS" if pct <= 30.0 else "FAIL"
	else:
		out["band04_pct"] = "N/A"
		out["band0_n"] = "N/A"
		out["band4_n"] = "N/A"
		out["band_ok"] = "N/A"
	## 17-72 C-v: aggregate new season_ports columns when present.
	if not ports.is_empty() and (ports[0] as Dictionary).has("beggar_gt_10"):
		var gt10 := 0
		var vj := 0
		var vb := 0
		for p_cv in ports:
			var pd: Dictionary = p_cv
			gt10 += _as_int(pd.get("beggar_gt_10", 0))
			vj += _as_int(pd.get("vacant_jobs", 0))
			vb += _as_int(pd.get("vacant_beds", 0))
		out["cv_ports_rows"] = str(ports.size())
		out["cv_beggar_gt_10_n"] = str(gt10)
		out["cv_vacant_jobs_sum"] = str(vj)
		out["cv_vacant_beds_sum"] = str(vb)
	if FileAccess.file_exists(summary_path):
		var sums: Array = _read_csv(summary_path)
		if not sums.is_empty():
			var s0: Dictionary = sums[0]
			out["aborted"] = String(s0.get("aborted", ""))
			out["abort_reason"] = String(s0.get("abort_reason", "")).replace("|", "/")
	if FileAccess.file_exists(trader_path):
		var sails := 0
		var cargo_total := 0
		var by_season: Dictionary = {} ## season_index:String → sails (L4)
		var traders: Array = _read_csv(trader_path)
		for t_v in traders:
			var td: Dictionary = t_v
			var sc: int = _as_int(td.get("sail_count", 0))
			sails += sc
			var si: String = String(td.get("season_index", ""))
			by_season[si] = int(by_season.get(si, 0)) + sc
			cargo_total += _cargo_dan_sum(td.get("cargo_dan_json", "{}"))
		out["sail_sum"] = str(sails)
		out["cargo_dan_sum"] = str(cargo_total)
		out["trader_sails_total"] = str(sails)
		out["trader_cargo_dan_total"] = str(cargo_total)
		var season_keys: Array = by_season.keys()
		season_keys.sort_custom(func(a, b): return _as_int(a) < _as_int(b))
		var parts: PackedStringArray = PackedStringArray()
		for sk in season_keys:
			parts.append("%s:%d" % [String(sk), int(by_season[sk])])
		out["season_sails"] = ",".join(parts) if not parts.is_empty() else "N/A"
		## 5.2: only exact column names season_sail_count / season_cargo_dan (not sail_count).
		out["season_sail_count"] = _column_sum_or_na(traders, "season_sail_count")
		out["season_cargo_dan"] = _column_cargo_or_na(traders, "season_cargo_dan")
	else:
		out["sail_sum"] = "N/A"
		out["cargo_dan_sum"] = "N/A"
		out["season_sails"] = "N/A"
		out["trader_sails_total"] = "N/A"
		out["trader_cargo_dan_total"] = "N/A"
	## Also accept season_* columns on season_ports (Lane4 may place them there).
	if out["season_sail_count"] == "N/A":
		out["season_sail_count"] = _column_sum_or_na(ports, "season_sail_count")
	if out["season_cargo_dan"] == "N/A":
		out["season_cargo_dan"] = _column_cargo_or_na(ports, "season_cargo_dan")
	return out


## 17-72 D1（D-127 甲）：種子獨立性須先證明指標對「非種子」擾動敏感，否則該檢查不計入驗收.
## 非種子擾動對照：Za_G0_A0 vs Zb_G0_notrader（商人開關）. 敏感＝至少一項 _SEED_METRIC_KEYS 不同.
func _append_d1_seed_gate(lines: PackedStringArray, rows: Array) -> void:
	lines.append("## D1 Seed-independence gate (D-127 rewrite)")
	lines.append("")
	var by_name: Dictionary = {}
	for st_v in rows:
		var st: Dictionary = st_v
		by_name[String(st["group"])] = st
	var sens_a := "Za_G0_A0"
	var sens_b := "Zb_G0_notrader"
	if not by_name.has(sens_a) or not by_name.has(sens_b):
		lines.append("- sensitivity probe `%s` vs `%s`: **N/A** (group missing)" % [sens_a, sens_b])
		lines.append("- D1 seed check: **not scored** (no sensitivity proof)")
		lines.append("")
		return
	var a0: Dictionary = by_name[sens_a]
	var b0: Dictionary = by_name[sens_b]
	if String(a0.get("status", "")) != "ok" or String(b0.get("status", "")) != "ok":
		lines.append(
			"- sensitivity probe: **N/A** (status %s / %s)" % [
				a0.get("status", ""), b0.get("status", "")
			]
		)
		lines.append("- D1 seed check: **not scored**")
		lines.append("")
		return
	var sens_differ: PackedStringArray = PackedStringArray()
	for key_v in _SEED_METRIC_KEYS:
		var key: String = String(key_v)
		var av: String = String(a0.get(key, "N/A"))
		var bv: String = String(b0.get(key, "N/A"))
		if av != bv and av != "N/A" and bv != "N/A":
			sens_differ.append("%s:%s≠%s" % [key, av, bv])
	if sens_differ.is_empty():
		lines.append(
			"- sensitivity probe `%s` vs `%s`: **INSENSITIVE** — metrics unchanged under traders on/off."
			% [sens_a, sens_b]
		)
		lines.append("- D1 seed check: **not scored** (D-127: constant metrics do not count)")
		lines.append("")
		return
	lines.append(
		"- sensitivity probe `%s` vs `%s`: **SENSITIVE** (%s)"
		% [sens_a, sens_b, ", ".join(sens_differ)]
	)
	## Seed pair only scored when sensitive.
	for pair_v in _SEED_PAIRS:
		var pair: Array = pair_v
		if pair.size() < 2:
			continue
		var a_name: String = String(pair[0])
		var b_name: String = String(pair[1])
		if not by_name.has(a_name) or not by_name.has(b_name):
			lines.append("- seed pair `%s` vs `%s`: skipped (missing)" % [a_name, b_name])
			continue
		var a: Dictionary = by_name[a_name]
		var b: Dictionary = by_name[b_name]
		var identical: PackedStringArray = PackedStringArray()
		var differ: PackedStringArray = PackedStringArray()
		for key2_v in _SEED_METRIC_KEYS:
			var key2: String = String(key2_v)
			var av2: String = String(a.get(key2, "N/A"))
			var bv2: String = String(b.get(key2, "N/A"))
			if av2 == bv2 and av2 != "N/A":
				identical.append("%s=%s" % [key2, av2])
			else:
				differ.append("%s:%s≠%s" % [key2, av2, bv2])
		if differ.is_empty() and not identical.is_empty():
			lines.append(
				"- seed pair `%s` vs `%s`: **FAIL** SEED_NO_EFFECT (all scored metrics identical)"
				% [a_name, b_name]
			)
		else:
			lines.append(
				"- seed pair `%s` vs `%s`: **PASS** (metrics differ or incomplete)"
				% [a_name, b_name]
			)
	lines.append("")


## 17-72 D2（D-127 甲）：商人有效性＝sail_count 總和 > 0「且」至少一項 MET／報告指標隨商人開關而變.
func _append_d2_trader_gate(lines: PackedStringArray, rows: Array) -> void:
	lines.append("## D2 Trader-effectiveness gate (D-127 rewrite)")
	lines.append("")
	var by_name: Dictionary = {}
	for st_v in rows:
		var st: Dictionary = st_v
		by_name[String(st["group"])] = st
	var with_t := "Za_G0_A0"
	var no_t := "Zb_G0_notrader"
	if not by_name.has(with_t) or not by_name.has(no_t):
		lines.append("- D2: **N/A** (need `%s` and `%s`)" % [with_t, no_t])
		lines.append("")
		return
	var a: Dictionary = by_name[with_t]
	var b: Dictionary = by_name[no_t]
	var sail_s: String = String(a.get("sail_sum", "N/A"))
	var sail_ok := false
	if sail_s != "N/A":
		sail_ok = _as_int(sail_s) > 0
	var met_moved: PackedStringArray = PackedStringArray()
	for key_v in _SEED_METRIC_KEYS:
		var key: String = String(key_v)
		var av: String = String(a.get(key, "N/A"))
		var bv: String = String(b.get(key, "N/A"))
		if av != bv and av != "N/A" and bv != "N/A":
			met_moved.append("%s:%s≠%s" % [key, av, bv])
	var moved_ok: bool = not met_moved.is_empty()
	lines.append("- `%s` sail_sum=%s → sail>0: **%s**" % [with_t, sail_s, "yes" if sail_ok else "no"])
	if moved_ok:
		lines.append("- traders on/off metric move: **yes** (%s)" % ", ".join(met_moved))
	else:
		lines.append("- traders on/off metric move: **no**")
	if sail_ok and moved_ok:
		lines.append("- D2: **PASS**")
	elif sail_s == "N/A" or String(a.get("status", "")) != "ok":
		lines.append("- D2: **N/A** (missing run data)")
	else:
		lines.append("- D2: **FAIL** (need sail_sum>0 AND ≥1 metric moves)")
	lines.append("")


## 17-69 5.1: emit SEED_NO_EFFECT when seed-only pair shares all ①②③④ metrics.
func _append_seed_no_effect(lines: PackedStringArray, rows: Array) -> void:
	lines.append("## SEED_NO_EFFECT check (seed-only pairs)")
	lines.append("")
	var by_name: Dictionary = {}
	for st_v in rows:
		var st: Dictionary = st_v
		by_name[String(st["group"])] = st
	var any_warn := false
	for pair_v in _SEED_PAIRS:
		var pair: Array = pair_v
		if pair.size() < 2:
			continue
		var a_name: String = String(pair[0])
		var b_name: String = String(pair[1])
		if not by_name.has(a_name) or not by_name.has(b_name):
			lines.append("- pair `%s` vs `%s`: skipped (group missing)" % [a_name, b_name])
			continue
		var a: Dictionary = by_name[a_name]
		var b: Dictionary = by_name[b_name]
		if String(a.get("status", "")) != "ok" or String(b.get("status", "")) != "ok":
			lines.append(
				"- pair `%s` vs `%s`: skipped (status %s / %s)" % [
					a_name, b_name, a.get("status", ""), b.get("status", "")
				]
			)
			continue
		var identical: PackedStringArray = PackedStringArray()
		var differ: PackedStringArray = PackedStringArray()
		for key_v in _SEED_METRIC_KEYS:
			var key: String = String(key_v)
			var av: String = String(a.get(key, "N/A"))
			var bv: String = String(b.get(key, "N/A"))
			if av == bv and av != "N/A":
				identical.append("%s=%s" % [key, av])
			elif av == bv and av == "N/A":
				## Both missing — not a positive identity proof; treat as not comparable.
				differ.append("%s=N/A" % key)
			else:
				differ.append("%s:%s≠%s" % [key, av, bv])
		if differ.is_empty() and not identical.is_empty():
			any_warn = true
			lines.append(
				"**WARNING: SEED_NO_EFFECT** — `%s` vs `%s` (seed-only): all ①②③④ metrics identical."
				% [a_name, b_name]
			)
			lines.append("")
			lines.append("Identical columns: %s" % ", ".join(identical))
			lines.append("")
		else:
			lines.append(
				"- pair `%s` vs `%s`: metrics differ or incomplete (no SEED_NO_EFFECT)."
				% [a_name, b_name]
			)
			if not identical.is_empty():
				lines.append("  - identical: %s" % ", ".join(identical))
			if not differ.is_empty():
				lines.append("  - differ/N/A: %s" % ", ".join(differ))
	if not any_warn:
		lines.append("")
		lines.append("_No SEED_NO_EFFECT warning emitted._")
	lines.append("")


## Sum numeric column if header present in any row; else N/A (T3 — never PASS/FAIL).
func _column_sum_or_na(rows: Array, col: String) -> String:
	if rows.is_empty():
		return "N/A"
	var has := false
	var total := 0
	for r_v in rows:
		var r: Dictionary = r_v
		if r.has(col):
			has = true
			total += _as_int(r.get(col, 0))
	return str(total) if has else "N/A"


## Sum cargo column: Dictionary JSON or numeric; missing → N/A.
func _column_cargo_or_na(rows: Array, col: String) -> String:
	if rows.is_empty():
		return "N/A"
	var has := false
	var total := 0
	for r_v in rows:
		var r: Dictionary = r_v
		if not r.has(col):
			continue
		has = true
		var raw: Variant = r.get(col, "")
		var s: String = String(raw).strip_edges()
		if s.begins_with("{") or s.begins_with("["):
			total += _cargo_dan_sum(s)
		else:
			total += _as_int(raw)
	return str(total) if has else "N/A"


func _cargo_dan_sum(raw: Variant) -> int:
	var s: String = String(raw).strip_edges()
	if s.is_empty() or s == "{}":
		return 0
	var parsed: Variant = JSON.parse_string(s)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var total := 0
	var d: Dictionary = parsed
	for k in d.keys():
		total += _as_int(d[k])
	return total


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
