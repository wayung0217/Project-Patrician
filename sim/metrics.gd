class_name SimMetrics
extends RefCounted
## FRM-SYS23-07／08／09 — MET-01..06, OBS-01..03 (WP-26); OBS-02／04／05＋TH-01b (WP-27／D-93).
## Missing threshold → pass N/A. MET-02 stock_weeks already MARKET-only (D-52b／D-93).


const PASS_NA := "N/A"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
## D-93／OBS-02: consecutive zero-beggar seasons ≥ this → labour-shortage warning (record only).
const OBS02_ZERO_STREAK_WARN := 4


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
	combo: Dictionary,
	scenario_id: String = ""
) -> Dictionary:
	var seasons_y: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	var warmup_seasons: int = warmup_years * seasons_y
	var eval_cells: Array = []
	for row_v in sampler.season_cells:
		var row: Dictionary = row_v
		if _json_int(row["season_index"]) >= warmup_seasons:
			eval_cells.append(row)
	var eval_ports: Array = []
	for row_v in sampler.season_ports:
		var row2: Dictionary = row_v
		if _json_int(row2["season_index"]) >= warmup_seasons:
			eval_ports.append(row2)

	var met01: Dictionary = _met01(eval_cells, thresholds)
	var met02: Dictionary = _met02(eval_cells, thresholds, seasons_y)
	var met03: Dictionary = _met03(eval_ports, thresholds, seasons_y)
	var met04: Dictionary = _met04(eval_ports, thresholds, seasons_y)
	var met05: Dictionary = _met05(eval_ports, thresholds, seasons_y)
	var met06: Dictionary = _met06(sampler.conservation_hits, aborted)
	var obs01: String = _obs01(eval_ports)
	var obs02_pack: Dictionary = _obs02(eval_ports)
	var obs02: Variant = obs02_pack["max_ratio"]
	## OBS-03 precise lock definition pending WP-21 (9.5 K) — no value → blank, not "0".
	var obs03: String = ""
	var obs_ext: Array = []
	if not aborted:
		obs_ext.append_array(
			_obs02_ext_rows(
				scenario_id, combo_index, seed, obs02_pack.get("streaks", {})
			)
		)
		obs_ext.append_array(
			_obs04_rows(
				scenario_id,
				combo_index,
				seed,
				eval_cells,
				met02.get("diverged_keys", []),
				thresholds,
				seasons_y
			)
		)
		obs_ext.append_array(
			_obs05_rows(scenario_id, combo_index, seed, eval_ports)
		)
		sampler.obs_ext_rows.append_array(obs_ext)

	## Abort path: MET-01..05b no value → blank + pass N/A; MET-06 only if measured hits.
	var met01_v: Variant = met01["value"]
	var met01_p: String = String(met01["pass"])
	var met02_v: Variant = met02["value"]
	var met02_p: String = String(met02["pass"])
	var met03_v: Variant = met03["value"]
	var met03_p: String = String(met03["pass"])
	var met04_v: Variant = met04["value"]
	var met04_p: String = String(met04["pass"])
	var met05a_v: Variant = met05["a"]
	var met05a_p: String = String(met05["a_pass"])
	var met05b_v: Variant = met05["b"]
	var met05b_p: String = String(met05["b_pass"])
	var met06_v: Variant = met06["value"]
	var met06_p: String = String(met06["pass"])
	if aborted:
		met01_v = ""
		met01_p = PASS_NA
		met02_v = ""
		met02_p = PASS_NA
		met03_v = ""
		met03_p = PASS_NA
		met04_v = ""
		met04_p = PASS_NA
		met05a_v = ""
		met05a_p = PASS_NA
		met05b_v = ""
		met05b_p = PASS_NA
		if sampler.conservation_hits > 0:
			met06_v = float(sampler.conservation_hits)
			met06_p = "0"
		else:
			met06_v = ""
			met06_p = PASS_NA

	return {
		"run_id": run_id,
		"combo_index": combo_index,
		"seed": seed,
		"combo": JSON.stringify(combo),
		"aborted": 1 if aborted else 0,
		"abort_reason": abort_reason,
		"MET-01": met01_v,
		"MET-01_pass": met01_p,
		"MET-02": met02_v,
		"MET-02_pass": met02_p,
		"MET-03": met03_v,
		"MET-03_pass": met03_p,
		"MET-04": met04_v,
		"MET-04_pass": met04_p,
		"MET-05a": met05a_v,
		"MET-05a_pass": met05a_p,
		"MET-05b": met05b_v,
		"MET-05b_pass": met05b_p,
		"MET-06": met06_v,
		"MET-06_pass": met06_p,
		"OBS-01": obs01,
		"OBS-02": obs02,
		"OBS-03": obs03,
		"elapsed_ms": elapsed_ms,
		"obs_ext": obs_ext,
	}


static func aggregate_combos(summaries: Array) -> Array:
	## FRM-SYS23-09 — per combo_index: MET avg／min／max + combo_pass.
	## Aborted runs excluded from avg／min／max; all-aborted → blanks (not 0).
	var by_combo: Dictionary = {}
	for s_v in summaries:
		var s: Dictionary = s_v
		var ci: int = _json_int(s["combo_index"])
		if not by_combo.has(ci):
			by_combo[ci] = []
		(by_combo[ci] as Array).append(s)
	var keys: Array = by_combo.keys()
	keys.sort()
	var rows: Array = []
	for ci_v in keys:
		var ci2: int = _json_int(ci_v)
		var group: Array = by_combo[ci2]
		var combo_s: String = String((group[0] as Dictionary)["combo"])
		var row := {
			"combo_index": ci2,
			"combo": combo_s,
		}
		var all_pass := true
		var any_na := false
		var any_alive := false
		for met_id in ["MET-01", "MET-02", "MET-03", "MET-04", "MET-05a", "MET-05b", "MET-06"]:
			var vals: Array = []
			for g in group:
				var gd: Dictionary = g as Dictionary
				if _json_int(gd.get("aborted", 0)) == 1:
					continue
				any_alive = true
				var raw: Variant = gd[met_id]
				if typeof(raw) == TYPE_STRING and String(raw) == "":
					continue
				vals.append(float(raw))
			if vals.is_empty():
				row["%s_avg" % met_id] = ""
				row["%s_min" % met_id] = ""
				row["%s_max" % met_id] = ""
			else:
				row["%s_avg" % met_id] = _avg(vals)
				row["%s_min" % met_id] = _minv(vals)
				row["%s_max" % met_id] = _maxv(vals)
			## D-93／WP-27: MET-05b never judges pass — exclude from combo_pass.
			if met_id == "MET-05b":
				continue
			for g2 in group:
				var gd2: Dictionary = g2 as Dictionary
				if _json_int(gd2.get("aborted", 0)) == 1:
					continue
				var p: String = String(gd2.get("%s_pass" % met_id, PASS_NA))
				if p == PASS_NA:
					any_na = true
				elif p != "1":
					all_pass = false
		if not any_alive:
			row["combo_pass"] = PASS_NA
		elif any_na:
			row["combo_pass"] = PASS_NA
		elif all_pass:
			row["combo_pass"] = "1"
		else:
			row["combo_pass"] = "0"
		rows.append(row)
	return rows


static func _json_int(v: Variant) -> int:
	## C-06：JSON／Variant 整數還原；非整數報錯（不靜默 floori）。
	return SimJsonInt.as_int(v, "metrics_json_int")


static func _met01(cells: Array, th: Dictionary) -> Dictionary:
	## 9.8 分母＝weekly_offtake>0 的 (港,貨)×評估季格數；無樣本 → 空白（D-52c）。
	## D-93／WP-27: TH-01 ≤ ratio ≤ TH-01b.
	var total: int = 0
	var eq: int = 0
	for c_v in cells:
		var c: Dictionary = c_v
		## weekly_consumption proxy: stock_weeks blank ⇒ weekly was 0 (skip).
		if String(c["stock_weeks"]) == "":
			continue
		total = total + 1
		if _json_int(c["band"]) == MarketPricer.BAND_EQUILIBRIUM:
			eq = eq + 1
	if total == 0:
		return {"value": "", "pass": PASS_NA}
	var ratio: float = float(eq) / float(total)
	return _pass_between(ratio, th, "TH-01", "TH-01b")


static func _met02(cells: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	## 9.8 分母＝可算比值的 (港,貨) 格（第一評估年平均週數≠0）；無樣本 → 空白（D-52c）。
	## D-93: stock_weeks from MARKET only (sampler／MarketPricer already MARKET).
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
	var diverged_keys: Array = []
	var sampled: int = 0
	var th02: Variant = th.get("TH-02", null)
	var cell_keys: Array = by_cell.keys()
	cell_keys.sort()
	for k_v in cell_keys:
		var rows: Array = by_cell[k_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _json_int(a["season_index"]) < _json_int(b["season_index"])
		)
		if rows.is_empty():
			continue
		var first_si: int = _json_int((rows[0] as Dictionary)["season_index"])
		var last_si: int = _json_int((rows[rows.size() - 1] as Dictionary)["season_index"])
		var first_year_end: int = first_si + seasons_y
		var last_year_start: int = last_si - seasons_y + 1
		var first_sum: float = 0.0
		var first_n: int = 0
		var last_sum: float = 0.0
		var last_n: int = 0
		for r_v in rows:
			var r: Dictionary = r_v
			var si: int = _json_int(r["season_index"])
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
		sampled = sampled + 1
		var ratio: float = last_avg / first_avg
		if th02 != null and ratio > float(th02):
			diverged = diverged + 1
			diverged_keys.append(String(k_v))
	if sampled == 0:
		return {"value": "", "pass": PASS_NA, "diverged_keys": []}
	var pass_s := PASS_NA
	if th.has("TH-02"):
		pass_s = "1" if diverged == 0 else "0"
	return {"value": float(diverged), "pass": pass_s, "diverged_keys": diverged_keys}


static func _met03(ports: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	## 9.8 分母＝最後一年第一季總人口>0 的港；無樣本 → 空白（D-52c）。
	var by_port: Dictionary = _group_ports(ports)
	var worst: float = 0.0
	var sampled: int = 0
	for pid_v in by_port.keys():
		var rows: Array = by_port[pid_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _json_int(a["season_index"]) < _json_int(b["season_index"])
		)
		if rows.is_empty():
			continue
		var last: Dictionary = rows[rows.size() - 1]
		var last_si: int = _json_int(last["season_index"])
		var year_start_si: int = last_si - seasons_y + 1
		var first_of_last_year: Dictionary = last
		for r_v in rows:
			var r: Dictionary = r_v
			if _json_int(r["season_index"]) == year_start_si:
				first_of_last_year = r
				break
		var pop_last: int = _total_pop(last)
		var pop_first: int = _total_pop(first_of_last_year)
		if pop_first <= 0:
			continue
		sampled = sampled + 1
		var delta: float = absf(float(pop_last - pop_first)) / float(pop_first)
		if delta > worst:
			worst = delta
	if sampled == 0:
		return {"value": "", "pass": PASS_NA}
	return _pass_le(worst, th, "TH-03")


static func _met04(ports: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	## 9.8 分母＝最後一年有 sat 樣本的港；無樣本 → 空白（D-52c）。
	var by_port: Dictionary = _group_ports(ports)
	var worst: float = 0.0
	var sampled: int = 0
	for pid_v in by_port.keys():
		var rows: Array = by_port[pid_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _json_int(a["season_index"]) < _json_int(b["season_index"])
		)
		if rows.is_empty():
			continue
		var last_si: int = _json_int((rows[rows.size() - 1] as Dictionary)["season_index"])
		var year_start: int = last_si - seasons_y + 1
		var mn: int = 0
		var mx: int = 0
		var init := false
		for r_v in rows:
			var r: Dictionary = r_v
			if _json_int(r["season_index"]) < year_start:
				continue
			var sat: int = _json_int(r["sat_weighted"])
			if not init:
				mn = sat
				mx = sat
				init = true
			else:
				if sat < mn:
					mn = sat
				if sat > mx:
					mx = sat
		if not init:
			continue
		sampled = sampled + 1
		var span: float = float(mx - mn)
		if span > worst:
			worst = span
	if sampled == 0:
		return {"value": "", "pass": PASS_NA}
	return _pass_le(worst, th, "TH-04")


static func _met05(ports: Array, th: Dictionary, seasons_y: int) -> Dictionary:
	## 9.8 分母＝有季表的 CITY／港；無港樣本 → a／b 空白（D-52c）。實測 0 保留。
	var by_port: Dictionary = _group_ports(ports)
	if by_port.is_empty():
		return {"a": "", "a_pass": PASS_NA, "b": "", "b_pass": PASS_NA}
	var longest_zero: int = 0
	var worst_growth: float = 0.0
	for pid_v in by_port.keys():
		var rows: Array = by_port[pid_v]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _json_int(a["season_index"]) < _json_int(b["season_index"])
		)
		var streak: int = 0
		var best_streak: int = 0
		for r_v in rows:
			var bal: int = _json_int((r_v as Dictionary)["city_balance_li"])
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
		var last_si: int = _json_int(last["season_index"])
		var year_start: int = last_si - seasons_y + 1
		var first: Dictionary = last
		for r2_v in rows:
			var r2: Dictionary = r2_v
			if _json_int(r2["season_index"]) == year_start:
				first = r2
				break
		var b0: int = _json_int(first["city_balance_li"])
		var b1: int = _json_int(last["city_balance_li"])
		var growth: float = 0.0
		if b0 != 0:
			growth = float(b1) / float(b0)
		if growth > worst_growth:
			worst_growth = growth
	var a_pass := PASS_NA
	## D-93／WP-27 MET-05(b): value only, never judge pass (TH-05b cancelled).
	var b_pass := PASS_NA
	if th.has("TH-05a"):
		a_pass = "1" if longest_zero <= _json_int(th["TH-05a"]) else "0"
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
			return _json_int(a["season_index"]) < _json_int(b["season_index"])
		)
		var found := ""
		if be_ready:
			for r_v in rows:
				var r: Dictionary = r_v
				var fee: Dictionary = BuildingEconomy.public_upgrade_fee(
					StringName(pid), BuildingEconomy.BUILDING_LEVEL_MIN + 1
				) ## EX-03 first upgrade target L2
				var need: int = _json_int(fee.get("CASH_LI", 0))
				if need > 0 and _json_int(r["city_balance_li"]) >= need:
					found = str(_json_int(r["season_index"]))
					break
		parts.append("%s:%s" % [pid, found])
	return ";".join(parts)


static func _obs02(ports: Array) -> Dictionary:
	## 9.8：評估期每港每季乞丐÷總人口之最大值。無港／無有效人口樣本 → 空白（D-52c）。
	## D-93／WP-27: also longest consecutive zero-beggar seasons per port.
	var by_port: Dictionary = _group_ports(ports)
	var worst: float = 0.0
	var sampled: int = 0
	var streaks: Dictionary = {}
	var pids: Array = by_port.keys()
	pids.sort()
	for pid_v in pids:
		var pid: String = String(pid_v)
		var rows: Array = by_port[pid]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _json_int(a["season_index"]) < _json_int(b["season_index"])
		)
		var streak: int = 0
		var best_streak: int = 0
		for r_v in rows:
			var r: Dictionary = r_v
			var beggar: int = _json_int(r["beggar"])
			var tot: int = _total_pop(r) + beggar
			if tot > 0:
				sampled = sampled + 1
				var ratio: float = float(beggar) / float(tot)
				if ratio > worst:
					worst = ratio
			if beggar == 0:
				streak = streak + 1
				if streak > best_streak:
					best_streak = streak
			else:
				streak = 0
		streaks[pid] = best_streak
	if sampled == 0:
		return {"max_ratio": "", "streaks": streaks}
	return {"max_ratio": worst, "streaks": streaks}


static func _obs02_ext_rows(
	scenario_id: String, combo_index: int, seed: int, streaks: Dictionary
) -> Array:
	var rows: Array = []
	var pids: Array = streaks.keys()
	pids.sort()
	for pid_v in pids:
		var pid: String = String(pid_v)
		var streak_i: int = _json_int(streaks[pid])
		rows.append(_obs_ext_row(
			scenario_id, combo_index, seed, -1, pid, "",
			"OBS-02", "longest_zero_beggar_streak", streak_i
		))
		if streak_i >= OBS02_ZERO_STREAK_WARN:
			rows.append(_obs_ext_row(
				scenario_id, combo_index, seed, -1, pid, "",
				"OBS-02", "zero_beggar_warn", 1
			))
	return rows


static func _obs04_rows(
	scenario_id: String,
	combo_index: int,
	seed: int,
	cells: Array,
	diverged_keys: Array,
	th: Dictionary,
	seasons_y: int
) -> Array:
	## D-93 OBS-04: for each MET-02 diverged (p,g), classify by global R_g vs TH-02.
	if diverged_keys.is_empty():
		return []
	var th02: float = float(th.get("TH-02", 0))
	## Build per-good per-season S／W from MARKET stock + sampled potential.
	var by_good_season: Dictionary = {} ## good -> season -> {S, W}
	for c_v in cells:
		var c: Dictionary = c_v
		var gid: String = String(c["good_id"])
		var si: int = _json_int(c["season_index"])
		if not by_good_season.has(gid):
			by_good_season[gid] = {}
		var by_si: Dictionary = by_good_season[gid]
		if not by_si.has(si):
			by_si[si] = {"S": 0, "W": 0}
		var bucket: Dictionary = by_si[si]
		bucket["S"] = _json_int(bucket["S"]) + _json_int(c["stock"])
		bucket["W"] = _json_int(bucket["W"]) + _json_int(c.get("_weekly_potential", 0))
		by_si[si] = bucket
		by_good_season[gid] = by_si

	var rows: Array = []
	var keys_sorted: Array = diverged_keys.duplicate()
	keys_sorted.sort()
	for k_v in keys_sorted:
		var k: String = String(k_v)
		var parts: PackedStringArray = k.split("|")
		if parts.size() != 2:
			continue
		var pid: String = parts[0]
		var gid2: String = parts[1]
		var by_si2: Dictionary = by_good_season.get(gid2, {})
		var seasons: Array = by_si2.keys()
		seasons.sort()
		if seasons.is_empty():
			continue
		var first_si: int = _json_int(seasons[0])
		var last_si: int = _json_int(seasons[seasons.size() - 1])
		var first_year_end: int = first_si + seasons_y
		var last_year_start: int = last_si - seasons_y + 1
		var first_sum: float = 0.0
		var first_n: int = 0
		var last_sum: float = 0.0
		var last_n: int = 0
		for si_v in seasons:
			var si2: int = _json_int(si_v)
			var b: Dictionary = by_si2[si2]
			var W: int = _json_int(b["W"])
			if W <= 0:
				continue
			var weeks_g: float = float(_json_int(b["S"])) / float(W)
			if si2 < first_year_end:
				first_sum = first_sum + weeks_g
				first_n = first_n + 1
			if si2 >= last_year_start:
				last_sum = last_sum + weeks_g
				last_n = last_n + 1
		var cause: String = "分配不足（運力或路線）"
		var r_g: float = 0.0
		if first_n > 0 and last_n > 0:
			var first_avg: float = first_sum / float(first_n)
			if first_avg > 0.0:
				r_g = (last_sum / float(last_n)) / first_avg
				if r_g > th02:
					cause = "供給過剩"
		rows.append(_obs_ext_row(
			scenario_id, combo_index, seed, -1, pid, gid2,
			"OBS-04", "cause", cause
		))
		rows.append(_obs_ext_row(
			scenario_id, combo_index, seed, -1, pid, gid2,
			"OBS-04", "R_g", r_g
		))
	return rows


static func _obs05_rows(
	scenario_id: String, combo_index: int, seed: int, ports: Array
) -> Array:
	## D-93 OBS-05: CITY spend breakdown + closing balance.
	## Spend categories (建設／城防／抽調／其他) require BuildingEconomy public query — gap.
	## Emit city_balance_li per season; note gap keys once per port.
	var rows: Array = []
	var by_port: Dictionary = _group_ports(ports)
	var pids: Array = by_port.keys()
	pids.sort()
	for pid_v in pids:
		var pid: String = String(pid_v)
		rows.append(_obs_ext_row(
			scenario_id, combo_index, seed, -1, pid, "",
			"OBS-05", "gap_spend_breakdown",
			"no_public_BuildingEconomy_city_spend_by_category"
		))
		var port_rows: Array = by_port[pid]
		port_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _json_int(a["season_index"]) < _json_int(b["season_index"])
		)
		for r_v in port_rows:
			var r: Dictionary = r_v
			rows.append(_obs_ext_row(
				scenario_id, combo_index, seed,
				_json_int(r["season_index"]), pid, "",
				"OBS-05", "city_balance_li", _json_int(r["city_balance_li"])
			))
	return rows


static func _obs_ext_row(
	scenario_id: String,
	combo_index: int,
	seed: int,
	season_index: int,
	port_id: String,
	good_id: String,
	obs_id: String,
	key: String,
	value: Variant
) -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"combo_index": combo_index,
		"seed": seed,
		"season_index": season_index,
		"port_id": port_id,
		"good_id": good_id,
		"obs_id": obs_id,
		"key": key,
		"value": value,
	}


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
	return _json_int(r["poor"]) + _json_int(r["citizen"]) + _json_int(r["rich"])


static func _pass_ge(value: float, th: Dictionary, key: String) -> Dictionary:
	var pass_s := PASS_NA
	if th.has(key):
		pass_s = "1" if value >= float(th[key]) else "0"
	return {"value": value, "pass": pass_s}


static func _pass_between(
	value: float, th: Dictionary, lo_key: String, hi_key: String
) -> Dictionary:
	## D-93 MET-01: TH-01 ≤ value ≤ TH-01b. Missing either bound → N/A for that side.
	var pass_s := PASS_NA
	var has_lo: bool = th.has(lo_key)
	var has_hi: bool = th.has(hi_key)
	if has_lo or has_hi:
		var ok := true
		if has_lo and value < float(th[lo_key]):
			ok = false
		if has_hi and value > float(th[hi_key]):
			ok = false
		pass_s = "1" if ok else "0"
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
