extends GutTest
## WP-02／WP-28 SYS-00 Clock — TechSpec §3.1 / 1-A3 / GP-01; Owner D-05 / D-07 / D-14d.


const FIXTURE_ALL := "res://tests/fixtures/params_all_keys.json"
const PRM_DAYS := &"PRM-SYS00-DAYS_PER_SEASON"
const PRM_TPD := &"PRM-SYS00-TICKS_PER_DAY"


func before_each() -> void:
	var errors: Array = Params.load_and_validate(FIXTURE_ALL)
	assert_eq(errors.size(), 0, "Params fixture must load")
	errors = Clock.load_and_validate()
	assert_eq(errors.size(), 0, "Clock load_and_validate")
	Clock.set_paused(false)


func test_boot_day_zero_first_advance_to_one() -> void:
	# D-05(b) / D-07: boot _tick=0 → day=0; first advance → day=1 (k=0 PRODUCE).
	assert_eq(Clock._tick, 0)
	assert_eq(Clock.day, 0)
	assert_eq(Clock.season_index, 0)
	assert_false(Clock.is_paused)
	Clock.advance_one_day()
	assert_eq(Clock.day, 1)
	assert_eq(Clock.season_index, 0)


func test_season_index_formula() -> void:
	# §3.1 / D-05(c): season_index = floori((day−1)/D)；首季 0，不得為 −1
	var d: int = Params.get_int(PRM_DAYS)
	# Advance to day == D → season_index still 0; then to D+1 → season_index 1
	for _i in range(d):
		Clock.advance_one_day()
	assert_eq(Clock.day, d)
	assert_eq(Clock.season_index, floori(float(d - 1) / float(d)))
	assert_eq(Clock.season_index, 0)
	Clock.advance_one_day()
	assert_eq(Clock.day, d + 1)
	assert_eq(Clock.season_index, floori(float(d) / float(d)))
	assert_eq(Clock.season_index, 1)


func test_set_paused_updates_is_paused() -> void:
	# §3.1 public API: set_paused(bool) / is_paused
	Clock.set_paused(true)
	assert_true(Clock.is_paused)
	Clock.set_paused(false)
	assert_false(Clock.is_paused)


func test_advance_one_day_does_not_emit_signals() -> void:
	# D-05(a): Clock mutates only; day_ticked / season_cutoff by SimLoop step 6.
	var ticked: Array = []
	var cutoffs: Array = []
	Clock.day_ticked.connect(func(day: int): ticked.append(day))
	Clock.season_cutoff.connect(func(s: int): cutoffs.append(s))
	Clock.advance_one_day()
	assert_eq(Clock.day, 1)
	assert_eq(ticked.size(), 0)
	assert_eq(cutoffs.size(), 0)


func test_paused_advance_push_error_and_no_progress() -> void:
	# §3.1 / GP-01: paused → push_error, day/_tick unchanged, no signals
	Clock.set_paused(true)
	var day_before: int = Clock.day
	var tick_before: int = Clock._tick
	var ticked: Array = []
	var cutoffs: Array = []
	Clock.day_ticked.connect(func(day: int): ticked.append(day))
	Clock.season_cutoff.connect(func(s: int): cutoffs.append(s))
	Clock.advance_one_day()
	assert_push_error_count(1)
	assert_eq(Clock.day, day_before)
	assert_eq(Clock._tick, tick_before)
	assert_eq(ticked.size(), 0)
	assert_eq(cutoffs.size(), 0)


func test_advance_one_day_advances_exactly_tpd_ticks() -> void:
	# D-07 / WP-02: advance_one_day() advances exactly TPD ticks (from Params).
	var tpd: int = Params.get_int(PRM_TPD)
	assert_gt(tpd, 0)
	assert_eq(Clock._tick, 0)
	Clock.advance_one_day()
	assert_eq(Clock._tick, tpd)
	assert_eq(Clock.day, 1)
	Clock.advance_one_day()
	assert_eq(Clock._tick, tpd + tpd)
	assert_eq(Clock.day, 2)


func test_no_season_cutoff_from_clock_at_season_end() -> void:
	# D-05(a): even at day_in_season == D, Clock must not emit season_cutoff.
	var d: int = Params.get_int(PRM_DAYS)
	var cutoffs: Array = []
	Clock.season_cutoff.connect(func(s: int): cutoffs.append(s))
	for _i in range(d):
		Clock.advance_one_day()
	assert_eq(Clock.day, d)
	assert_eq(Clock.season_index, 0)
	assert_eq(cutoffs.size(), 0)


func test_load_requires_params() -> void:
	## BB3: official params missing keys → Clock refuses; reverse when formal is complete.
	var schema: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/params/params_schema.json")
	)
	var formal: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Params.PARAMS_PATH)
	)
	var missing := false
	for id_variant in schema.keys():
		if not formal.has(String(id_variant)):
			missing = true
			break
	var perr: Array = Params.load_and_validate(Params.PARAMS_PATH)
	if missing:
		assert_gt(perr.size(), 0)
		assert_push_error_count(perr.size())
		var cerr: Array = Clock.load_and_validate()
		assert_gt(cerr.size(), 0)
		assert_push_error_count(perr.size() + cerr.size())
		assert_false(Clock.is_loaded())
	else:
		assert_eq(perr.size(), 0)
		var cerr_ok: Array = Clock.load_and_validate()
		assert_eq(cerr_ok.size(), 0)
		assert_true(Clock.is_loaded())


func test_load_requires_ticks_per_day() -> void:
	# D-07: TPD must come from Params; missing key → Clock not loaded.
	assert_true(Params.has_prm(PRM_TPD))
	# Reload Clock after Params ok — already loaded in before_each.
	assert_true(Clock.is_loaded())
	assert_eq(Clock._ticks_per_day, Params.get_int(PRM_TPD))


func test_TST_SYS13_16_advance_one_day_matches_tpd_ticks() -> void:
	# 13-03／TST-SYS13-16: advance_one_day() ≡ TPD × advance_one_tick()（日結前時鐘狀態相同）.
	var tpd: int = Params.get_int(PRM_TPD)
	Clock.advance_one_day()
	var tick_via_day: int = Clock.tick
	var day_via_day: int = Clock.day
	assert_eq(tick_via_day, tpd)
	assert_eq(day_via_day, 1)

	var reload: Array = Clock.load_and_validate()
	assert_eq(reload.size(), 0)
	Clock.set_paused(false)
	for _i in range(tpd):
		Clock.advance_one_tick()
	assert_eq(Clock.tick, tick_via_day)
	assert_eq(Clock.day, day_via_day)
	assert_eq(Clock._tick, Clock.tick)


func test_13_03_1_tick_starts_zero_increments_by_one() -> void:
	# 13-03 ①: tick 從 0 起、每次 advance_one_tick +1；唯讀 tick 與 _tick 一致.
	assert_eq(Clock.tick, 0)
	assert_eq(Clock._tick, 0)
	Clock.advance_one_tick()
	assert_eq(Clock.tick, 1)
	assert_eq(Clock._tick, 1)
	Clock.advance_one_tick()
	assert_eq(Clock.tick, 2)
	assert_eq(Clock.day, 0)  # TPD=24；尚未跨日


func test_13_03_2_day_boundary_across_days() -> void:
	# 13-03 ②: 跨日邊界 day = floori(tick ÷ TPD) 正確.
	var tpd: int = Params.get_int(PRM_TPD)
	for _i in range(tpd - 1):
		Clock.advance_one_tick()
	assert_eq(Clock.tick, tpd - 1)
	assert_eq(Clock.day, 0)
	Clock.advance_one_tick()
	assert_eq(Clock.tick, tpd)
	assert_eq(Clock.day, 1)
	for _i in range(tpd):
		Clock.advance_one_tick()
	assert_eq(Clock.tick, tpd * 2)
	assert_eq(Clock.day, 2)


func test_13_03_3_paused_advance_one_tick_no_progress() -> void:
	# 13-03 ③／GP-01: 暫停時 advance_one_tick() push_error 不推進；不發信號.
	Clock.set_paused(true)
	var tick_before: int = Clock.tick
	var day_before: int = Clock.day
	var ticked: Array = []
	var cutoffs: Array = []
	Clock.day_ticked.connect(func(day: int): ticked.append(day))
	Clock.season_cutoff.connect(func(s: int): cutoffs.append(s))
	Clock.advance_one_tick()
	assert_push_error_count(1)
	assert_eq(Clock.tick, tick_before)
	assert_eq(Clock.day, day_before)
	assert_eq(ticked.size(), 0)
	assert_eq(cutoffs.size(), 0)
