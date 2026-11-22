extends Node
## Autoload: SeaLanes — SYS-14 sea chart load／validate／pathfind (TechSpec 13-04／13-05 / D-14c／D-14e).
## _ready() field init only; load_and_validate() reads res://data/sea/ (2.2-01).
## Pathfinding: Dijkstra weight＝waypoints; intermediate nodes JUNCTION only (13-05).
## Do NOT implement ships／draft／sea risk (WP-30／31 out of scope).

const SYS_ID := &"SYS-14"
const SCRIPT_PATH := "res://autoload/sea_lanes.gd"

const SEA_DIR := "res://data/sea/"
const NODES_DIR := SEA_DIR + "nodes/"
const REGIONS_DIR := SEA_DIR + "regions/"
const LANES_DIR := SEA_DIR + "lanes/"
const TRES_SUFFIX := ".tres"

const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"

const ERR_SYS14_01 := &"ERR-SYS14-01"
const ERR_SYS14_03 := &"ERR-SYS14-03"
const ERR_SYS14_04 := &"ERR-SYS14-04"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_PORT_REGISTRY_NOT_LOADED := &"PORT_REGISTRY_NOT_LOADED"
const CODE_NOT_LOADED := &"NOT_LOADED"
const CODE_DIR_OPEN := &"DIR_OPEN"
const CODE_LOAD_FAIL := &"LOAD_FAIL"
const CODE_LOAD_TYPE := &"LOAD_TYPE"

const FIELD_NODE_ID := "node_id"
const FIELD_KIND := "kind"
const FIELD_LANE_ID := "lane_id"
const FIELD_NODE_A := "node_a"
const FIELD_NODE_B := "node_b"
const FIELD_REGION_ID := "region_id"
const FIELD_WAYPOINTS := "waypoints"
const FIELD_PORT_COUNT := "port_count"
const FIELD_REACHABILITY := "reachability"
const FIELD_PATH := "path"
const FIELD_PARAMS := "Params"
const FIELD_PORT_REGISTRY := "PortRegistry"

const PATH_KEY_LANE_ID := "lane_id"
const PATH_KEY_FROM_NODE := "from_node"

const WAYPOINTS_FAILURE := -1

var _nodes: Dictionary = {} ## node_id:String → SeaNode
var _regions: Dictionary = {} ## region_id:String → SeaRegion
var _lanes: Dictionary = {} ## lane_id:String → SeaLane
var _node_ids_sorted: PackedStringArray = PackedStringArray()
var _lane_ids_sorted: PackedStringArray = PackedStringArray()
## node_id → Array[{lane_id, other, waypoints}] sorted by lane_id ascending (13-05／C-08).
var _adj: Dictionary = {}
var _loaded: bool = false
var _last_error: Dictionary = {}


func _ready() -> void:
	_clear_state()


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func load_and_validate(
	nodes_dir: String = NODES_DIR,
	regions_dir: String = REGIONS_DIR,
	lanes_dir: String = LANES_DIR
) -> Array:
	var errors: Array = []
	_clear_state()

	if not Params.is_loaded():
		errors.append(
			_err(
				CODE_PARAMS_NOT_LOADED,
				nodes_dir,
				FIELD_PARAMS,
				null,
				"Params must load_and_validate before SeaLanes"
			)
		)
		_emit_errors(errors)
		return errors

	if not PortRegistry.is_loaded():
		errors.append(
			_err(
				CODE_PORT_REGISTRY_NOT_LOADED,
				nodes_dir,
				FIELD_PORT_REGISTRY,
				null,
				"PortRegistry must load_and_validate before SeaLanes"
			)
		)
		_emit_errors(errors)
		return errors

	_load_nodes(nodes_dir, errors)
	_load_regions(regions_dir, errors)
	_load_lanes(lanes_dir, errors)
	if not errors.is_empty():
		_emit_errors(errors)
		return errors

	_build_adjacency()
	errors.append_array(_validate_loaded())
	if not errors.is_empty():
		_clear_graph_only()
		_emit_errors(errors)
		return errors

	_loaded = true
	return errors


func validate() -> Array:
	if not _loaded:
		var not_loaded: Dictionary = _err(
			CODE_NOT_LOADED,
			SEA_DIR,
			"",
			null,
			"SeaLanes.validate called before successful load"
		)
		_emit_errors([not_loaded])
		return [not_loaded]
	var errors: Array = _validate_loaded()
	_emit_errors(errors)
	return errors


func nodes() -> Array:
	_clear_last_error()
	if not _loaded:
		_record_fail(CODE_NOT_LOADED, SEA_DIR, null, "SeaLanes.nodes before load")
		return []
	var out: Array = []
	for id_variant in _node_ids_sorted:
		out.append(_nodes[String(id_variant)])
	return out


func waypoints(lane_id: Variant) -> int:
	_clear_last_error()
	if not _loaded:
		_record_fail(CODE_NOT_LOADED, FIELD_LANE_ID, lane_id, "SeaLanes.waypoints before load")
		return WAYPOINTS_FAILURE
	var key := String(lane_id)
	if not _lanes.has(key):
		_record_fail(ERR_SYS14_01, FIELD_LANE_ID, key, "unknown lane_id")
		return WAYPOINTS_FAILURE
	return (_lanes[key] as SeaLane).waypoints


func lane_endpoints(lane_id: Variant) -> PackedStringArray:
	## Returns [node_a, node_b] for a known lane; empty if unknown (WP-30 reroute).
	_clear_last_error()
	if not _loaded:
		_record_fail(CODE_NOT_LOADED, FIELD_LANE_ID, lane_id, "SeaLanes.lane_endpoints before load")
		return PackedStringArray()
	var key := String(lane_id)
	if not _lanes.has(key):
		_record_fail(ERR_SYS14_01, FIELD_LANE_ID, key, "unknown lane_id")
		return PackedStringArray()
	var lane: SeaLane = _lanes[key] as SeaLane
	return PackedStringArray([lane.node_a, lane.node_b])


func region(lane_id: Variant) -> StringName:
	_clear_last_error()
	if not _loaded:
		_record_fail(CODE_NOT_LOADED, FIELD_LANE_ID, lane_id, "SeaLanes.region before load")
		return &""
	var key := String(lane_id)
	if not _lanes.has(key):
		_record_fail(ERR_SYS14_01, FIELD_LANE_ID, key, "unknown lane_id")
		return &""
	return StringName((_lanes[key] as SeaLane).region_id)


func path(from_node: Variant, to_node: Variant) -> Array:
	## FRM-SYS14-02／13-05: Dijkstra; Array[{lane_id, from_node}].
	_clear_last_error()
	if not _loaded:
		_record_fail(CODE_NOT_LOADED, FIELD_PATH, null, "SeaLanes.path before load")
		return []
	var src := String(from_node)
	var dst := String(to_node)
	if src == dst:
		_record_fail(ERR_SYS14_04, FIELD_PATH, src, "origin equals destination (ERR-SYS14-04)")
		return []
	if not _nodes.has(src) or not _nodes.has(dst):
		_record_fail(ERR_SYS14_03, FIELD_PATH, "%s→%s" % [src, dst], "no path (unknown node)")
		return []
	var result: Array = _dijkstra(src, dst)
	if result.is_empty():
		_record_fail(ERR_SYS14_03, FIELD_PATH, "%s→%s" % [src, dst], "no path (ERR-SYS14-03)")
		return []
	return result


# --- load ---


func _load_nodes(nodes_dir: String, errors: Array) -> void:
	var dir_path := _ensure_trailing_slash(nodes_dir)
	var paths: Array = _list_tres_paths(dir_path, errors)
	for path_variant in paths:
		var path: String = String(path_variant)
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			errors.append(_err(CODE_LOAD_FAIL, path, "", null, "ResourceLoader.load failed"))
			continue
		if not (res is SeaNode):
			errors.append(
				_err(CODE_LOAD_TYPE, path, "", res.get_class(), "expected SeaNode Resource")
			)
			continue
		var node: SeaNode = res as SeaNode
		if _nodes.has(node.node_id):
			errors.append(
				_err(
					ERR_SYS14_01,
					path,
					FIELD_NODE_ID,
					node.node_id,
					"duplicate node_id"
				)
			)
			continue
		_nodes[node.node_id] = node
	_node_ids_sorted = PackedStringArray(_nodes.keys())
	_node_ids_sorted.sort()


func _load_regions(regions_dir: String, errors: Array) -> void:
	var dir_path := _ensure_trailing_slash(regions_dir)
	var paths: Array = _list_tres_paths(dir_path, errors)
	for path_variant in paths:
		var path: String = String(path_variant)
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			errors.append(_err(CODE_LOAD_FAIL, path, "", null, "ResourceLoader.load failed"))
			continue
		if not (res is SeaRegion):
			errors.append(
				_err(CODE_LOAD_TYPE, path, "", res.get_class(), "expected SeaRegion Resource")
			)
			continue
		var region_res: SeaRegion = res as SeaRegion
		if _regions.has(region_res.region_id):
			errors.append(
				_err(
					ERR_SYS14_01,
					path,
					FIELD_REGION_ID,
					region_res.region_id,
					"duplicate region_id"
				)
			)
			continue
		_regions[region_res.region_id] = region_res


func _load_lanes(lanes_dir: String, errors: Array) -> void:
	var dir_path := _ensure_trailing_slash(lanes_dir)
	var paths: Array = _list_tres_paths(dir_path, errors)
	for path_variant in paths:
		var path: String = String(path_variant)
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			errors.append(_err(CODE_LOAD_FAIL, path, "", null, "ResourceLoader.load failed"))
			continue
		if not (res is SeaLane):
			errors.append(
				_err(CODE_LOAD_TYPE, path, "", res.get_class(), "expected SeaLane Resource")
			)
			continue
		var lane: SeaLane = res as SeaLane
		if _lanes.has(lane.lane_id):
			errors.append(
				_err(
					ERR_SYS14_01,
					path,
					FIELD_LANE_ID,
					lane.lane_id,
					"duplicate lane_id"
				)
			)
			continue
		_lanes[lane.lane_id] = lane
	_lane_ids_sorted = PackedStringArray(_lanes.keys())
	_lane_ids_sorted.sort()


func _build_adjacency() -> void:
	_adj = {}
	for id_variant in _node_ids_sorted:
		_adj[String(id_variant)] = []
	for lane_id_variant in _lane_ids_sorted:
		var lane_id: String = String(lane_id_variant)
		var lane: SeaLane = _lanes[lane_id]
		var a: String = lane.node_a
		var b: String = lane.node_b
		if not _adj.has(a) or not _adj.has(b):
			continue
		(_adj[a] as Array).append(
			{"lane_id": lane_id, "other": b, "waypoints": lane.waypoints}
		)
		(_adj[b] as Array).append(
			{"lane_id": lane_id, "other": a, "waypoints": lane.waypoints}
		)
	for id_variant in _node_ids_sorted:
		var key: String = String(id_variant)
		var edges: Array = _adj[key]
		edges.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
			return String(x["lane_id"]) < String(y["lane_id"])
		)


func _validate_loaded() -> Array:
	## FRM-SYS14-01 — collect every error (C-06) as ERR-SYS14-01.
	var errors: Array = []
	var port_nodes: Dictionary = {}

	for id_variant in _node_ids_sorted:
		var node_id: String = String(id_variant)
		var node: SeaNode = _nodes[node_id]
		if node.kind != SeaNode.KIND_PORT and node.kind != SeaNode.KIND_JUNCTION:
			errors.append(
				_err(
					ERR_SYS14_01,
					NODES_DIR,
					FIELD_KIND,
					node.kind,
					"kind must be PORT or JUNCTION (%s)" % node_id
				)
			)
			continue
		if node.kind == SeaNode.KIND_PORT:
			port_nodes[node_id] = node
			var port_def: Variant = PortRegistry.get_port(node_id)
			if port_def == null:
				errors.append(
					_err(
						ERR_SYS14_01,
						NODES_DIR,
						FIELD_NODE_ID,
						node_id,
						"PORT node has no matching PortDef"
					)
				)

	## Prefer PortRegistry loaded count (SYS-14 PORT completeness); fallback PRM-SYS02-PORT_COUNT_MAX.
	var expected_ports: int = (
		PortRegistry.all_ids().size()
		if PortRegistry.is_loaded()
		else Params.get_int(PRM_PORT_COUNT_MAX)
	)
	if port_nodes.size() != expected_ports:
		errors.append(
			_err(
				ERR_SYS14_01,
				NODES_DIR,
				FIELD_PORT_COUNT,
				port_nodes.size(),
				"expected %s PORT nodes, got %s" % [expected_ports, port_nodes.size()]
			)
		)

	# Every PortRegistry port must appear as a PORT node (16 港齊全).
	for port_variant in PortRegistry.all_ids():
		var port_id: String = String(port_variant)
		if not port_nodes.has(port_id):
			errors.append(
				_err(
					ERR_SYS14_01,
					NODES_DIR,
					FIELD_NODE_ID,
					port_id,
					"PortRegistry port missing from sea nodes"
				)
			)

	var undirected_pairs: Dictionary = {}
	for lane_id_variant in _lane_ids_sorted:
		var lane_id: String = String(lane_id_variant)
		var lane: SeaLane = _lanes[lane_id]
		if not _nodes.has(lane.node_a) or not _nodes.has(lane.node_b):
			errors.append(
				_err(
					ERR_SYS14_01,
					LANES_DIR,
					FIELD_LANE_ID,
					lane_id,
					"lane endpoint node missing"
				)
			)
		elif lane.node_a == lane.node_b:
			errors.append(
				_err(
					ERR_SYS14_01,
					LANES_DIR,
					FIELD_NODE_A,
					lane.node_a,
					"lane endpoints must differ (%s)" % lane_id
				)
			)
		else:
			var pair_key: String = _pair_key(lane.node_a, lane.node_b)
			if undirected_pairs.has(pair_key):
				errors.append(
					_err(
						ERR_SYS14_01,
						LANES_DIR,
						FIELD_LANE_ID,
						lane_id,
						"duplicate undirected node pair %s (also %s)"
						% [pair_key, undirected_pairs[pair_key]]
					)
				)
			else:
				undirected_pairs[pair_key] = lane_id

		if not _regions.has(lane.region_id):
			errors.append(
				_err(
					ERR_SYS14_01,
					LANES_DIR,
					FIELD_REGION_ID,
					lane.region_id,
					"region_id missing for lane %s" % lane_id
				)
			)

		if typeof(lane.waypoints) != TYPE_INT or lane.waypoints < 1:
			errors.append(
				_err(
					ERR_SYS14_01,
					LANES_DIR,
					FIELD_WAYPOINTS,
					lane.waypoints,
					"waypoints must be int ≥ 1 (%s)" % lane_id
				)
			)

	# Pairwise port reachability under FRM-SYS14-02 rules.
	var port_ids: PackedStringArray = PackedStringArray(port_nodes.keys())
	port_ids.sort()
	for i in range(port_ids.size()):
		for j in range(i + 1, port_ids.size()):
			var a: String = String(port_ids[i])
			var b: String = String(port_ids[j])
			if _dijkstra(a, b).is_empty():
				errors.append(
					_err(
						ERR_SYS14_01,
						SEA_DIR,
						FIELD_REACHABILITY,
						"%s→%s" % [a, b],
						"ports not mutually reachable under JUNCTION-only intermediates"
					)
				)

	return errors


# --- pathfinding (13-05) ---


func _dijkstra(src: String, dst: String) -> Array:
	## Returns Array[{lane_id, from_node}] or empty if unreachable.
	## Tie-break: waypoints → hop count → lane_id sequence lexicographic.
	var best_cost: Dictionary = {} ## node → int
	var best_hops: Dictionary = {}
	var best_seq: Dictionary = {} ## node → PackedStringArray of lane_ids
	var best_path: Dictionary = {} ## node → Array of hop dicts
	var settled: Dictionary = {}

	best_cost[src] = 0
	best_hops[src] = 0
	best_seq[src] = PackedStringArray()
	best_path[src] = []

	while true:
		var u: String = ""
		for cand_variant in _node_ids_sorted:
			var cand: String = String(cand_variant)
			if settled.has(cand):
				continue
			if not best_cost.has(cand):
				continue
			if u == "":
				u = cand
				continue
			if _key_better(
				int(best_cost[cand]),
				int(best_hops[cand]),
				best_seq[cand] as PackedStringArray,
				int(best_cost[u]),
				int(best_hops[u]),
				best_seq[u] as PackedStringArray
			):
				u = cand
		if u == "":
			break
		settled[u] = true
		if u == dst:
			break

		if not _adj.has(u):
			continue
		for edge_variant in _adj[u]:
			var edge: Dictionary = edge_variant
			var other: String = String(edge["other"])
			if not _is_allowed_next(other, src, dst):
				continue
			var lane_id: String = String(edge["lane_id"])
			var w: int = int(edge["waypoints"])
			var new_cost: int = int(best_cost[u]) + w
			var new_hops: int = int(best_hops[u]) + 1
			var new_seq: PackedStringArray = (best_seq[u] as PackedStringArray).duplicate()
			new_seq.append(lane_id)
			var new_path: Array = (best_path[u] as Array).duplicate()
			new_path.append({PATH_KEY_LANE_ID: lane_id, PATH_KEY_FROM_NODE: u})

			if not best_cost.has(other) or _key_better(
				new_cost,
				new_hops,
				new_seq,
				int(best_cost[other]),
				int(best_hops[other]),
				best_seq[other] as PackedStringArray
			):
				best_cost[other] = new_cost
				best_hops[other] = new_hops
				best_seq[other] = new_seq
				best_path[other] = new_path

	if not best_path.has(dst):
		return []
	return best_path[dst] as Array


func _is_allowed_next(node_id: String, src: String, dst: String) -> bool:
	## Intermediate nodes must be JUNCTION; start／end ports exempt (13-05).
	if node_id == dst:
		return true
	if node_id == src:
		return true
	var node: SeaNode = _nodes[node_id]
	return node.kind == SeaNode.KIND_JUNCTION


func _key_better(
	cost_a: int,
	hops_a: int,
	seq_a: PackedStringArray,
	cost_b: int,
	hops_b: int,
	seq_b: PackedStringArray
) -> bool:
	if cost_a != cost_b:
		return cost_a < cost_b
	if hops_a != hops_b:
		return hops_a < hops_b
	return _seq_less(seq_a, seq_b)


func _seq_less(a: PackedStringArray, b: PackedStringArray) -> bool:
	var n: int = mini(a.size(), b.size())
	for i in range(n):
		var sa: String = String(a[i])
		var sb: String = String(b[i])
		if sa < sb:
			return true
		if sa > sb:
			return false
	return a.size() < b.size()


# --- helpers ---


func _pair_key(a: String, b: String) -> String:
	if a < b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]


func _list_tres_paths(dir_path: String, errors: Array) -> Array:
	var out: Array = []
	var abs_dir: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_dir):
		# Empty／missing formal dir is valid input; reachability／port checks catch emptiness.
		return out
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		errors.append(
			_err(CODE_DIR_OPEN, dir_path, "", DirAccess.get_open_error(), "cannot open directory")
		)
		return out
	var names: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(TRES_SUFFIX):
			names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for name_variant in names:
		out.append(dir_path.path_join(String(name_variant)))
	return out


func _ensure_trailing_slash(path: String) -> String:
	if path.ends_with("/"):
		return path
	return "%s/" % path


func _clear_state() -> void:
	_clear_graph_only()
	_loaded = false
	_clear_last_error()


func _clear_graph_only() -> void:
	_nodes = {}
	_regions = {}
	_lanes = {}
	_node_ids_sorted = PackedStringArray()
	_lane_ids_sorted = PackedStringArray()
	_adj = {}
	_loaded = false


func _clear_last_error() -> void:
	_last_error = {}


func _record_fail(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = _err(code, SCRIPT_PATH, field, value, message)
	push_error("SeaLanes: %s" % str(_last_error))


func _err(
	code: StringName,
	file_path: String,
	field: String,
	value: Variant,
	message: String
) -> Dictionary:
	return ErrorInfoUtil.make_validation(code, SYS_ID, file_path, field, value, message)


func _emit_errors(errors: Array) -> void:
	for err_variant in errors:
		push_error("SeaLanes: %s" % str(err_variant))
