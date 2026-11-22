extends SceneTree
## WP-61 screenshot harness — requires a display (do not pass --headless).
## godot --path . -s res://ui/screenshot_wp61.gd
## Writes PNGs to user://wp61_shots/


const OUT_DIR := "user://wp61_shots/"
const ACTOR := &"ACT-PLAYER"
const BUY_PORT := &"PT-03"
const SELL_PORT := &"PT-04"
const GOOD := &"GD-001"

var _phase: int = 0
var _ui: Node = null
var _ship: StringName = &""
var _frames: int = 0
var _settle: int = 0
var _pending_save: String = ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DisplayServer.window_set_size(Vector2i(1400, 900))
	var packed: PackedScene = load("res://ui/debug_main.tscn") as PackedScene
	_ui = packed.instantiate()
	get_root().add_child(_ui)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	if _settle > 0:
		_settle -= 1
		if _settle == 0 and _pending_save != "":
			_write_png(_pending_save)
			_pending_save = ""
		return false
	match _phase:
		0:
			_queue_shot("01_sea_map.png")
			_phase = 1
		1:
			_ui.call("force_select_port", BUY_PORT)
			_ui.call("refresh_panels")
			_queue_shot("02_market_table.png")
			_phase = 2
		2:
			_ui.call("refresh_panels")
			_queue_shot("03_player_panel.png")
			_phase = 3
		3:
			_warmup(14)
			_ensure_at(BUY_PORT)
			_do_buy()
			_ui.call("force_select_port", BUY_PORT)
			_ui.call("force_select_good", GOOD)
			_ui.call("refresh_panels")
			_ui.call(
				"set_trade_result_text",
				"交易成功（截圖）已買入 米×1"
			)
			_queue_shot("04_trade_success.png")
			_phase = 4
		4:
			_do_buy_fail()
			_ui.call("refresh_panels")
			_queue_shot("05_trade_fail.png")
			_phase = 5
		5:
			_ensure_sail(SELL_PORT)
			_ui.call("refresh_panels")
			_queue_shot("06_sailing.png")
			_phase = 6
		6:
			print("SHOTS_DONE ", ProjectSettings.globalize_path(OUT_DIR))
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


func _do_buy() -> void:
	var desk: Node = get_root().get_node("TradeDesk")
	var hold_id: StringName = StringName("HOLD:%s" % String(_ship))
	var seq: int = int(desk.call(
		"execute_trade", ACTOR, hold_id, BUY_PORT, GOOD, 0, 1, 0
	))
	print("BUY seq=", seq, " err=", desk.call("last_error"))
	desk.call("flush_signals")


func _do_buy_fail() -> void:
	var desk: Node = get_root().get_node("TradeDesk")
	var hold_id: StringName = StringName("HOLD:%s" % String(_ship))
	var seq: int = int(desk.call(
		"execute_trade", ACTOR, hold_id, BUY_PORT, GOOD, 0, 9999, 0
	))
	var err: Dictionary = desk.call("last_error")
	print("FAIL seq=", seq, " err=", err)
	_ui.call(
		"set_trade_result_text",
		"交易失敗 code=%s msg=%s" % [str(err.get("code", "")), str(err.get("message", err))]
	)


func _ensure_sail(dest: StringName) -> void:
	var reg: Node = get_root().get_node("ShipRegistry")
	var info: Dictionary = reg.call("ship_info", _ship)
	print("PRE_SAIL ", info)
	if StringName(info.get("state", "")) == &"DOCKED":
		var arrival: int = int(reg.call("sail", ACTOR, _ship, dest))
		print("SAIL arrival=", arrival, " err=", reg.call("last_error"))
		print("POST_SAIL ", reg.call("ship_info", _ship))
