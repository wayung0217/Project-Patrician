class_name M1bDiagZ
extends RefCounted
## 17-63 Z2: gated M1b trader diagnosis (env M1B_DIAG_Z=1). No product behaviour change.
## Writes DIAG_Z_* lines to stdout and optional JSON under M1B_DIAG_Z_OUT.


const ENV_FLAG := "M1B_DIAG_Z"
const ENV_OUT := "M1B_DIAG_Z_OUT"

var _active: bool = false
var _out_path: String = ""
var _boot: Dictionary = {}
var _roster: Array = []
var _days: Array = []
var _board_snapshots: Dictionary = {} ## day → {port → count}
var _sails_total: int = 0


func is_active() -> bool:
	return _active


func begin_from_env() -> void:
	_active = OS.get_environment(ENV_FLAG) == "1"
	_out_path = String(OS.get_environment(ENV_OUT)).strip_edges()
	_boot = {}
	_roster.clear()
	_days.clear()
	_board_snapshots.clear()
	_sails_total = 0
	if _active:
		print("DIAG_Z: enabled out=%s" % (_out_path if not _out_path.is_empty() else "(stdout-only)"))


func record_boot(traders_on: bool, qual_open: bool, fixture_class: String) -> void:
	if not _active:
		return
	_boot = {
		"set_layers_traders_on": traders_on,
		"set_layers_qual_open": qual_open,
		"qualification_fixture_class": fixture_class,
	}
	print(
		"DIAG_Z_A: set_layers traders_on=%s qual_open=%s fixture=%s"
		% [str(traders_on), str(qual_open), fixture_class]
	)


## FRM-SYS07-18／Owner 2026-11-26: record 生效 CLASS_CAP（not request bit）.
func record_class_cap_effective(effective_on: bool) -> void:
	if not _active:
		return
	_boot["class_cap_effective"] = effective_on
	print("DIAG_Z_A: class_cap_effective=%s" % str(effective_on))


func record_roster_after_boot() -> void:
	if not _active:
		return
	_roster.clear()
	var trader_n: int = 0
	var ship_n: int = 0
	if TraderRegistry.is_enabled() and TraderRegistry.is_loaded():
		for tid_v in TraderRegistry.all_trader_ids():
			var tid: String = String(tid_v)
			var t: Variant = TraderRegistry.get_trader(StringName(tid))
			if typeof(t) != TYPE_DICTIONARY:
				continue
			trader_n += 1
			var td: Dictionary = t
			var sids: Array = td.get("ship_ids", [])
			for sid_v in sids:
				ship_n += 1
				var info: Dictionary = ShipRegistry.ship_info(sid_v)
				var port_s: String = String(info.get("port_id", ""))
				var state_s: String = String(info.get("state", ""))
				_roster.append({
					"trader_id": tid,
					"ship_id": String(sid_v),
					"port_id": port_s,
					"state": state_s,
					"home_port": String(td.get("home_port", "")),
				})
				print(
					"DIAG_Z_B_SHIP: trader=%s ship=%s port=%s state=%s home=%s"
					% [tid, String(sid_v), port_s, state_s, String(td.get("home_port", ""))]
				)
	print("DIAG_Z_B: trader_count=%d ship_count=%d" % [trader_n, ship_n])


func note_day_eval(
	day: int,
	evaluable_candidates: int,
	dest_excluded_no_market: int,
	explore_hit_traders: int,
	sail_count: int
) -> void:
	if not _active:
		return
	_sails_total += sail_count
	var row := {
		"day": day,
		"evaluable_candidates": evaluable_candidates,
		"dest_excluded_no_market": dest_excluded_no_market,
		"explore_hit_traders": explore_hit_traders,
		"sail_count": sail_count,
	}
	_days.append(row)
	print(
		"DIAG_Z_C: day=%d evaluable=%d dest_excl_no_market=%d explore_hit=%d sails=%d"
		% [day, evaluable_candidates, dest_excluded_no_market, explore_hit_traders, sail_count]
	)
	if day == 1 or day == 7 or day == 30:
		_snapshot_board_counts(day)


func finish() -> void:
	if not _active:
		return
	print("DIAG_Z: sails_total=%d days_logged=%d" % [_sails_total, _days.size()])
	var payload := {
		"a_boot": _boot,
		"b_roster": _roster,
		"c_days": _days,
		"d_board_for_days": _board_snapshots,
		"sails_total": _sails_total,
	}
	var text: String = JSON.stringify(payload, "\t")
	print("DIAG_Z_JSON_BEGIN")
	print(text)
	print("DIAG_Z_JSON_END")
	if _out_path.is_empty():
		return
	var abs_path: String = _out_path
	if not abs_path.is_absolute_path():
		abs_path = ProjectSettings.globalize_path("res://").trim_suffix("/").path_join(_out_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_error("m1b_diag_z: cannot write %s" % abs_path)
		return
	f.store_string(text + "\n")
	f.close()
	print("DIAG_Z: wrote %s" % abs_path)


func _snapshot_board_counts(day: int) -> void:
	var by_port := {}
	if not PortRegistry.is_loaded() or not IntelLedger.is_loaded():
		_board_snapshots[str(day)] = by_port
		print("DIAG_Z_D: day=%d (no PortRegistry/IntelLedger)" % day)
		return
	for pid_v in PortRegistry.all_ids():
		var pid: StringName = pid_v
		var n: int = 0
		## Raw recorded ship-report entries at this present-port board (_rec[port] size).
		if IntelLedger.has_method("diag_recorded_report_count"):
			n = int(IntelLedger.call("diag_recorded_report_count", pid))
		by_port[String(pid)] = n
		print("DIAG_Z_D: day=%d port=%s board_reports=%d" % [day, String(pid), n])
	_board_snapshots[str(day)] = by_port
