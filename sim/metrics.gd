class_name SimMetrics
extends RefCounted
## FRM-SYS23-07／08／09 — MET-01..06, OBS-01..03 (WP-26). Missing threshold → pass N/A.


const PASS_NA := "N/A"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


static func compute(
	sampler: SimSampler,
	warmup_years: int,
	years: int,
	thresholds: Dictionary,
	aborted: bool,
	abort_reason: String,
	elapsed_ms: int,
	run_id: int,
	combo_index: int,
	seed: int,
	combo: Dictionary
) -> Dictionary:
	var seasons_y: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	var warmup_seasons: int = warmup_years * seasons_y
	var eval_cells: Array = []
	for row_v in sampler.season_cells:
		var row: Dictionary = row_v
		if int(row["season_index"]) >= warmup_seasons:
			eval_cells.append(row)
	var eval_ports: Array = []
	for row_v in sampler.season_ports:
		var row2: Dictionary = row_v
		if int(row2["season_index"]) >= warmup_seasons:
			eval_ports.append(row2)

	var met01: Dictionary = _met01(eval_cells, thresholds)
	var met02: Dictionary = _met02(eval_cells, thresholds, seasons_y)
	var met03: Dictionary = _met03(eval_ports, thresholds, seasons_y)
	var met04: Dictionary = _met04(eval_ports, thresholds, seasons_y)
	var met05: Dictionary = _met05(eval_ports, thresholds, seasons_y)
	var met06: Dictionary = _met06(sampler.conservation_hits, aborted)
	var obs01: String = _obs01(eval_ports)
	var obs02: String = _obs02(eval_ports)
	var obs03: String = "0" ## OBS-03 precise lock definition pending WP-21; record 0.

	return {
		"run_id": run_id,
		"combo_index": combo_index,
		"seed": seed,
		"combo": JSON.stringify(combo),
		"aborted": 1 if aborted else 0,
		"abort_reason": abort_reason,
		"MET-01": met01["value"],
		"MET-01_pass": met01["pass"],
		"MET-02": met02["value"],
		"MET-02_pass": met02["pass"],
		"MET-03": met03["value"],
		"MET-03_pass": met03["pass"],
		"MET-04": met04["value"],
		"MET-04_pass": met04["pass"],
		"MET-05a": met05["a"],
		"MET-05a_pass": met05["a_pass"],
		"MET-05b": met05["b"],
		"MET-05b_pass": met05["b_pass"],
		"MET-06": met06["value"],
		"MET-06_pass": met06["pass"],
		"OBS-01": obs01,
		"OBS-02": obs02,
		"OBS-03": obs03,
		"elapsed_ms": elapsed_ms,
	}


static func aggregate_combos(summaries: Array) -> Array:
	## FRM-SYS23-09 — per combo_index: MET avg／min／max + combo_pass.
	var by_combo: Dictionary = {}
	for s_v in summaries:
		var s: Dictionary = s_v
		var ci: int = int(s["combo_index"])
		if not by_combo.has(ci):
			by_combo[ci] = []
		(by_combo[ci] as Array).append(s)
	var keys: Array = by_combo.keys()
	keys.sort()
	var rows: Array = []
	for ci_v in keys:
		var ci2: int = int(ci_v)
		var group: Array = by_combo[ci2]
		var combo_s: String = String((group[0] as Dictionary)["combo"])
		var row := {
			"combo_index": ci2,
			"combo": combo_s,
		}
		var all_pass := true
		var any_na := false
		for met_id in ["MET-01", "MET-02", "MET-03", "MET-04", "MET-05a", "MET-05b", "MET-06"]:
			var vals: Array = []
			for g in group:
				vals.append(float((g as Dictionary)[met_id]))
			row["%s_avg" % met_id] = _avg(vals)
			row["%s_min" % met_id] = _minv(vals)
			row["%s_max" % met_id] = _maxv(vals)
			for g2 in group:
				var p: String = String((g2 as Dictionary).get("%s_pass" % met_id, PASS_NA))
				if p == PASS_NA:
					any_na = true
				elif p != "1":
					all_pass = false
		if any_na:
			row["combo_pass"] = PASS_NA
		elif all_pass:
			row["combo_pass"] = "1"
		else:
			row["combo_pass"] = "0"
		rows.append(row)
	return rows


static func _met01(cells: Array, th: Dictionary) -> Dictionary:
	var total: int = 0
	var eq: int = 0
	for c_v in cells:
		var c: Dictionary = c_v
		## weekly_consumption proxy: stock_weeks blank ⇒ weekly was 0 (skip).
		if String(c["stock_weeks"]) == "":
			continue
		total = total + 1
		if int(c["band"]) == MarketPricer.BAND_EQUILIBRIUM:
			eq = eq + 1
	var ratio: float = 0.0
	if total > 0:
		ratio = float(eq) / float(total)
	return _pass_ge(ratio, th, "TH-01")


static func _met02(cells: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	## Group by port|good; first eval year avg weeks vs last year.
	var by_cell: Dictionary = {}
	for c_v in cells:
		var c: Dictionary = c_v
		if String(c["stock_weeks"]) == "":
			continue
		var k: String = "%s|%s" % [c["port_id"], c["good_id"]]
		if not by_cell.has(k):
			by_cell[k] = []
		(by_cell[k] as Array).append(c)
	var diverged: int = 0
	var th02: Variant = th.get("TH-02", null)
	for k_v in by_cell.keys():
		var rows: Array = by_cell[k_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["season_index"]) < int(b["season_index"])
		)
		if rows.is_empty():
			continue
		var first_si: int = int((rows[0] as Dictionary)["season_index"])
		var last_si: int = int((rows[rows.size() - 1] as Dictionary)["season_index"])
		var first_year_end: int = first_si + seasons_y
		var last_year_start: int = last_si - seasons_y + 1
		var first_sum: float = 0.0
		var first_n: int = 0
		var last_sum: float = 0.0
		var last_n: int = 0
		for r_v in rows:
			var r: Dictionary = r_v
			var si: int = int(r["season_index"])
			var w: float = float(r["stock_weeks"])
			if si < first_year_end:
				first_sum = first_sum + w
				first_n = first_n + 1
			if si >= last_year_start:
				last_sum = last_sum + w
				last_n = last_n + 1
		var first_avg: float = 0.0
		if first_n > 0:
			first_avg = first_sum / float(first_n)
		var last_avg: float = 0.0
		if last_n > 0:
			last_avg = last_sum / float(last_n)
		if first_avg == 0.0:
			continue ## 「由零起」— excluded from > TH-02 count per 9.8
		var ratio: float = last_avg / first_avg
		if th02 != null and ratio > float(th02):
			diverged = diverged + 1
	var pass_s := PASS_NA
	if th.has("TH-02"):
		pass_s = "1" if diverged == 0 else "0"
	return {"value": float(diverged), "pass": pass_s}


static func _met03(ports: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	var by_port: Dictionary = _group_ports(ports)
	var worst: float = 0.0
	for pid_v in by_port.keys():
		var rows: Array = by_port[pid_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["season_index"]) < int(b["season_index"])
		)
		if rows.is_empty():
			continue
		var last: Dictionary = rows[rows.size() - 1]
		var last_si: int = int(last["season_index"])
		var year_start_si: int = last_si - seasons_y + 1
		var first_of_last_year: Dictionary = last
		for r_v in rows:
			var r: Dictionary = r_v
			if int(r["season_index"]) == year_start_si:
				first_of_last_year = r
				break
		var pop_last: int = _total_pop(last)
		var pop_first: int = _total_pop(first_of_last_year)
		if pop_first <= 0:
			continue
		var delta: float = absf(float(pop_last - pop_first)) / float(pop_first)
		if delta > worst:
			worst = delta
	return _pass_le(worst, th, "TH-03")


static func _met04(ports: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	var by_port: Dictionary = _group_ports(ports)
	var worst: float = 0.0
	for pid_v in by_port.keys():
		var rows: Array = by_port[pid_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["season_index"]) < int(b["season_index"])
		)
		if rows.is_empty():
			continue
		var last_si: int = int((rows[rows.size() - 1] as Dictionary)["season_index"])
		var year_start: int = last_si - seasons_y + 1
		var mn: int = 0
		var mx: int = 0
		var init := false
		for r_v in rows:
			var r: Dictionary = r_v
			if int(r["season_index"]) < year_start:
				continue
			var sat: int = int(r["sat_weighted"])
			if not init:
				mn = sat
				mx = sat
				init = true
			else:
				if sat < mn:
					mn = sat
				if sat > mx:
					mx = sat
		var span: float = float(mx - mn)
		if span > worst:
			worst = span
	return _pass_le(worst, th, "TH-04")


static func _met05(ports: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	var by_port: Dictionary = _group_ports(ports)
	var longest_zero: int = 0
	var worst_growth: float = 0.0
	for pid_v in by_port.keys():
		var rows: Array = by_port[pid_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["season_index"]) < int(b["season_index"])
		)
		var streak: int = 0
		var best_streak: int = 0
		for r_v in rows:
			var bal: int = int((r_v as Dictionary)["city_balance_li"])
			if bal == 0:
				streak = streak + 1
				if streak > best_streak:
					best_streak = streak
			else:
				streak = 0
		if best_streak > longest_zero:
			longest_zero = best_streak
		if rows.is_empty():
			continue
		var last: Dictionary = rows[rows.size() - 1]
		var last_si: int = int(last["season_index"])
		var year_start: int = last_si - seasons_y + 1
		var first: Dictionary = last
		for r2_v in rows:
			var r2: Dictionary = r2_v
			if int(r2["season_index"]) == year_start:
				first = r2
				break
		var b0: int = int(first["city_balance_li"])
		var b1: int = int(last["city_balance_li"])
		var growth: float = 0.0
		if b0 != 0:
			growth = float(b1) / float(b0)
		if growth > worst_growth:
			worst_growth = growth
	var a_pass := PASS_NA
	var b_pass := PASS_NA
	if th.has("TH-05a"):
		a_pass = "1" if longest_zero <= int(th["TH-05a"]) else "0"
	if th.has("TH-05b"):
		b_pass = "1" if worst_growth <= float(th["TH-05b"]) else "0"
	return {
		"a": float(longest_zero),
		"a_pass": a_pass,
		"b": worst_growth,
		"b_pass": b_pass,
	}


static func _met06(hits: int, aborted: bool) -> Dictionary:
	## Hard: pass iff hits == 0 (and not aborted for conservation).
	var ok: bool = hits == 0
	return {"value": float(hits), "pass": "1" if ok else "0"}


static func _obs01(ports: Array) -> String:
	## First season_index per port where city_balance >= any public L2 fee; blank if never.
	## Requires BuildingEconomy loaded (public_upgrade_fee assert); else blank per port.
	var by_port: Dictionary = _group_ports(ports)
	var parts: PackedStringArray = PackedStringArray()
	var pids: Array = by_port.keys()
	pids.sort()
	var be_ready: bool = BuildingEconomy.is_loaded()
	for pid_v in pids:
		var pid: String = String(pid_v)
		var rows: Array = by_port[pid]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["season_index"]) < int(b["season_index"])
		)
		var found := ""
		if be_ready:
			for r_v in rows:
				var r: Dictionary = r_v
				var fee: Dictionary = BuildingEconomy.public_upgrade_fee(StringName(pid), 1 + 1)
				var need: int = int(fee.get("CASH_LI", 0))
				if need > 0 and int(r["city_balance_li"]) >= need:
					found = str(int(r["season_index"]))
					break
		parts.append("%s:%s" % [pid, found])
	return ";".join(parts)


static func _obs02(ports: Array) -> String:
	var by_port: Dictionary = _group_ports(ports)
	var worst: float = 0.0
	for pid_v in by_port.keys():
		for r_v in by_port[pid_v]:
			var r: Dictionary = r_v
			var tot: int = _total_pop(r) + int(r["beggar"])
			if tot <= 0:
				continue
			var ratio: float = float(r["beggar"]) / float(tot)
			if ratio > worst:
				worst = ratio
	return str(worst)


static func _group_ports(ports: Array) -> Dictionary:
	var by_port: Dictionary = {}
	for r_v in ports:
		var r: Dictionary = r_v
		var pid: String = String(r["port_id"])
		if not by_port.has(pid):
			by_port[pid] = []
		(by_port[pid] as Array).append(r)
	return by_port


static func _total_pop(r: Dictionary) -> int:
	return int(r["poor"]) + int(r["citizen"]) + int(r["rich"])


static func _pass_ge(value: float, th: Dictionary, key: String) -> Dictionary:
	var pass_s := PASS_NA
	if th.has(key):
		pass_s = "1" if value >= float(th[key]) else "0"
	return {"value": value, "pass": pass_s}


static func _pass_le(value: float, th: Dictionary, key: String) -> Dictionary:
	var pass_s := PASS_NA
	if th.has(key):
		pass_s = "1" if value <= float(th[key]) else "0"
	return {"value": value, "pass": pass_s}


static func _avg(vals: Array) -> float:
	if vals.is_empty():
		return 0.0
	var s: float = 0.0
	for v in vals:
		s = s + float(v)
	return s / float(vals.size())


static func _minv(vals: Array) -> float:
	if vals.is_empty():
		return 0.0
	var m: float = float(vals[0])
	for v in vals:
		var f: float = float(v)
		if f < m:
			m = f
	return m


static func _maxv(vals: Array) -> float:
	if vals.is_empty():
		return 0.0
	var m: float = float(vals[0])
	for v in vals:
		var f: float = float(v)
		if f > m:
			m = f
	return m
