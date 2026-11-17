extends Node
## Autoload: Clock — SYS-00 (TechSpec §3.1 / 1-A3).
## Phase 0: advance_one_day only; no _process / timer speed (PRM not registered).

signal day_ticked(day: int)
signal season_cutoff(season_index: int)

const PRM_DAYS_PER_SEASON := &"PRM-SYS00-DAYS_PER_SEASON"

var _day: int = 1
var _is_paused: bool = false
var _days_per_season: int = 0
var _loaded: bool = false


var day: int:
	get:
		return _day


var season_index: int:
	get:
		# TechSpec §3.1: season_index = floori((day−1)/D)；PRM-SYS00-DAYS_PER_SEASON
		if not _loaded:
			return 0
		return floori(float(_day - 1) / float(_days_per_season))


var is_paused: bool:
	get:
		return _is_paused


func _ready() -> void:
	# 2.2-01: field init only; do not read Params or emit.
	_day = 1
	_is_paused = false
	_days_per_season = 0
	_loaded = false


func load_and_validate() -> Array:
	var errors: Array = []
	_loaded = false
	_days_per_season = 0
	_day = 1
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
		_days_per_season = 0
		_emit_errors(errors)
		return errors
	_loaded = true
	return errors


func is_loaded() -> bool:
	return _loaded


func set_paused(paused: bool) -> void:
	_is_paused = paused


func day_in_season() -> int:
	# 2.3-01: day_in_season = ((day−1) mod D) + 1
	if not _loaded:
		return 0
	return ((_day - 1) % _days_per_season) + 1


func advance_one_day() -> void:
	# GP-01 / §3.1: paused → push_error, do not advance.
	if _is_paused:
		push_error("Clock.advance_one_day called while is_paused=true (GP-01)")
		return
	if not _loaded:
		push_error("Clock.advance_one_day called before load_and_validate")
		return
	_day += 1
	day_ticked.emit(_day)
	# 2.3-05: season cutoff on day_in_season == D
	if day_in_season() == _days_per_season:
		season_cutoff.emit(season_index)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("Clock: %s" % str(e))
