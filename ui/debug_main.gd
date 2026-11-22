extends Control
## WP-61 M0 Debug UI — Godot default controls only; formal L1 boot + play loop.


const ACTOR := &"ACT-PLAYER"
const DEFAULT_GOOD := &"GD-001"
const BAND_LABELS := {
	0: "過低",
	1: "偏低",
	2: "均衡",
	3: "偏高",
	4: "過高",
}

var _booted: bool = false
var _selected_port: StringName = &""
var _selected_good: StringName = DEFAULT_GOOD
var _selected_ship: StringName = &""
var _trade_qty: int = 1
var _continuous: bool = false
var _accum_sec: float = 0.0

var _sea_map: Control
var _market_tree: Tree
var _player_label: Label
var _msg_log: RichTextLabel
var _status_label: Label
var _day_label: Label
var _cash_label: Label
var _port_label: Label
var _good_option: OptionButton
var _qty_spin: SpinBox
var _ship_option: OptionButton
var _dest_option: OptionButton
var _eta_label: Label
var _trade_result: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_append_msg("WP-61 Debug UI starting…")
	var boot: Dictionary = DebugBoot.boot_formal_l1()
	if not bool(boot.get("ok")):
		_booted = false
		_append_msg("BOOT FAILED — errors follow (not swallowed):")
		for e in boot.get("errors", []):
			_append_msg(str(e))
		_status_label.text = "開機失敗（見訊息列）"
		_status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	_booted = true
	_status_label.text = "開機成功（formal L1 + debug providers）"
	_append_msg("BOOT OK merged=%s" % str(boot.get("merged_path")))
	_sea_map.reload_from_sea()
	var opening: StringName = &"PT-10"
	if PortRegistry.is_loaded() and PortRegistry.get_port("PT-10") != null:
		_selected_port = opening
	elif PortRegistry.is_loaded():
		var ids: PackedStringArray = PortRegistry.all_ids()
		if ids.size() > 0:
			_selected_port = StringName(ids[0])
	_sea_map.set_selected(_selected_port)
	_refresh_good_options()
	_refresh_ship_options()
	_refresh_dest_options()
	_refresh_all()


func _process(delta: float) -> void:
	if not _booted or not _continuous:
		return
	if Clock.is_paused:
		return
	_accum_sec += delta
	while _accum_sec >= DebugConfig.SECONDS_PER_GAME_DAY:
		_accum_sec -= DebugConfig.SECONDS_PER_GAME_DAY
		_advance_day()


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	root.add_child(left)

	var title := Label.new()
	title.text = "Project Patrician — WP-61 Debug UI (M0)"
	title.add_theme_font_size_override("font_size", DebugConfig.FONT_SIZE_TITLE)
	left.add_child(title)

	_day_label = Label.new()
	_cash_label = Label.new()
	_status_label = Label.new()
	left.add_child(_day_label)
	left.add_child(_cash_label)
	left.add_child(_status_label)

	var time_row := HBoxContainer.new()
	left.add_child(time_row)
	_add_btn(time_row, "暫停", _on_pause)
	_add_btn(time_row, "前進一日", _on_step_day)
	_add_btn(time_row, "連續", _on_continuous)
	_add_btn(time_row, "停止連續", _on_stop_continuous)

	_sea_map = load("res://ui/sea_map.gd").new() as Control
	_sea_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_sea_map)
	_sea_map.port_selected.connect(_on_port_selected)

	_port_label = Label.new()
	left.add_child(_port_label)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(float(DebugConfig.PANEL_MIN_WIDTH), 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	right.add_child(_section("市場表（選定港 28 貨）"))
	_market_tree = Tree.new()
	_market_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_tree.columns = 7
	_market_tree.column_titles_visible = true
	var headers := ["貨", "買", "賣", "中價", "庫存", "週數", "燈"]
	for i in range(headers.size()):
		_market_tree.set_column_title(i, headers[i])
		_market_tree.set_column_expand(i, true)
	_market_tree.item_selected.connect(_on_market_selected)
	right.add_child(_market_tree)

	right.add_child(_section("玩家面板"))
	_player_label = Label.new()
	_player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_player_label)

	right.add_child(_section("交易"))
	var trade_row := HBoxContainer.new()
	right.add_child(trade_row)
	_good_option = OptionButton.new()
	_good_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_good_option.item_selected.connect(_on_good_picked)
	trade_row.add_child(_good_option)
	_qty_spin = SpinBox.new()
	_qty_spin.min_value = 1
	_qty_spin.max_value = 9999
	_qty_spin.value = 1
	_qty_spin.value_changed.connect(_on_qty_changed)
	trade_row.add_child(_qty_spin)
	_add_btn(trade_row, "買入", _on_buy)
	_add_btn(trade_row, "賣出", _on_sell)
	_trade_result = Label.new()
	_trade_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_trade_result)

	right.add_child(_section("航行"))
	var sail_row := HBoxContainer.new()
	right.add_child(sail_row)
	_ship_option = OptionButton.new()
	_ship_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_option.item_selected.connect(_on_ship_picked)
	sail_row.add_child(_ship_option)
	_dest_option = OptionButton.new()
	_dest_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sail_row.add_child(_dest_option)
	_add_btn(sail_row, "出航", _on_sail)
	_eta_label = Label.new()
	right.add_child(_eta_label)

	right.add_child(_section("訊息列"))
	_msg_log = RichTextLabel.new()
	_msg_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_msg_log.fit_content = false
	_msg_log.scroll_following = true
	_msg_log.bbcode_enabled = false
	_msg_log.custom_minimum_size = Vector2(0, 160)
	right.add_child(_msg_log)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", DebugConfig.FONT_SIZE_TITLE)
	return l


func _add_btn(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _on_port_selected(port_id: StringName) -> void:
	_selected_port = port_id
	_refresh_all()


func _on_market_selected() -> void:
	var item: TreeItem = _market_tree.get_selected()
	if item == null:
		return
	var gid: Variant = item.get_metadata(0)
	if gid != null:
		_selected_good = StringName(str(gid))
		_sync_good_option()


func _on_good_picked(idx: int) -> void:
	if idx < 0:
		return
	_selected_good = StringName(_good_option.get_item_text(idx).split(" ")[0])


func _on_qty_changed(v: float) -> void:
	_trade_qty = int(v)
	if _trade_qty < 1:
		_trade_qty = 1


func _on_ship_picked(idx: int) -> void:
	if idx < 0:
		return
	_selected_ship = StringName(_ship_option.get_item_text(idx))


func _on_pause() -> void:
	if not _booted:
		return
	Clock.set_paused(true)
	_continuous = false
	_append_msg("時間：暫停")
	_refresh_all()


func _on_step_day() -> void:
	if not _booted:
		return
	if Clock.is_paused:
		Clock.set_paused(false)
	_advance_day()


func _on_continuous() -> void:
	if not _booted:
		return
	Clock.set_paused(false)
	_continuous = true
	_accum_sec = 0.0
	_append_msg("時間：連續（每 %.2f 現實秒＝1 日）" % DebugConfig.SECONDS_PER_GAME_DAY)


func _on_stop_continuous() -> void:
	_continuous = false
	_append_msg("時間：停止連續")


func _advance_day() -> void:
	var before: int = Clock.day
	var errs: Array = SimLoop.tick_day()
	for e in errs:
		_append_msg("日推進錯誤: %s" % str(e))
	_append_msg("日推進 day %s → %s（錯誤 %s 條）" % [str(before), str(Clock.day), str(errs.size())])
	_refresh_all()


func _on_buy() -> void:
	_do_trade(MarketPricer.SIDE_BUY)


func _on_sell() -> void:
	_do_trade(MarketPricer.SIDE_SELL)


func _do_trade(side: int) -> void:
	if not _booted:
		_trade_result.text = "未開機"
		return
	if _selected_port == &"":
		_trade_result.text = "請先選港"
		return
	var container_id: StringName = _trade_container_for_port(_selected_port)
	if container_id == &"":
		_trade_result.text = "缺口：選定港無可用 HOLD／WAREHOUSE 容器（船須停靠該港）"
		_append_msg(_trade_result.text)
		return
	var cash_before: int = CashLedger.balance(ACTOR)
	var market: Dictionary = GoodsLedger.make_market(String(_selected_port))
	var stock_before: int = GoodsLedger.get_qty(market, _selected_good)
	var seq: int = TradeDesk.execute_trade(
		ACTOR,
		container_id,
		_selected_port,
		_selected_good,
		side,
		_trade_qty,
		0
	)
	if seq <= 0:
		var err: Dictionary = TradeDesk.last_error()
		_trade_result.text = "交易失敗 code=%s msg=%s" % [
			str(err.get("code", "")), str(err.get("message", err))
		]
		_append_msg(_trade_result.text)
		_refresh_all()
		return
	# D-95(d): TradeDesk.last_trade_total_li() after successful execute_trade.
	var paid: int = TradeDesk.last_trade_total_li()
	var cash_after: int = CashLedger.balance(ACTOR)
	var stock_after: int = GoodsLedger.get_qty(market, _selected_good)
	TradeDesk.flush_signals()
	_trade_result.text = "成交 seq=%s 量=%s 金額=%s 庫存 %s→%s 現金 %s→%s" % [
		str(seq),
		str(_trade_qty),
		FormatTael.format_tael(paid),
		str(stock_before),
		str(stock_after),
		FormatTael.format_tael(cash_before),
		FormatTael.format_tael(cash_after),
	]
	_append_msg(_trade_result.text)
	_refresh_all()


func _on_sail() -> void:
	if not _booted:
		return
	if _selected_ship == &"":
		_eta_label.text = "請選船"
		return
	var dest_idx: int = _dest_option.selected
	if dest_idx < 0:
		_eta_label.text = "請選目的港"
		return
	var dest: StringName = StringName(_dest_option.get_item_text(dest_idx).split(" ")[0])
	var arrival: int = ShipRegistry.sail(ACTOR, _selected_ship, dest)
	if arrival <= 0:
		var err: Dictionary = ShipRegistry.last_error()
		_eta_label.text = "出航失敗: %s" % str(err)
		_append_msg(_eta_label.text)
		_refresh_all()
		return
	var tpd: int = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
	if tpd < 1:
		tpd = 1
	var eta_day: int = int(floori(float(arrival) / float(tpd)))
	_eta_label.text = "出航成功 → %s；預計抵達 tick=%s（約 day %s）" % [
		String(dest), str(arrival), str(eta_day)
	]
	_append_msg(_eta_label.text)
	_refresh_all()


func _trade_container_for_port(port_id: StringName) -> StringName:
	## Prefer docked player HOLD at port; else player WAREHOUSE at port.
	for sid_variant in ShipRegistry.ship_ids(ACTOR):
		var sid: StringName = sid_variant
		var info: Dictionary = ShipRegistry.ship_info(sid)
		if info.is_empty():
			continue
		if StringName(info.get("state", "")) != Ship.STATE_DOCKED:
			continue
		if StringName(info.get("port_id", "")) != port_id:
			continue
		if ShipRegistry.can_trade(sid, port_id):
			return StringName(GoodsLedger.CONTAINER_ID_FMT_HOLD % String(sid))
	var wh_id: StringName = GoodsLedger.container_id(
		StringName(GoodsLedger.KIND_WAREHOUSE), String(ACTOR), String(port_id)
	)
	if wh_id != &"" and GoodsLedger.is_container_registered(wh_id):
		return wh_id
	return &""


func _refresh_good_options() -> void:
	_good_option.clear()
	if not GoodCatalog.is_loaded():
		return
	for gid in GoodCatalog.all_ids():
		var g: GoodDef = GoodCatalog.get_good(String(gid))
		var label: String = "%s %s" % [gid, g.name_zh if g else ""]
		_good_option.add_item(label)
	_sync_good_option()


func _sync_good_option() -> void:
	for i in range(_good_option.item_count):
		if _good_option.get_item_text(i).begins_with(String(_selected_good)):
			_good_option.select(i)
			return


func _refresh_ship_options() -> void:
	_ship_option.clear()
	if not ShipRegistry.is_loaded():
		return
	var ids: Array = ShipRegistry.ship_ids(ACTOR)
	for sid_variant in ids:
		_ship_option.add_item(String(sid_variant))
	if ids.size() > 0:
		_selected_ship = ids[0]
		_ship_option.select(0)


func _refresh_dest_options() -> void:
	_dest_option.clear()
	if not PortRegistry.is_loaded():
		return
	for pid in PortRegistry.all_ids():
		var def: PortDef = PortRegistry.get_port(String(pid))
		var name_zh: String = def.name_zh if def else ""
		_dest_option.add_item("%s %s" % [pid, name_zh])


func _refresh_all() -> void:
	if not _booted:
		return
	_day_label.text = "日＝%s　季＝%s　tick＝%s　暫停＝%s　連續＝%s" % [
		str(Clock.day), str(Clock.season_index), str(Clock.tick),
		str(Clock.is_paused), str(_continuous)
	]
	var bal: int = CashLedger.balance(ACTOR) if CashLedger.has_account(ACTOR) else 0
	_cash_label.text = "現金（%s）：%s" % [String(ACTOR), FormatTael.format_tael(bal)]
	var pname: String = String(_selected_port)
	if PortRegistry.is_loaded() and _selected_port != &"":
		var def: PortDef = PortRegistry.get_port(String(_selected_port))
		if def != null:
			pname = "%s %s" % [def.port_id, def.name_zh]
	_port_label.text = "選定港：%s（點海圖選港）" % pname
	_refresh_market()
	_refresh_player()


func _refresh_market() -> void:
	_market_tree.clear()
	var root: TreeItem = _market_tree.create_item()
	if not _booted or _selected_port == &"" or not GoodCatalog.is_loaded():
		return
	var market: Dictionary = GoodsLedger.make_market(String(_selected_port))
	for gid in GoodCatalog.all_ids():
		var g: GoodDef = GoodCatalog.get_good(String(gid))
		var good_id: StringName = StringName(gid)
		var item: TreeItem = _market_tree.create_item(root)
		item.set_metadata(0, String(gid))
		item.set_text(0, g.name_zh if g else String(gid))
		var stock: int = GoodsLedger.get_qty(market, good_id)
		var buy_s: String = "—"
		var sell_s: String = "—"
		# Avoid MarketPricer.quote BUY when stock=0 (ERR-SYS04-06 push_error).
		if stock > 0:
			var buy_q: Dictionary = MarketPricer.quote(
				_selected_port, good_id, MarketPricer.SIDE_BUY, 1
			)
			if not buy_q.has(MarketPricer.KEY_ERROR):
				buy_s = FormatTael.format_tael_unit_price(int(buy_q[MarketPricer.KEY_TOTAL_LI]))
		var sell_q: Dictionary = MarketPricer.quote(
			_selected_port, good_id, MarketPricer.SIDE_SELL, 1
		)
		if not sell_q.has(MarketPricer.KEY_ERROR):
			sell_s = FormatTael.format_tael_unit_price(int(sell_q[MarketPricer.KEY_TOTAL_LI]))
		var mid: float = MarketPricer.mid_price(_selected_port, good_id)
		var weeks_v: Variant = MarketPricer.stock_weeks(_selected_port, good_id)
		var weeks_s: String = "—" if weeks_v == null else "%.2f" % float(weeks_v)
		var band: int = MarketPricer.BAND_EQUILIBRIUM
		if g != null and g.base_price_li > 0 and mid > 0.0:
			band = MarketPricer.indicator_band(mid / float(g.base_price_li))
		item.set_text(1, buy_s)
		item.set_text(2, sell_s)
		item.set_text(3, FormatTael.format_tael_from_float_li(mid))
		item.set_text(4, str(stock))
		item.set_text(5, weeks_s)
		item.set_text(6, String(BAND_LABELS.get(band, str(band))))
		if good_id == _selected_good:
			item.select(0)


func _refresh_player() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var bal: int = CashLedger.balance(ACTOR) if CashLedger.has_account(ACTOR) else 0
	lines.append("現金：%s" % FormatTael.format_tael(bal))
	if not ShipRegistry.is_loaded():
		_player_label.text = "\n".join(lines)
		return
	for sid_variant in ShipRegistry.ship_ids(ACTOR):
		var sid: StringName = sid_variant
		var info: Dictionary = ShipRegistry.ship_info(sid)
		var hold: Dictionary = GoodsLedger.make_hold(String(sid), String(ACTOR))
		# D-95(d): GoodsLedger.container_used; capacity shows 150 擔 for SH-01 (D-94a／scenario).
		var used: int = GoodsLedger.container_used(hold)
		var cap: int = ShipRegistry.capacity_for_hold(hold)
		var free_slots: int = cap - used
		if free_slots < 0:
			free_slots = 0
		var cargo_bits: PackedStringArray = PackedStringArray()
		if GoodCatalog.is_loaded():
			for gid in GoodCatalog.all_ids():
				var q: int = GoodsLedger.get_qty(hold, StringName(gid))
				if q > 0:
					var gd: GoodDef = GoodCatalog.get_good(String(gid))
					cargo_bits.append("%s×%s" % [gd.name_zh if gd else gid, str(q)])
		var cargo_s: String = "（空）" if cargo_bits.is_empty() else ", ".join(cargo_bits)
		lines.append(
			"船 %s 狀態=%s 港=%s 目的=%s 抵達tick=%s | 艙 %s/%s 擔 餘 %s | 貨 %s" % [
				String(sid),
				str(info.get("state", "")),
				str(info.get("port_id", "")),
				str(info.get("dest_port", "")),
				str(info.get("arrival_tick", "")),
				str(used),
				str(cap),
				str(free_slots),
				cargo_s,
			]
		)
	_player_label.text = "\n".join(lines)


func _append_msg(text: String) -> void:
	if _msg_log == null:
		return
	_msg_log.append_text(text + "\n")
	# trim roughly by recreating if too long — keep simple
	pass


## Test／screenshot helpers (public for tests/ui).
func is_debug_booted() -> bool:
	return _booted


func selected_port() -> StringName:
	return _selected_port


func last_trade_total_li() -> int:
	## Delegates to TradeDesk.last_trade_total_li() (D-95d).
	return TradeDesk.last_trade_total_li()


func force_select_port(port_id: StringName) -> void:
	_selected_port = port_id
	if _sea_map != null:
		_sea_map.set_selected(port_id)
	_refresh_all()


func force_select_good(good_id: StringName) -> void:
	_selected_good = good_id
	_sync_good_option()
	_refresh_all()


func refresh_panels() -> void:
	_refresh_all()


func set_trade_result_text(text: String) -> void:
	if _trade_result != null:
		_trade_result.text = text
	_append_msg(text)
