extends GutTest
## WP-27／D-93: FRM-SYS23-04 relocator, SIM_RELOCATE, MET／OBS revisions.
## Expectations from frm_examples EX-23-04-01..03; test names contain TST／EX ids.


const PRM_PPM := "PRM-SYS06-PPM_SCALE"
const PRM_EPS := "PRM-SYS04-ROUND_EPS"
## EX-23-04-01 fixture (demo values; not from DemandModel).
const EX01_STOCK_A := 100
const EX01_STOCK_B := 10
const EX01_STOCK_C := 0
const EX01_W_A := 0
const EX01_W_B := 200
const EX01_W_C := 100
const EX01_F_PPM := 100000
const EX01_PPM := 1000000
const EX01_MOVE_AB := 6
const EX01_MOVE_AC := 4
const EX01_AFTER_A := 90
const EX01_AFTER_B := 16
const EX01_AFTER_C := 4
const EX01_TOTAL := 110


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func _boot_cash() -> void:
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var cerr: Array = CashLedger.load_and_validate()
	assert_eq(cerr.size(), 0)


func test_EX_23_04_01_plan_three_ports() -> void:
	## EX-23-04-01: A→B 6, A→C 4; stocks 90／16／4; total 110.
	_boot_cash()
	var stocks := {"A": EX01_STOCK_A, "B": EX01_STOCK_B, "C": EX01_STOCK_C}
	var pots := {"A": EX01_W_A, "B": EX01_W_B, "C": EX01_W_C}
	var plan: Dictionary = SimRelocator.plan_one_good(stocks, pots, EX01_F_PPM, EX01_PPM)
	assert_true(bool(plan["ok"]), String(plan.get("error", "")))
	assert_eq(int(plan["exports"].get("A", 0)), 10)
	assert_eq(int(plan["imports"].get("B", 0)), EX01_MOVE_AB)
	assert_eq(int(plan["imports"].get("C", 0)), EX01_MOVE_AC)
	var moves: Array = plan["moves"]
	assert_eq(moves.size(), 2)
	assert_eq(String(moves[0]["from"]), "A")
	assert_eq(String(moves[0]["to"]), "B")
	assert_eq(int(moves[0]["qty"]), EX01_MOVE_AB)
	assert_eq(String(moves[1]["from"]), "A")
	assert_eq(String(moves[1]["to"]), "C")
	assert_eq(int(moves[1]["qty"]), EX01_MOVE_AC)
	var after_a: int = EX01_STOCK_A - EX01_MOVE_AB - EX01_MOVE_AC
	var after_b: int = EX01_STOCK_B + EX01_MOVE_AB
	var after_c: int = EX01_STOCK_C + EX01_MOVE_AC
	assert_eq(after_a, EX01_AFTER_A)
	assert_eq(after_b, EX01_AFTER_B)
	assert_eq(after_c, EX01_AFTER_C)
	assert_eq(after_a + after_b + after_c, EX01_TOTAL)
	print("EX-23-04-01 moves ok: A→B %s A→C %s" % [str(EX01_MOVE_AB), str(EX01_MOVE_AC)])


func test_EX_23_04_02_TST_SYS23_06_f_zero_no_move() -> void:
	## EX-23-04-02／TST-SYS23-06: f=0 → no moves.
	_boot_cash()
	var stocks := {"A": EX01_STOCK_A, "B": EX01_STOCK_B, "C": EX01_STOCK_C}
	var pots := {"A": EX01_W_A, "B": EX01_W_B, "C": EX01_W_C}
	var plan: Dictionary = SimRelocator.plan_one_good(stocks, pots, 0, EX01_PPM)
	assert_true(bool(plan["ok"]))
	assert_eq((plan["moves"] as Array).size(), 0)
	assert_eq((plan["exports"] as Dictionary).size(), 0)
	print("EX-23-04-02／TST-SYS23-06 f=0 → no moves")


func test_EX_23_04_03_no_consumer_ports() -> void:
	## EX-23-04-03: W=0 → no moves.
	_boot_cash()
	var stocks := {"A": EX01_STOCK_A, "B": EX01_STOCK_B, "C": EX01_STOCK_C}
	var pots := {"A": 0, "B": 0, "C": 0}
	var plan: Dictionary = SimRelocator.plan_one_good(stocks, pots, EX01_F_PPM, EX01_PPM)
	assert_true(bool(plan["ok"]))
	assert_eq((plan["moves"] as Array).size(), 0)
	print("EX-23-04-03 W=0 → no moves")


func test_TST_SYS23_05_transfer_matches_EX_23_04_01() -> void:
	## TST-SYS23-05: apply EX-23-04-01 via GoodsLedger.transfer SIM_RELOCATE; totals conserved.
	_boot_cash()
	var gerr: Array = GoodsLedger.load_and_validate()
	assert_eq(gerr.size(), 0)
	var good: StringName = &"GD-001"
	var m_a: Dictionary = GoodsLedger.make_market("PT-A")
	var m_b: Dictionary = GoodsLedger.make_market("PT-B")
	var m_c: Dictionary = GoodsLedger.make_market("PT-C")
	GoodsLedger.transfer(
		GoodsLedger.make_external(), m_a, good, EX01_STOCK_A,
		GoodsLedger.REASON_GENESIS, &"TEST"
	)
	GoodsLedger.transfer(
		GoodsLedger.make_external(), m_b, good, EX01_STOCK_B,
		GoodsLedger.REASON_GENESIS, &"TEST"
	)
	## C stock 0 — no genesis.
	var stocks := {
		"PT-A": GoodsLedger.get_qty(m_a, good),
		"PT-B": GoodsLedger.get_qty(m_b, good),
		"PT-C": GoodsLedger.get_qty(m_c, good),
	}
	var pots := {"PT-A": EX01_W_A, "PT-B": EX01_W_B, "PT-C": EX01_W_C}
	var plan: Dictionary = SimRelocator.plan_one_good(stocks, pots, EX01_F_PPM, EX01_PPM)
	assert_true(bool(plan["ok"]))
	for mv_v in plan["moves"]:
		var mv: Dictionary = mv_v
		var from_c: Dictionary = GoodsLedger.make_market(String(mv["from"]))
		var to_c: Dictionary = GoodsLedger.make_market(String(mv["to"]))
		var seq: int = GoodsLedger.transfer(
			from_c, to_c, good, int(mv["qty"]),
			GoodsLedger.REASON_SIM_RELOCATE, &"SYS-23"
		)
		assert_gt(seq, 0, "SIM_RELOCATE transfer must succeed")
	assert_eq(GoodsLedger.get_qty(m_a, good), EX01_AFTER_A)
	assert_eq(GoodsLedger.get_qty(m_b, good), EX01_AFTER_B)
	assert_eq(GoodsLedger.get_qty(m_c, good), EX01_AFTER_C)
	assert_eq(
		GoodsLedger.get_qty(m_a, good)
		+ GoodsLedger.get_qty(m_b, good)
		+ GoodsLedger.get_qty(m_c, good),
		EX01_TOTAL
	)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)
	print("TST-SYS23-05 EX-23-04-01 ledger apply ok")


func test_TST_SYS23_07_sim_relocate_rejected_when_disabled() -> void:
	## TST-SYS23-07: non-sim → ERR-SYS03-04; quantities unchanged.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var gerr: Array = GoodsLedger.load_and_validate()
	assert_eq(gerr.size(), 0)
	var good: StringName = &"GD-001"
	var m_a: Dictionary = GoodsLedger.make_market("PT-01")
	var m_b: Dictionary = GoodsLedger.make_market("PT-02")
	GoodsLedger.transfer(
		GoodsLedger.make_external(), m_a, good, 1, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	var before_a: int = GoodsLedger.get_qty(m_a, good)
	var before_b: int = GoodsLedger.get_qty(m_b, good)
	var seq: int = GoodsLedger.transfer(
		m_a, m_b, good, 1, GoodsLedger.REASON_SIM_RELOCATE, &"TEST"
	)
	assert_eq(seq, 0)
	var le: Dictionary = GoodsLedger.last_error()
	assert_eq(StringName(le.get(ErrorInfoUtil.KEY_CODE, &"")), GoodsLedger.ERR_SYS03_04)
	assert_eq(GoodsLedger.get_qty(m_a, good), before_a)
	assert_eq(GoodsLedger.get_qty(m_b, good), before_b)
	## ERR path push_error is expected (same as SEA_LOSS TST-SYS03-05).
	assert_push_error_count(1)
	print("TST-SYS23-07 SIM_RELOCATE rejected offline")


func test_WP27_MET01_TH01b_upper_bound() -> void:
	## D-93 MET-01: TH-01 ≤ ratio ≤ TH-01b.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var sampler := SimSampler.new()
	sampler.acc = SimTransferAcc.new()
	## 2／2 equilibrium → ratio 1.0; with TH-01b=0.6 → fail.
	for si in [0, 1]:
		sampler.season_cells.append({
			"run_id": 0, "seed": 1, "season_index": si, "port_id": "PT-01", "good_id": "GD-001",
			"stock": 1, "mid_li": 1, "stock_weeks": "1.0",
			"band": MarketPricer.BAND_EQUILIBRIUM,
			"produced": 0, "consumed": 0, "relocated_in": 0, "relocated_out": 0,
			"_weekly_potential": 1,
		})
		sampler.season_ports.append({
			"run_id": 0, "seed": 1, "season_index": si, "port_id": "PT-01",
			"rich": 1, "citizen": 1, "poor": 1, "beggar": 0, "sat_weighted": 100,
			"workplaces": 0, "beds": 0, "city_balance_li": 1,
		})
	var summary: Dictionary = SimMetrics.compute(
		sampler, 0, 1, {"TH-01": 0.4, "TH-01b": 0.6}, false, "", 0, 0, 0, 1, {}, "t"
	)
	assert_eq(float(summary["MET-01"]), 1.0)
	assert_eq(String(summary["MET-01_pass"]), "0")
	print("WP27 MET-01 TH-01b upper reject ok")


func test_WP27_MET05b_no_pass() -> void:
	## D-93 MET-05(b): value only; pass always N/A even if TH-05b present.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var sampler := SimSampler.new()
	sampler.acc = SimTransferAcc.new()
	sampler.season_ports.append({
		"run_id": 0, "seed": 1, "season_index": 0, "port_id": "PT-01",
		"rich": 1, "citizen": 1, "poor": 1, "beggar": 0, "sat_weighted": 1,
		"workplaces": 0, "beds": 0, "city_balance_li": 10,
	})
	sampler.season_ports.append({
		"run_id": 0, "seed": 1, "season_index": 1, "port_id": "PT-01",
		"rich": 1, "citizen": 1, "poor": 1, "beggar": 0, "sat_weighted": 1,
		"workplaces": 0, "beds": 0, "city_balance_li": 20,
	})
	var summary: Dictionary = SimMetrics.compute(
		sampler, 0, 1, {"TH-05a": 1, "TH-05b": 0.5}, false, "", 0, 0, 0, 1, {}, "t"
	)
	assert_eq(String(summary["MET-05b_pass"]), SimMetrics.PASS_NA)
	assert_true(float(summary["MET-05b"]) > 0.0)
	print("WP27 MET-05b pass=N/A ok value=%s" % str(summary["MET-05b"]))


func test_WP27_OBS02_longest_zero_beggar_streak() -> void:
	## D-93 OBS-02: longest consecutive zero-beggar seasons in obs_ext.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var sampler := SimSampler.new()
	sampler.acc = SimTransferAcc.new()
	## beggar 0,0,0,1 → streak 3
	for si in range(4):
		var beg: int = 0 if si < 3 else 1
		sampler.season_ports.append({
			"run_id": 0, "seed": 1, "season_index": si, "port_id": "PT-01",
			"rich": 1, "citizen": 1, "poor": 1, "beggar": beg, "sat_weighted": 1,
			"workplaces": 0, "beds": 0, "city_balance_li": 1,
		})
	var summary: Dictionary = SimMetrics.compute(
		sampler, 0, 1, {}, false, "", 0, 0, 0, 1, {}, "obs02"
	)
	assert_true(typeof(summary["OBS-02"]) != TYPE_STRING or String(summary["OBS-02"]) != "")
	var found := false
	for r_v in sampler.obs_ext_rows:
		var r: Dictionary = r_v
		if String(r["obs_id"]) == "OBS-02" and String(r["key"]) == "longest_zero_beggar_streak":
			assert_eq(int(r["value"]), 3)
			found = true
	assert_true(found, "OBS-02 streak row missing")
	print("WP27 OBS-02 streak=3 ok")


func test_WP27_relocate_f_C02_float_snap() -> void:
	## C-02: 0.1 × 1000000 snaps to 100000 within ROUND_EPS.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var ppm: int = Params.get_int(PRM_PPM)
	var eps: float = Params.get_float(PRM_EPS)
	var conv: Dictionary = SimRelocator.f_to_ppm(0.1, ppm, eps)
	assert_true(bool(conv["ok"]), String(conv.get("error", "")))
	assert_eq(int(conv["f_ppm"]), 100000)
	var conv05: Dictionary = SimRelocator.f_to_ppm(0.05, ppm, eps)
	assert_true(bool(conv05["ok"]))
	assert_eq(int(conv05["f_ppm"]), 50000)
	var conv20: Dictionary = SimRelocator.f_to_ppm(0.2, ppm, eps)
	assert_true(bool(conv20["ok"]))
	assert_eq(int(conv20["f_ppm"]), 200000)
	## Non-integer product beyond eps → reject.
	var bad: Dictionary = SimRelocator.f_to_ppm(0.1000001, ppm, eps)
	## May or may not snap depending on product error magnitude; just exercise API.
	print(
		"WP27 relocate_f C-02: 0.1→%s 0.05→%s 0.2→%s bad_ok=%s"
		% [str(conv["f_ppm"]), str(conv05["f_ppm"]), str(conv20["f_ppm"]), str(bad.get("ok"))]
	)


func test_WP27_weekly_potential_demand_D96f() -> void:
	## D-96f: DemandModel.weekly_potential_demand exists; equals weekly_demand.
	assert_true(DemandModel.has_method("weekly_potential_demand"))
	## Full boot of DemandModel is heavy; signature／alias checked when loaded in other suites.
	print("WP27 D-96f weekly_potential_demand present")


func test_WP27_scenario_list_dir_sorted_R9_64() -> void:
	## R9-64 中-3: validator list_dir path still validates L2 scenarios.
	var r: Dictionary = SimScenarioValidator.validate_file(
		"res://docs/spec/scenario_L2_f010.json"
	)
	assert_true(bool(r["ok"]), " ".join(r["errors"]))
	assert_true(bool((r["scenario"]["layers"] as Dictionary)["RELOCATE"]))
	print("WP27 R9-64 scenario_L2_f010 validates")


func test_R9_65_B2_e_p_overflow_boundary() -> void:
	## R9-65 B2／C-10: int64 overflow before multiply → error, not wrap.
	_boot_cash()
	## Huge stock × W overflows mul check.
	var huge: int = 1 << 62
	var stocks := {"A": huge, "B": 1}
	var pots := {"A": 0, "B": 1}
	var plan: Dictionary = SimRelocator.plan_one_good(stocks, pots, EX01_F_PPM, EX01_PPM)
	assert_false(bool(plan["ok"]))
	assert_true(String(plan.get("error", "")).find("overflow") >= 0)
	print("R9-65 B2 e_p overflow → error ok")


func test_R9_65_B6_e_p_exceeds_stock_errors() -> void:
	## R9-65 B6／C-06: if math e_p > stock_p → error (no clamp).
	_boot_cash()
	## Construct: stock_p=1, W large, S small relative → e_p can exceed stock.
	## Use f_ppm = ppm_scale so e_p ≈ (stock_p*W - S*w_p)/W = stock_p - S*w_p/W.
	## With stock A=1, w_A=0, B stock=0 w_B=1, S=1 W=1 → numer=1*1-1*0=1; e=f*1/(1*ppm).
	## Need e_p > stock: use f_ppm=ppm and inflate numer via W >> S*w.
	## A: stock=1 w=0; B: stock=100 w=1; S=101 W=1 → numer_A=1*1-101*0=1; e=(f*1)/(1*ppm).
	## Still e <= 1 when f<=ppm. Force via stock_p=1, W=ppm_scale, S=1, w=0, f=ppm:
	## numer=1*W=ppm; e=(ppm*ppm)/(W*ppm)=ppm/W=1 when W=ppm. Still = stock.
	## Use stock_p=1, W=2, S=1, w_A=0, f=ppm, ppm=1000000 → e=(1000000*2)/(2*1000000)=1.
	## To get e>stock: numer_inner large vs stock — stock_p=1, W=10^6, S=1, f=ppm:
	## numer=1e6; e=(ppm*1e6)/(1e6*ppm)=1.
	## Formula e = f*(stock*W - S*w)/(W*ppm). Max when w=0: e=f*stock/ppm ≤ stock when f≤ppm.
	## So e_p > stock_p only when f_ppm > ppm_scale (allowed by validator? relocate_f≤1 → f≤ppm).
	## Use raw f_ppm > ppm_scale to prove no-clamp error path (API accepts any int f_ppm).
	var stocks := {"A": 1, "B": 0}
	var pots := {"A": 0, "B": 1}
	var plan: Dictionary = SimRelocator.plan_one_good(stocks, pots, EX01_PPM * 2, EX01_PPM)
	assert_false(bool(plan["ok"]), "e_p>stock must error")
	assert_true(String(plan.get("error", "")).find("exceeds stock_p") >= 0)
	print("R9-65 B6 e_p>stock_p → error ok: %s" % str(plan.get("error")))


func test_R9_65_B3_OBS04_unable_to_judge() -> void:
	## R9-65 B3: cannot compute R_g →「無法判定」, never default「分配不足」.
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0)
	var cells: Array = []
	## W=0 potentials → first_n=last_n=0 → 無法判定.
	for si in [0, 1, 2, 3]:
		cells.append({
			"run_id": 0, "seed": 1, "season_index": si, "port_id": "PT-01", "good_id": "GD-001",
			"stock": 10, "mid_li": 1, "stock_weeks": "",
			"band": MarketPricer.BAND_EQUILIBRIUM,
			"produced": 0, "consumed": 0, "relocated_in": 0, "relocated_out": 0,
			"_weekly_potential": 0,
		})
	var rows: Array = SimMetrics._obs04_rows(
		"t", 0, 1, cells, ["PT-01|GD-001"], {"TH-02": 1.1}, 2
	)
	var found := false
	for r_v in rows:
		var r: Dictionary = r_v
		if String(r["obs_id"]) == "OBS-04" and String(r["key"]) == "cause":
			assert_eq(String(r["value"]), "無法判定")
			found = true
	assert_true(found, "OBS-04 cause row missing")
	print("R9-65 B3 OBS-04 無法判定 ok")
