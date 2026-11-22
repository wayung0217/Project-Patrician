extends Control
## WP-61 Debug sea chart: ports + junctions + lanes from data/sea (and SeaLanes.nodes after boot).
## Lane list: SeaLanes has no public lanes() enumerator → load res://data/sea/lanes/*.tres (介面缺口見 gaps).


signal port_selected(port_id: StringName)

var _nodes: Array = [] ## SeaNode
var _lanes: Array = [] ## {a: Vector2, b: Vector2, id: String}
var _selected: StringName = &""
var _min_x: float = 0.0
var _min_y: float = 0.0
var _span_x: float = 1.0
var _span_y: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(float(DebugConfig.MAP_WIDTH), float(DebugConfig.MAP_HEIGHT))


func set_selected(port_id: StringName) -> void:
	_selected = port_id
	queue_redraw()


func reload_from_sea() -> void:
	_nodes.clear()
	_lanes.clear()
	if SeaLanes.is_loaded():
		for n_variant in SeaLanes.nodes():
			var n: SeaNode = n_variant as SeaNode
			if n != null:
				_nodes.append(n)
	else:
		_load_nodes_from_dir(SeaLanes.NODES_DIR)
	_load_lanes_from_dir(SeaLanes.LANES_DIR)
	_recompute_bounds()
	queue_redraw()


func _load_nodes_from_dir(dir_path: String) -> void:
	var paths: PackedStringArray = _list_tres(dir_path)
	for p in paths:
		var res: Resource = load(p)
		var n: SeaNode = res as SeaNode
		if n != null:
			_nodes.append(n)


func _load_lanes_from_dir(dir_path: String) -> void:
	## Gap workaround: no SeaLanes.lanes() public API — read data files for chart only.
	var by_id: Dictionary = {}
	for n_variant in _nodes:
		var n: SeaNode = n_variant as SeaNode
		by_id[n.node_id] = n
	var paths: PackedStringArray = _list_tres(dir_path)
	for p in paths:
		var res: Resource = load(p)
		var lane: SeaLane = res as SeaLane
		if lane == null:
			continue
		if not by_id.has(lane.node_a) or not by_id.has(lane.node_b):
			continue
		var a: SeaNode = by_id[lane.node_a]
		var b: SeaNode = by_id[lane.node_b]
		_lanes.append({
			"id": lane.lane_id,
			"a": Vector2(float(a.x), float(a.y)),
			"b": Vector2(float(b.x), float(b.y)),
		})


func _list_tres(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var path: String = dir_path
	if not path.ends_with("/"):
		path = path + "/"
	var d: DirAccess = DirAccess.open(path)
	if d == null:
		return out
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.ends_with(".tres"):
			out.append(path + fname)
		fname = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func _recompute_bounds() -> void:
	if _nodes.is_empty():
		_min_x = 0.0
		_min_y = 0.0
		_span_x = 1.0
		_span_y = 1.0
		return
	var min_x: float = float((_nodes[0] as SeaNode).x)
	var max_x: float = min_x
	var min_y: float = float((_nodes[0] as SeaNode).y)
	var max_y: float = min_y
	for n_variant in _nodes:
		var n: SeaNode = n_variant as SeaNode
		var xf: float = float(n.x)
		var yf: float = float(n.y)
		if xf < min_x:
			min_x = xf
		if xf > max_x:
			max_x = xf
		if yf < min_y:
			min_y = yf
		if yf > max_y:
			max_y = yf
	_min_x = min_x
	_min_y = min_y
	_span_x = maxf(1.0, max_x - min_x)
	_span_y = maxf(1.0, max_y - min_y)


func _world_to_local(wx: float, wy: float) -> Vector2:
	var pad: float = float(DebugConfig.MAP_PAD)
	var w: float = size.x - pad * 2.0
	var h: float = size.y - pad * 2.0
	if w < 1.0:
		w = 1.0
	if h < 1.0:
		h = 1.0
	var nx: float = (wx - _min_x) / _span_x
	var ny: float = (wy - _min_y) / _span_y
	# y grows south in data; flip for screen
	return Vector2(pad + nx * w, pad + (1.0 - ny) * h)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.16, 0.22), true)
	for lane_variant in _lanes:
		var lane: Dictionary = lane_variant
		var a: Vector2 = _world_to_local(lane["a"].x, lane["a"].y)
		var b: Vector2 = _world_to_local(lane["b"].x, lane["b"].y)
		draw_line(a, b, Color(0.35, 0.55, 0.75, 0.85), DebugConfig.LANE_WIDTH, true)
	for n_variant in _nodes:
		var n: SeaNode = n_variant as SeaNode
		var p: Vector2 = _world_to_local(float(n.x), float(n.y))
		var is_port: bool = n.kind == SeaNode.KIND_PORT
		var r: float = DebugConfig.NODE_RADIUS_PORT if is_port else DebugConfig.NODE_RADIUS_JUNCTION
		var col: Color = Color(0.95, 0.8, 0.35) if is_port else Color(0.55, 0.65, 0.75)
		if is_port and StringName(n.node_id) == _selected:
			draw_arc(p, r + DebugConfig.SELECTED_RING, 0.0, TAU, 24, Color(1, 1, 1), 2.0, true)
			col = Color(1.0, 0.45, 0.2)
		draw_circle(p, r, col)
		if is_port:
			draw_string(
				ThemeDB.fallback_font,
				p + Vector2(r + 2.0, 4.0),
				n.name_zh if not n.name_zh.is_empty() else n.node_id,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				DebugConfig.FONT_SIZE_BODY - 2,
				Color(0.9, 0.92, 0.95)
			)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit: StringName = _hit_port(mb.position)
	if hit != &"":
		_selected = hit
		queue_redraw()
		port_selected.emit(hit)


func _hit_port(local_pos: Vector2) -> StringName:
	var best: StringName = &""
	var best_d: float = 14.0
	for n_variant in _nodes:
		var n: SeaNode = n_variant as SeaNode
		if n.kind != SeaNode.KIND_PORT:
			continue
		var p: Vector2 = _world_to_local(float(n.x), float(n.y))
		var d: float = local_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = StringName(n.node_id)
	return best
