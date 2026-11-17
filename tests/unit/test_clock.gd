extends GutTest
## WP-02 SYS-00 Clock — TechSpec §3.1 / 1-A3 / GP-01.


const FIXTURE_ALL := "res://tests/fixtures/params_all_keys.json"
const PRM_DAYS := &"PRM-SYS00-DAYS_PER_SEASON"


func before_each() -> void:
	var errors: Array = Params.load_and_validate(FIXTURE_ALL)
	assert_eq(errors.size(), 0, "Params fixture must load")
	errors = Clock.load_and_validate()
	assert_eq(errors.size(), 0, "Clock load_and_validate")
	Clock.set_paused(false)


func test_initial_day_is_one() -> void:
	# 2.3-01 / §3.1: day 由 1 起算
	assert_eq(Clock.day, 1)
	assert_eq(Clock.season_index, 0)
	assert_eq(Clock.day_in_season(), 1)
	assert_false(Clock.is_paused)


func test_season_index_formula() -> void:
	# §3.1: season_index = floori((day−1)/D)；D = PRM-SYS00-DAYS_PER_SEASON
	var d: int = Params.get_int(PRM_DAYS)
	var ticks: Array = []
	Clock.day_ticked.connect(func(day: int): ticks.append(day))
	# Advance to day == D → season_index still 0; then to D+1 → season_index 1
	for _i in range(d - 1):
		Clock.advance_one_day()
	assert_eq(Clock.day, d)
	assert_eq(Clock.season_index, floori(float(d - 1) / float(d)))
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


func test_advance_one_day_emits_day_ticked() -> void:
	# §3.1 signal day_ticked(day)
	var seen: Array = []
	Clock.day_ticked.connect(func(day: int): seen.append(day))
	Clock.advance_one_day()
	assert_eq(Clock.day, 2)
	assert_eq(seen, [2])


func test_paused_advance_push_error_and_no_progress() -> void:
	# §3.1 / GP-01: paused → push_error, day unchanged, no signals
	Clock.set_paused(true)
	var day_before: int = Clock.day
	var ticked: Array = []
	var cutoffs: Array = []
	Clock.day_ticked.connect(func(day: int): ticked.append(day))
	Clock.season_cutoff.connect(func(s: int): cutoffs.append(s))
	Clock.advance_one_day()
	assert_push_error_count(1)
	assert_eq(Clock.day, day_before)
	assert_eq(ticked.size(), 0)
	assert_eq(cutoffs.size(), 0)


func test_season_cutoff_emitted_on_season_end() -> void:
	# §3.1 / 2.3-05: season_cutoff(season_index) when day_in_season == D
	var d: int = Params.get_int(PRM_DAYS)
	var cutoffs: Array = []
	Clock.season_cutoff.connect(func(s: int): cutoffs.append(s))
	for _i in range(d - 1):
		Clock.advance_one_day()
	assert_eq(Clock.day, d)
	assert_eq(Clock.day_in_season(), d)
	assert_eq(cutoffs, [0])
	# Next season end
	cutoffs.clear()
	for _i in range(d):
		Clock.advance_one_day()
	assert_eq(Clock.day, d + d)
	assert_eq(Clock.day_in_season(), d)
	assert_eq(cutoffs, [1])


func test_no_season_cutoff_mid_season() -> void:
	var d: int = Params.get_int(PRM_DAYS)
	var cutoffs: Array = []
	Clock.season_cutoff.connect(func(s: int): cutoffs.append(s))
	# Stop one day before season end (avoid bare 2 per C-03).
	if d > 1:
		for _i in range(d - 1 - 1):
			Clock.advance_one_day()
		assert_eq(Clock.day, d - 1)
		assert_eq(cutoffs.size(), 0)


func test_load_requires_params() -> void:
	# Force Params into unloaded state via official file (missing 1-A8 keys).
	var perr: Array = Params.load_and_validate(Params.PARAMS_PATH)
	assert_gt(perr.size(), 0)
	assert_push_error_count(perr.size())
	var cerr: Array = Clock.load_and_validate()
	assert_gt(cerr.size(), 0)
	assert_push_error_count(perr.size() + cerr.size())
	assert_false(Clock.is_loaded())
