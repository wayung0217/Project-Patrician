extends SceneTree
## WP-62 M0 acceptance screenshots — requires a display (do not pass --headless).
## Path: 福州買米 → 開船 → 抵達月港 → 賣出.
## godot --path . -s res://ui/screenshot_wp62_m0.gd
## Writes PNGs + voyage_log.txt to user://wp62_m0_shots/


const OUT_DIR := "user://wp62_m0_shots/"
const ACTOR := &"ACT-PLAYER"
const BUY_PORT := &"PT-03" ## 福州
const SELL_PORT := &"PT-01" ## 月港
const GOOD := &"GD-001"
const BUY_QTY := 1
const WARMUP_DAYS := 14

var _phase: int = -1 ## -1 = wait for autoload _ready, then spawn UI
var _ui: Node = null
var _ship: StringName = &""
var _frames: int = 0
var _settle: int = 0
var _pending_save: String = ""
var _log_lines: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_size(Vector2i(1400, 900))
	_log("INIT display_size=1400x900")


func _process(_delta: float) -> bool:
	_frames += 1
	## Defer UI spawn until autoloads finished _ready (regex／Params).
	if _phase < 0:
		if _frames < 2:
			return false
		var packed: PackedScene = load("res://ui/debug_main.tscn") as PackedScene
		_ui = packed.instantiate()
		get_root().add_child(_ui)
		_phase = 0
		_frames = 0
		return false
	if _frames < 10:
		return false
	if _settle > 0:
		_settle -= 1
		if _settle == 0 and _pending_save != "":
			_write_png(_pending_save)
			_pending_save = ""
		return false
	if _ui == null or not bool(_ui.call("is_debug_booted")):
		_log("BOOT_NOT_READY phase=%s" % str(_phase))
		_write_log_file()
		quit(1)
		return false
	match _phase:
		0:
			var reg0: Node = get_root().get_node("ShipRegistry")
			var ids0: Array = reg0.call("ship_ids", ACTOR)
			if ids0.size() > 0:
				_ship = ids0[0]
			_log_snapshot("01_boot")
			_queue_shot("01_boot.png")
			_phase = 1
		1:
			_warmup(WARMUP_DAYS)
			_ensure_at(BUY_PORT)
			_ui.call("force_select_port", BUY_PORT)
			_ui.call("force_select_good", GOOD)
			_ui.call("refresh_panels")
			_log_snapshot("02_at_fuzhou_ready")
			_queue_shot("02_at_fuzhou_ready.png")
			_phase = 2
		2:
			_do_buy()
			_ui.call("force_select_port", BUY_PORT)
			_ui.call("force_select_good", GOOD)
			_ui.call("refresh_panels")
			var desk_buy: Node = get_root().get_node("TradeDesk")
			_ui.call(
				"set_trade_result_text",
				"福州買米成功 total_li=%s" % str(desk_buy.call("last_trade_total_li"))
			)
			_log_snapshot("03_fuzhou_bought_rice")
			_queue_shot("03_fuzhou_bought_rice.png")
			_phase = 3
		3:
			_start_sail(SELL_PORT)
			_ui.call("refresh_panels")
			_log_snapshot("04_sailed_from_fuzhou")
			_queue_shot("04_sailed_from_fuzhou.png")
			_phase = 4
		4:
			_finish_sail(SELL_PORT)
			_ui.call("force_select_port", SELL_PORT)
			_ui.call("refresh_panels")
			_log_snapshot("05_arrived_yuegang")
			_queue_shot("05_arrived_yuegang.png")
			_phase = 5
		5:
			_do_sell()
			_ui.call("force_select_port", SELL_PORT)
			_ui.call("refresh_panels")
			var desk_sell: Node = get_root().get_node("TradeDesk")
			_ui.call(
				"set_trade_result_text",
				"月港賣出成功 total_li=%s" % str(desk_sell.call("last_trade_total_li"))
			)
			_log_snapshot("06_yuegang_sold")
			_queue_shot("06_yuegang_sold.png")
			_phase = 6
		6:
			_write_log_file()
			print("WP62_M0_SHOTS_DONE ", ProjectSettings.globalize_path(OUT_DIR))
			quit(0)
	return false


func _queue_shot(fname: String) -> void:
	_pending_save = fname
	_settle = 8


func _write_png(fname: String) -> void:
	RenderingServer.force_draw()
	var vp: Viewport = get_root()
	var tex: ViewportTexture = vp.get_texture()
	var img: Image = tex.get_image()
	var path: String = OUT_DIR + fname
	var err: Error = img.save_png(path)
	print("SAVED ", ProjectSettings.globalize_path(path), " err=", err)


func _warmup(n: int) -> void:
	var clock: Node = get_root().get_node("Clock")
	var sim: Node = get_root().get_node("SimLoop")
	if bool(clock.get("is_paused")):
		clock.call("set_paused", false)
	for _i in range(n):
		sim.call("tick_day")


func _ensure_at(port: StringName) -> void:
	var reg: Node = get_root().get_node("ShipRegistry")
	var sim: Node = get_root().get_node("SimLoop")
	var ids: Array = reg.call("ship_ids", ACTOR)
	assert(ids.size() > 0)
	_ship = ids[0]
	var info: Dictionary = reg.call("ship_info", _ship)
	if StringName(info.get("port_id", "")) == port and StringName(info.get("state", "")) == &"DOCKED":
		return
	if StringName(info.get("state", "")) == &"DOCKED":
		reg.call("sail", ACTOR, _ship, port)
	var guard: int = 0
	while guard < 500:
		var pos: Dictionary = reg.call("position", _ship)
		if StringName(pos.get("state", "")) == &"DOCKED" and StringName(pos.get("port_id", "")) == port:
			return
		sim.call("tick_day")
		guard += 1


func _start_sail(dest: StringName) -> void:
	var reg: Node = get_root().get_node("ShipRegistry")
	var info: Dictionary = reg.call("ship_info", _ship)
	if StringName(info.get("state", "")) == &"DOCKED":
		var arrival: int = int(reg.call("sail", ACTOR, _ship, dest))
		_log("SAIL dest=%s arrival_tick=%s err=%s" % [
			String(dest), str(arrival), str(reg.call("last_error"))
		])


func _finish_sail(dest: StringName) -> void:
	var reg: Node = get_root().get_node("ShipRegistry")
	var sim: Node = get_root().get_node("SimLoop")
	var guard: int = 0
	while guard < 500:
		var pos: Dictionary = reg.call("position", _ship)
		if StringName(pos.get("state", "")) == &"DOCKED" and StringName(pos.get("port_id", "")) == dest:
			return
		sim.call("tick_day")
		guard += 1


func _do_buy() -> void:
	var desk: Node = get_root().get_node("TradeDesk")
	var hold_id: StringName = StringName("HOLD:%s" % String(_ship))
	var seq: int = int(desk.call(
		"execute_trade", ACTOR, hold_id, BUY_PORT, GOOD, 0, BUY_QTY, 0
	))
	_log("BUY seq=%s last_trade_total_li=%s err=%s" % [
		str(seq), str(desk.call("last_trade_total_li")), str(desk.call("last_error"))
	])
	desk.call("flush_signals")


func _do_sell() -> void:
	var desk: Node = get_root().get_node("TradeDesk")
	var hold_id: StringName = StringName("HOLD:%s" % String(_ship))
	var seq: int = int(desk.call(
		"execute_trade", ACTOR, hold_id, SELL_PORT, GOOD, 1, BUY_QTY, 0
	))
	_log("SELL seq=%s last_trade_total_li=%s err=%s" % [
		str(seq), str(desk.call("last_trade_total_li")), str(desk.call("last_error"))
	])
	desk.call("flush_signals")


func _log_snapshot(step: String) -> void:
	var clock: Node = get_root().get_node("Clock")
	var cash: Node = get_root().get_node("CashLedger")
	var goods: Node = get_root().get_node("GoodsLedger")
	var pricer: Node = get_root().get_node("MarketPricer")
	var reg: Node = get_root().get_node("ShipRegistry")
	var day: int = int(clock.get("day"))
	var bal: int = int(cash.call("balance", ACTOR))
	var m_buy: Dictionary = goods.call("make_market", String(BUY_PORT))
	var m_sell: Dictionary = goods.call("make_market", String(SELL_PORT))
	var stock_fuzhou: int = int(goods.call("get_qty", m_buy, GOOD))
	var stock_yue: int = int(goods.call("get_qty", m_sell, GOOD))
	var mid_fuzhou: float = float(pricer.call("mid_price", BUY_PORT, GOOD))
	var mid_yue: float = float(pricer.call("mid_price", SELL_PORT, GOOD))
	var hold: Dictionary = goods.call("make_hold", String(_ship), String(ACTOR))
	var used: int = int(goods.call("container_used", hold))
	var cap: int = int(reg.call("capacity_for_hold", hold))
	var info: Dictionary = reg.call("ship_info", _ship)
	_log(
		(
			"STEP=%s day=%s cash_li=%s | 福州米 mid=%s stock=%s | 月港米 mid=%s stock=%s"
			+ " | hold_used=%s/%s 擔 ship_state=%s port=%s"
		) % [
			step,
			str(day),
			str(bal),
			str(mid_fuzhou),
			str(stock_fuzhou),
			str(mid_yue),
			str(stock_yue),
			str(used),
			str(cap),
			str(info.get("state", "")),
			str(info.get("port_id", "")),
		]
	)


func _log(line: String) -> void:
	_log_lines.append(line)
	print("WP62_M0 ", line)


func _write_log_file() -> void:
	var path: String = OUT_DIR + "voyage_log.txt"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("LOG_WRITE_FAIL ", path)
		return
	for line in _log_lines:
		f.store_line(line)
	f.close()
	print("LOG_SAVED ", ProjectSettings.globalize_path(path))
