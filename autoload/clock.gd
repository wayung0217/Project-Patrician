extends Node
## Autoload: Clock — SYS-00 (TechSpec §3.1 / 1-A3; Owner D-05 / D-07 / D-14d).
## No _process / Timer (1-A3). D-05: mutate only — SimLoop step 6 emits signals.
## D-07: internal _tick; day = floori(_tick / TPD); TPD from Params.
## D-14d: public advance_one_tick() + read-only tick; advance_one_day = TPD ticks.

signal day_ticked(day: int)
signal season_cutoff(season_index: int)

const PRM_DAYS_PER_SEASON := &"PRM-SYS00-DAYS_PER_SEASON"
const PRM_TICKS_PER_DAY := &"PRM-SYS00-TICKS_PER_DAY"

var _tick: int = 0
var _is_paused: bool = false
var _days_per_season: int = 0
var _ticks_per_day: int = 0
var _loaded: bool = false


var day: int:
	get:
		# D-07: day = floori(_tick ÷ TPD). Boot _tick=0 → day=0.
		if not _loaded or _ticks_per_day < 1:
			return 0
		return floori(float(_tick) / float(_ticks_per_day))


## D-14d: read-only public tick (same value as private _tick).
var tick: int:
	get:
		return _tick


var season_index: int:
	get:
		# §3.1 / D-05(c): season_index = floori((day−1)/D)；首季 0（不得為 −1）。
		if not _loaded:
			return 0
		var d: int = day
		if d < 1:
			return 0
		return floori(float(d - 1) / float(_days_per_season))


var is_paused: bool:
	get:
		return _is_paused


func _ready() -> void:
	# 2.2-01: field init only; do not read Params or emit.
	_tick = 0
	_is_paused = false
	_days_per_season = 0
	_ticks_per_day = 0
	_loaded = false


func load_and_validate() -> Array:
	var errors: Array = []
	_loaded = false
	_days_per_season = 0
	_ticks_per_day = 0
	_tick = 0
	_is_paused = false
	if not Params.is_loaded():
		errors.append({
			"code": "PARAMS_NOT_LOADED",
			"file": "res://autoload/clock.gd",
			"field": String(PRM_DAYS_PER_SEASON),
			"value": null,
			"message": "Params must load_and_validate before Clock",
		})
		_emit_errors(errors)
		return errors
	if not Params.has_prm(PRM_DAYS_PER_SEASON):
		errors.append({
			"code": "MISSING_PRM",
			"file": "res://autoload/clock.gd",
			"field": String(PRM_DAYS_PER_SEASON),
			"value": null,
			"message": "PRM-SYS00-DAYS_PER_SEASON required",
		})
	if not Params.has_prm(PRM_TICKS_PER_DAY):
		errors.append({
			"code": "MISSING_PRM",
			"file": "res://autoload/clock.gd",
			"field": String(PRM_TICKS_PER_DAY),
			"value": null,
			"message": "PRM-SYS00-TICKS_PER_DAY required",
		})
	if not errors.is_empty():
		_emit_errors(errors)
		return errors
	# PRM-SYS00-DAYS_PER_SEASON
	_days_per_season = Params.get_int(PRM_DAYS_PER_SEASON)
	if _days_per_season < 1:
		errors.append({
			"code": "INVALID_D",
			"file": "res://autoload/clock.gd",
			"field": String(PRM_DAYS_PER_SEASON),
			"value": _days_per_season,
			"message": "DAYS_PER_SEASON must be >= 1",
		})
	# D-07: TICKS_PER_DAY from Params as int; Clock must not hardcode the value.
	_ticks_per_day = Params.get_int(PRM_TICKS_PER_DAY)
	if _ticks_per_day != floori(float(_ticks_per_day)) or _ticks_per_day < 1:
		errors.append({
			"code": "INVALID_TPD",
			"file": "res://autoload/clock.gd",
			"field": String(PRM_TICKS_PER_DAY),
			"value": _ticks_per_day,
			"message": "TICKS_PER_DAY must be an integer >= 1",
		})
	if not errors.is_empty():
		_days_per_season = 0
		_ticks_per_day = 0
		_emit_errors(errors)
		return errors
	_loaded = true
	return errors


func is_loaded() -> bool:
	return _loaded


func set_paused(paused: bool) -> void:
	_is_paused = paused


func advance_one_tick() -> void:
	# D-14d / GP-01: paused → push_error, do not advance. D-05: mutate only; no emit.
	if _is_paused:
		push_error("Clock.advance_one_tick called while is_paused=true (GP-01)")
		return
	if not _loaded:
		push_error("Clock.advance_one_tick called before load_and_validate")
		return
	_tick += 1


func advance_one_day() -> void:
	# GP-01 / §3.1: paused → push_error once, do not advance (existing contract).
	if _is_paused:
		push_error("Clock.advance_one_day called while is_paused=true (GP-01)")
		return
	if not _loaded:
		push_error("Clock.advance_one_day called before load_and_validate")
		return
	# D-14d: advance_one_day = TICKS_PER_DAY successive advance_one_tick() calls.
	for _i in range(_ticks_per_day):
		advance_one_tick()


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("Clock: %s" % str(e))
