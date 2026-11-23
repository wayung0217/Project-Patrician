extends SceneTree
## WP-66／17-50 step0：黃金輸出 v2（只讀公開方法）。
## 用法：
##   godot --headless --path . -s res://tools/golden_harness.gd -- \
##     --out <abs.csv> --days 360 --seed 1
## 預設 360 日；輸出寬表＋逐日欄位雜湊列（row_kind=hash）。


const ARG_OUT := "--out"
const ARG_DAYS := "--days"
const ARG_SEED := "--seed"
const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"
const DEFAULT_DAYS := 360
const DEFAULT_SEED := 1
const PLAYER_TOKEN := "PLAYER"


var _started: bool = false


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_main()
	return false


func _main() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = _arg_value(args, ARG_OUT)
	var days: int = int(_arg_value(args, ARG_DAYS)) if not _arg_value(args, ARG_DAYS).is_empty() else DEFAULT_DAYS
	var seed_i: int = int(_arg_value(args, ARG_SEED)) if not _arg_value(args, ARG_SEED).is_empty() else DEFAULT_SEED
	if out_path.is_empty():
		push_error("golden_harness: require --out <abs.csv>")
		quit(2)
		return
	var parent: String = out_path.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(parent)
	var boot: Dictionary = _boot_formal()
	if not bool(boot.get("ok")):
		push_error("golden_harness: boot failed: %s" % str(boot.get("errors")))
		quit(1)
		return
	print("GOLDEN_V2: boot_ok seed=%s days=%s out=%s" % [str(seed_i), str(days), out_path])
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("golden_harness: cannot write %s" % out_path)
		quit(1)
		return
	f.store_line(_header())
	var root: Window = get_root()
	var sim_loop: Node = root.get_node_or_null("SimLoop")
	var clock: Node = root.get_node_or_null("Clock")
	var pop: Node = root.get_node_or_null("PopulationModel")
	var ports: Node = root.get_node_or_null("PortRegistry")
	var cash: Node = root.get_node_or_null("CashLedger")
	var goods: Node = root.get_node_or_null("GoodsLedger")
	var catalog: Node = root.get_node_or_null("GoodCatalog")
	var be: Node = root.get_node_or_null("BuildingEconomy")
	var market: Node = root.get_node_or_null("MarketPricer")
	var port_ids: PackedStringArray = ports.call("all_ids")
	var good_ids: PackedStringArray = catalog.call("all_ids")
	_write_day(0, seed_i, port_ids, good_ids, pop, cash, goods, be, market, f)
	for d in range(1, days + 1):
		var day_errs: Array = sim_loop.call("tick_day")
		if not day_errs.is_empty():
			print("GOLDEN_V2: tick_day errors day=%s count=%s" % [str(d), str(day_errs.size())])
		var clock_day: int = int(clock.get("day")) if clock != null else d
		_write_day(clock_day, seed_i, port_ids, good_ids, pop, cash, goods, be, market, f)
	f.close()
	print("GOLDEN_V2: wrote %s" % out_path)
	quit(0)


func _boot_formal() -> Dictionary:
	var root: Window = get_root()
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var scen: Dictionary = JSON.parse_string(raw)
	var overrides: Dictionary = scen.get("overrides", {})
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merged_path := "user://sim_merged/golden_v2_harness.json"
	var merge_res: Dictionary = merge_gds.call(
		"merge_to_user", "res://data/params/params.json", overrides, {}, merged_path
	)
	if not bool(merge_res.get("ok")):
		return {"ok": false, "errors": merge_res.get("errors", [])}
	var sim_loop: Node = root.get_node_or_null("SimLoop")
	var good_cat: Node = root.get_node_or_null("GoodCatalog")
	var port_reg: Node = root.get_node_or_null("PortRegistry")
	var market: Node = root.get_node_or_null("MarketPricer")
	var sea: Node = root.get_node_or_null("SeaLanes")
	var demand: Node = root.get_node_or_null("DemandModel")
	var goods_dir: String = "res://data/goods/"
	var ports_dir: String = "res://data/ports/"
	var curve_path: String = "res://data/market/price_curve.tres"
	var nodes_dir: String = "res://data/sea/nodes/"
	var regions_dir: String = "res://data/sea/regions/"
	var lanes_dir: String = "res://data/sea/lanes/"
	var tables_path: String = "res://data/demand/"
	if good_cat != null and not String(good_cat.get("GOODS_DIR")).is_empty():
		var g: String = String(good_cat.get("GOODS_DIR"))
		if g != "<null>":
			goods_dir = g
	if port_reg != null and not String(port_reg.get("PORTS_DIR")).is_empty():
		var p: String = String(port_reg.get("PORTS_DIR"))
		if p != "<null>":
			ports_dir = p
	if market != null and not String(market.get("CURVE_PATH")).is_empty():
		var c: String = String(market.get("CURVE_PATH"))
		if c != "<null>":
			curve_path = c
	if sea != null:
		var n: String = String(sea.get("NODES_DIR"))
		var r: String = String(sea.get("REGIONS_DIR"))
		var l: String = String(sea.get("LANES_DIR"))
		if not n.is_empty() and n != "<null>":
			nodes_dir = n
		if not r.is_empty() and r != "<null>":
			regions_dir = r
		if not l.is_empty() and l != "<null>":
			lanes_dir = l
	if demand != null:
		var t: String = String(demand.get("TABLES_PATH"))
		if not t.is_empty() and t != "<null>":
			tables_path = t
	var intel: Node = root.get_node_or_null("IntelLedger")
	if intel != null and not bool(intel.call("has_broker_provider")):
		var fixture_script: GDScript = load("res://sim/sim_broker_fixture.gd") as GDScript
		intel.call("set_broker_provider", fixture_script.new())
	var trade_desk: Node = root.get_node_or_null("TradeDesk")
	if trade_desk != null:
		if not bool(trade_desk.call("has_qualification_provider")):
			var qual_script: GDScript = load("res://sim/sim_qualification_fixture.gd") as GDScript
			trade_desk.call("set_qualification_provider", qual_script.new())
		if not bool(trade_desk.call("has_trade_observers")):
			var obs_script: GDScript = load("res://sim/sim_trade_observer_fixture.gd") as GDScript
			trade_desk.call("set_trade_observers", [obs_script.new()])
	var boot_errors: Array = sim_loop.call(
		"boot",
		String(merge_res["path"]),
		goods_dir,
		ports_dir,
		curve_path,
		nodes_dir,
		regions_dir,
		lanes_dir,
		tables_path
	)
	var is_booted: bool = bool(sim_loop.call("is_booted"))
	return {"ok": boot_errors.is_empty() and is_booted, "errors": boot_errors}


func _header() -> String:
	return (
		"row_kind,day,seed,port_id,poor,citizen,rich,beggar,city_balance_li,player_balance_li,"
		+ "goods_mid_json,goods_stock_weeks_json,goods_window_qty_json,"
		+ "buildings_json,residences_json,"
		+ "land_rent_li,vacancy_tax_li,city_spend_json,note"
	)


func _write_day(
	day: int,
	seed_i: int,
	port_ids: PackedStringArray,
	good_ids: PackedStringArray,
	pop: Node,
	cash: Node,
	goods: Node,
	be: Node,
	market: Node,
	f: FileAccess
) -> void:
	## Accumulate per-column strings for day-level hashes.
	var col_bufs: Dictionary = {
		"port_id": "",
		"poor": "",
		"citizen": "",
		"rich": "",
		"beggar": "",
		"city_balance_li": "",
		"player_balance_li": "",
		"goods_mid_json": "",
		"goods_stock_weeks_json": "",
		"goods_window_qty_json": "",
		"buildings_json": "",
		"residences_json": "",
		"land_rent_li": "",
		"vacancy_tax_li": "",
		"city_spend_json": "",
	}
	var player_id: StringName = cash.call("make_actor_id", PLAYER_TOKEN)
	var player_bal: int = 0
	if bool(cash.call("has_account", player_id)):
		player_bal = int(cash.call("balance", player_id))
	for i in range(port_ids.size()):
		var port_s: String = String(port_ids[i])
		var pid: StringName = StringName(port_s)
		var poor: int = int(pop.call("population", pid, StringName("POOR")))
		var citizen: int = int(pop.call("population", pid, StringName("CITIZEN")))
		var rich: int = int(pop.call("population", pid, StringName("RICH")))
		var beggar: int = int(pop.call("beggars", pid))
		var city_id: StringName = cash.call("make_city_id", port_s)
		var city_bal: int = int(cash.call("balance", city_id))
		var mid_json: String = _goods_mid_json(market, port_s, good_ids)
		var weeks_json: String = _goods_weeks_json(market, port_s, good_ids)
		var win_json: String = _goods_window_json(goods, port_s, good_ids)
		var bld_json: String = _buildings_json(be, port_s)
		var res_json: String = _residences_json(be, pop, port_s)
		## OBS-05／地租／空置稅：無公開查詢 API（C-05）→ 空值，note 標 gap。
		var land_rent: String = ""
		var vac_tax: String = ""
		var spend_json: String = "{}"
		var note: String = "gap_no_public_OBS05_land_vacancy"
		f.store_line(
			"port,%s,%s,%s,%s,%s,%s,%s,%s,%s,\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",%s,%s,\"%s\",%s"
			% [
				str(day),
				str(seed_i),
				port_s,
				str(poor),
				str(citizen),
				str(rich),
				str(beggar),
				str(city_bal),
				str(player_bal),
				mid_json.replace("\"", "'"),
				weeks_json.replace("\"", "'"),
				win_json.replace("\"", "'"),
				bld_json.replace("\"", "'"),
				res_json.replace("\"", "'"),
				land_rent,
				vac_tax,
				spend_json.replace("\"", "'"),
				note,
			]
		)
		col_bufs["port_id"] += port_s + ";"
		col_bufs["poor"] += str(poor) + ";"
		col_bufs["citizen"] += str(citizen) + ";"
		col_bufs["rich"] += str(rich) + ";"
		col_bufs["beggar"] += str(beggar) + ";"
		col_bufs["city_balance_li"] += str(city_bal) + ";"
		col_bufs["player_balance_li"] += str(player_bal) + ";"
		col_bufs["goods_mid_json"] += mid_json + ";"
		col_bufs["goods_stock_weeks_json"] += weeks_json + ";"
		col_bufs["goods_window_qty_json"] += win_json + ";"
		col_bufs["buildings_json"] += bld_json + ";"
		col_bufs["residences_json"] += res_json + ";"
		col_bufs["land_rent_li"] += land_rent + ";"
		col_bufs["vacancy_tax_li"] += vac_tax + ";"
		col_bufs["city_spend_json"] += spend_json + ";"
	## One hash row per day: hash of each tracked column payload.
	var hash_parts: PackedStringArray = PackedStringArray()
	var keys: Array = col_bufs.keys()
	keys.sort()
	for k in keys:
		var h: String = _fnv1a64(String(col_bufs[k]))
		hash_parts.append("%s=%s" % [str(k), h])
	f.store_line(
		"hash,%s,%s,,,,,,,,,,,\"%s\",,,,,"
		% [str(day), str(seed_i), ",".join(hash_parts)]
	)


func _goods_mid_json(market: Node, port_s: String, good_ids: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for j in range(good_ids.size()):
		var gid: String = String(good_ids[j])
		var mid: float = float(market.call("mid_price", StringName(port_s), StringName(gid)))
		var mid_li: int = floori(mid)
		parts.append("%s:%s" % [gid, str(mid_li)])
	return "{" + ",".join(parts) + "}"


func _goods_weeks_json(market: Node, port_s: String, good_ids: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for j in range(good_ids.size()):
		var gid: String = String(good_ids[j])
		var w: Variant = market.call("stock_weeks", StringName(port_s), StringName(gid))
		var ws: String = "null" if w == null else str(w)
		parts.append("%s:%s" % [gid, ws])
	return "{" + ",".join(parts) + "}"


func _goods_window_json(goods: Node, port_s: String, good_ids: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for j in range(good_ids.size()):
		var gid: String = String(good_ids[j])
		var snap: Dictionary = goods.call("offtake_snapshot", StringName(port_s), StringName(gid))
		var wq: int = int(snap.get("window_qty", 0)) if not snap.is_empty() else 0
		parts.append("%s:%s" % [gid, str(wq)])
	return "{" + ",".join(parts) + "}"


func _buildings_json(be: Node, port_s: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var arr: Array = be.call("buildings_for_port", port_s)
	## Stable order by building_id string.
	var rows: Array = []
	for b_v in arr:
		var b: Object = b_v
		var bid: String = String(b.get("building_id"))
		var typ: String = String(b.get("type"))
		var lv: int = int(b.get("level"))
		var st: int = int(b.get("state"))
		var sid: String = String(b.get("slot_id"))
		var ring: int = 0
		var slot: Object = be.call("get_slot", StringName(sid))
		if slot != null:
			ring = int(slot.get("ring"))
		rows.append(
			{
				"id": bid,
				"line": "%s:%s:L%s:S%s:slot=%s:ring=%s"
				% [bid, typ, str(lv), str(st), sid, str(ring)],
			}
		)
	rows.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	for r in rows:
		parts.append(String(r["line"]))
	return "[" + ";".join(parts) + "]"


func _residences_json(be: Node, pop: Node, port_s: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var arr: Array = be.call("residences", StringName(port_s))
	var rows: Array = []
	for b_v in arr:
		var b: Object = b_v
		var bid: String = String(b.get("building_id"))
		var occ: Dictionary = pop.call("residence_occupants", StringName(bid))
		rows.append(
			{
				"id": bid,
				"line": "%s:p%s:c%s:r%s"
				% [
					bid,
					str(int(occ.get("poor", 0))),
					str(int(occ.get("citizen", 0))),
					str(int(occ.get("rich", 0))),
				],
			}
		)
	rows.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	for r in rows:
		parts.append(String(r["line"]))
	return "[" + ";".join(parts) + "]"


func _fnv1a64(s: String) -> String:
	## FRM-SYS23-10／E2: FNV-1a 64 via Rng（offset basis as int64 bit-pattern of
	## unsigned 14695981039346656037＝0xcbf29ce484222325；mul mod 2^64 in Rng）.
	## Emit signed decimal of the bit-pattern（stable across platforms）.
	return str(Rng.fnv1a64(s.to_utf8_buffer()))


func _arg_value(args: PackedStringArray, key: String) -> String:
	for i in range(args.size()):
		if String(args[i]) == key and i + 1 < args.size():
			return String(args[i + 1])
	return ""
