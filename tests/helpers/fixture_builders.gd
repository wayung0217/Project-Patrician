class_name FixtureBuilders
extends RefCounted
## WP-59 T6: shared port／goods fixture builders for unit tests.


const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


static func wipe_dir(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		_wipe_abs(abs_path)


static func _wipe_abs(abs_path: String) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child: String = abs_path.path_join(name)
		if dir.current_is_dir():
			_wipe_abs(child)
			DirAccess.remove_absolute(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()


static func valid_free_count(port_count: int) -> int:
	## Smallest free_count whose ratio ∈ [PRM min, max] (C-03: no bare ratio literals).
	var ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	if port_count <= 0:
		return 0
	var free_count: int = 0
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return free_count
		free_count += 1
	return 0


static func build_valid_ports(
	port_count: int,
	dir: String,
	free_count: int = -1,
	draft_limit_class: int = 0
) -> String:
	## Minimal valid PortRegistry fixture: PT-01 PRODUCER, others TERMINAL.
	wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if free_count < 0:
		free_count = valid_free_count(port_count)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	for i in range(port_count):
		var n: int = i + 1
		var port_id := "PT-%02d" % n
		var def := PortDef.new()
		def.port_id = port_id
		def.name_zh = "港%d" % n
		def.is_free_port = i < free_count
		def.draft_limit_class = draft_limit_class
		def.regime_id = "RG-TEST"
		def.role_cells = {}
		for good_variant in good_ids:
			var good_id: String = String(good_variant)
			var cell := RoleCell.new()
			if i == 0:
				cell.role = PortRegistry.ROLE_PRODUCER
				cell.base_output_per_season = 1
				cell.downstream_terminals = PackedStringArray()
			else:
				cell.role = PortRegistry.ROLE_TERMINAL
				cell.base_output_per_season = 0
				cell.downstream_terminals = PackedStringArray()
			def.role_cells[good_id] = cell
		ResourceSaver.save(def, dir + "%s.tres" % port_id)
	return dir


static func make_good(
	good_id: String,
	name_zh: String,
	tier: int,
	is_staple: bool,
	is_build_material: bool,
	is_strategic: bool,
	base_price_li: int
) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = good_id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = is_staple
	def.is_build_material = is_build_material
	def.is_strategic = is_strategic
	def.base_price_li = base_price_li
	## D-08a: year-full from PRM-SYS00-SEASONS_PER_YEAR (never literal 15).
	def.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
	return def


static func force_controlled_producer_on_free_port(dir: String) -> void:
	## Free port PT-01 already PRODUCER; pick a controlled_scale_only good (T5: must fail if none).
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	var target: String = ""
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	for id in good_ids:
		var g: GoodDef = GoodCatalog.get_good(id)
		if g.tier > free_max or g.is_strategic:
			target = id
			break
	assert(
		not target.is_empty(),
		"force_controlled_producer_on_free_port: no controlled_scale_only good in catalog"
	)
	assert(GoodCatalog.get_good(target).controlled_scale_only)
	## PT-01 already produces every good in build_valid_ports; nothing further to rewrite.
	var _dir_ok: String = dir
