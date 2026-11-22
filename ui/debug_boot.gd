class_name DebugBoot
extends RefCounted
## WP-61：Debug UI formal L1 boot helper（mirror tests/fixtures/sys23/probe_formal_l1_boot.gd）.
## Injects ui/debug always-allow providers (D-90(f)); merges scenario_L1_baseline overrides.


const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"
const PARAMS_PATH := "res://data/params/params.json"
const MERGED_PATH := "user://sim_merged/wp61_debug_ui.json"


static func inject_debug_providers() -> void:
	## 僅供除錯介面，正式開機不得使用。
	if not TradeDesk.has_qualification_provider():
		TradeDesk.set_qualification_provider(DebugQualificationProvider.new())
	if not TradeDesk.has_trade_observers():
		TradeDesk.set_trade_observers([DebugTradeObserver.new()])
	if not IntelLedger.has_broker_provider():
		IntelLedger.set_broker_provider(DebugBrokerProvider.new())


static func boot_formal_l1() -> Dictionary:
	## Returns {ok: bool, errors: Array, merged_path: String, merge_errors: Array}.
	inject_debug_providers()
	var out: Dictionary = {
		"ok": false,
		"errors": [],
		"merged_path": "",
		"merge_errors": [],
	}
	if not FileAccess.file_exists(SCENARIO_PATH):
		out["errors"] = [{
			"code": "SCENARIO_MISSING",
			"file": SCENARIO_PATH,
			"field": "scenario",
			"value": null,
			"message": "scenario_L1_baseline.json missing",
		}]
		return out
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var scen: Variant = JSON.parse_string(raw)
	if typeof(scen) != TYPE_DICTIONARY:
		out["errors"] = [{
			"code": "SCENARIO_PARSE",
			"file": SCENARIO_PATH,
			"field": "json",
			"value": null,
			"message": "scenario JSON parse failed",
		}]
		return out
	var overrides: Dictionary = (scen as Dictionary).get("overrides", {})
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merge_res: Dictionary = merge_gds.call(
		"merge_to_user",
		PARAMS_PATH,
		overrides,
		{},
		MERGED_PATH
	)
	out["merge_errors"] = merge_res.get("errors", [])
	if not bool(merge_res.get("ok")):
		out["errors"] = out["merge_errors"]
		return out
	var merged_path: String = String(merge_res["path"])
	out["merged_path"] = merged_path
	var boot_errors: Array = SimLoop.boot(
		merged_path,
		GoodCatalog.GOODS_DIR,
		PortRegistry.PORTS_DIR,
		MarketPricer.CURVE_PATH,
		SeaLanes.NODES_DIR,
		SeaLanes.REGIONS_DIR,
		SeaLanes.LANES_DIR,
		DemandModel.TABLES_PATH
	)
	out["errors"] = boot_errors
	out["ok"] = boot_errors.is_empty() and SimLoop.is_booted()
	return out
