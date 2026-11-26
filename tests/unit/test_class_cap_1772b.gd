extends GutTest
## 17-72 B／FRM-SYS07-18／D-109(g)：layers.CLASS_CAP bed-share gate.
## Expectations from proposed frm_examples EX-07-18-01…04（C-14：docs/spec 未改；期望值寫死於此）.
## 四測：升／滿／超／關；另 ERR-SYS07-10. 測名含 1772／EX／紅隊.


const ROOT := "user://class_cap_1772b/"
const PORT := "PT-01"
const ACTOR := &"ACT-PLAYER"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const PPM := 1000000
## frm_examples EX-07-18-* 示範值（D-109(g) 試驗值）.
const RICH_SHARE := 200000
const CIT_SHARE := 300000
const BEDS_EX := 100
const CAP_RICH_EX := 20 ## floori(100×200000÷1000000)
const CAP_CIT_EX := 30 ## floori(100×300000÷1000000)

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


class TestSat extends SatisfactionInputProvider:
	var _v: Dictionary = {}

	func set_input(port_id: String, clazz: String, v: float) -> void:
		_v["%s|%s" % [port_id, clazz]] = v

	func satisfaction_input(port_id: StringName, clazz: StringName) -> float:
		var key := "%s|%s" % [String(port_id), String(clazz)]
		if _v.has(key):
			return float(_v[key])
		return 0.5


func before_each() -> void:
	_wipe(ROOT)
	PopulationModel.reset_runtime_state()
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false
	Params._loaded = false


func after_each() -> void:
	PopulationModel.set_class_cap_layer(false)
	Params.load_and_validate(ParamsFixtures.path_demo())


## ——— frm_examples EX-07-18 公式錨點（S9f；非鏡像產品路徑）———


func test_1772_B_EX_07_18_caps_from_frm_examples() -> void:
	## EX-07-18-00: B=100, RICH=200000, CIT=300000, PPM=1000000 → caps 20／30.
	assert_eq((BEDS_EX * RICH_SHARE) / PPM, CAP_RICH_EX)
	assert_eq((BEDS_EX * CIT_SHARE) / PPM, CAP_CIT_EX)
	assert_eq(CAP_RICH_EX + CAP_CIT_EX, 50)
	assert_true(RICH_SHARE + CIT_SHARE <= PPM)


## ——— 升：未滿有升階空間 ———


func test_1772_B_EX_07_18_01_升_under_cap_room() -> void:
	## EX-07-18-01: s0_rich=10／s0_cit=15 → room 10／15；開閘後可升且不超 cap.
	## 期望（示範值）：uncapped up1≈10／up2≈2；開閘後 rich∈(10,20]／cit≤30.
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.9)
	sat.set_input(PORT, "CITIZEN", 0.9)
	sat.set_input(PORT, "RICH", 0.9)
	_boot_pop(sat)
	_setup_be_with_workshops(3)
	_apply_share_prms()
	Params._values["PRM-SYS07-HOUSE_CAPACITY"] = BEDS_EX
	_force_one_residence()
	assert_eq(PopulationModel.housing_capacity(StringName(PORT)), BEDS_EX)
	_zero_pf_except_up()
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 1000000
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 1000000
	PopulationModel.set_port_state(PORT, 70, 15, 10, 0, 900, 900, 900)
	PopulationModel.set_upgrade_streaks(PORT, 999, 999)
	_staff_tier_workshops()
	PopulationModel.set_class_cap_layer(true)
	assert_true(PopulationModel.is_class_cap_on())
	PopulationModel.daily_step(1)
	var rich: int = PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH)
	var cit: int = PopulationModel.population(StringName(PORT), PopulationModel.CLASS_CITIZEN)
	assert_lte(rich, CAP_RICH_EX)
	assert_lte(cit, CAP_CIT_EX)
	## 至少有一階向上流動（room＞0）.
	assert_true(rich > 10 or cit != 15)


## ——— 滿：達 cap 擋向上 ———


func test_1772_B_EX_07_18_02_滿_at_cap_blocks_up() -> void:
	## EX-07-18-02: s0_rich=20／s0_cit=30 → room 0；高速率仍無升階.
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.9)
	sat.set_input(PORT, "CITIZEN", 0.9)
	sat.set_input(PORT, "RICH", 0.9)
	_boot_pop(sat)
	_setup_be_with_workshops(3)
	_apply_share_prms()
	Params._values["PRM-SYS07-HOUSE_CAPACITY"] = BEDS_EX
	_force_one_residence()
	_zero_pf_except_up()
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 1000000
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 1000000
	PopulationModel.set_port_state(PORT, 40, CAP_CIT_EX, CAP_RICH_EX, 0, 900, 900, 900)
	PopulationModel.set_upgrade_streaks(PORT, 999, 999)
	_staff_tier_workshops()
	PopulationModel.set_class_cap_layer(true)
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH), CAP_RICH_EX)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_CITIZEN), CAP_CIT_EX)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_POOR), 40)


## ——— 超：已超 cap 不趕人（紅隊：不得強制移出）———


func test_1772_B_EX_07_18_03_超_red_team_no_force_out() -> void:
	## EX-07-18-03／紅隊：s0_rich=25／s0_cit=35 已超；開閘不趕人、仍擋再升.
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.9)
	sat.set_input(PORT, "CITIZEN", 0.9)
	sat.set_input(PORT, "RICH", 0.9)
	_boot_pop(sat)
	_setup_be_with_workshops(3)
	_apply_share_prms()
	Params._values["PRM-SYS07-HOUSE_CAPACITY"] = BEDS_EX
	_force_one_residence()
	_zero_pf_except_up()
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 1000000
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 1000000
	## 關閉向下流動，鎖定「不趕人」斷言.
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF5_RATE_WK"] = 0
	var over_rich := CAP_RICH_EX + 5
	var over_cit := CAP_CIT_EX + 5
	PopulationModel.set_port_state(PORT, 20, over_cit, over_rich, 0, 900, 900, 900)
	PopulationModel.set_upgrade_streaks(PORT, 999, 999)
	_staff_tier_workshops()
	PopulationModel.set_class_cap_layer(true)
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH), over_rich)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_CITIZEN), over_cit)


## ——— 關：CLASS_CAP＝關 → 與無閘門相同（可超 cap；黃金零差異）———


func test_1772_B_EX_07_18_04_關_layer_off_zero_diff() -> void:
	## EX-07-18-04: 同初值；關＝可超 cap；兩次關跑零差異；開則受 cap.
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.9)
	sat.set_input(PORT, "CITIZEN", 0.9)
	sat.set_input(PORT, "RICH", 0.9)
	var snap_off_a: Dictionary = _run_up_day(sat, false)
	before_each()
	var snap_off_b: Dictionary = _run_up_day(sat, false)
	assert_eq(snap_off_a["rich"], snap_off_b["rich"])
	assert_eq(snap_off_a["cit"], snap_off_b["cit"])
	assert_eq(snap_off_a["poor"], snap_off_b["poor"])
	## 關時可超過 cap（證明閘門未套用）.
	assert_true(snap_off_a["rich"] > CAP_RICH_EX or snap_off_a["cit"] > CAP_CIT_EX)
	before_each()
	var snap_on: Dictionary = _run_up_day(sat, true)
	assert_lte(int(snap_on["rich"]), CAP_RICH_EX)
	assert_lte(int(snap_on["cit"]), CAP_CIT_EX)
	assert_true(
		int(snap_on["rich"]) < int(snap_off_a["rich"])
		or int(snap_on["cit"]) < int(snap_off_a["cit"])
	)


## ——— ERR-SYS07-10 CLASS_SHARE_SUM ———


func test_1772_B_ERR_SYS07_10_CLASS_SHARE_SUM() -> void:
	## 兩階份額合計 > PPM_SCALE → load 拒絕；set_class_cap_layer 亦拒.
	var sat := TestSat.new()
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	Params._values["PRM-SYS07-RICH_BED_SHARE_PPM"] = 600000
	Params._values["PRM-SYS07-CITIZEN_BED_SHARE_PPM"] = 600000
	PopulationModel.set_satisfaction_input_provider(sat)
	var errs: Array = PopulationModel.load_and_validate()
	assert_gt(errs.size(), 0)
	var found := false
	for e in errs:
		if String((e as Dictionary).get("code", "")) == String(PopulationModel.ERR_SYS07_10):
			found = true
	assert_true(found, "load_and_validate must emit ERR-SYS07-10")
	assert_false(PopulationModel.is_loaded())
	## 正常載入後再注入壞值 → enable 失敗且閘門維持關.
	before_each()
	_boot_pop(sat)
	_apply_share_prms()
	Params._values["PRM-SYS07-RICH_BED_SHARE_PPM"] = 600000
	Params._values["PRM-SYS07-CITIZEN_BED_SHARE_PPM"] = 500000
	PopulationModel.set_class_cap_layer(true)
	assert_false(PopulationModel.is_class_cap_on())
	assert_eq(String(PopulationModel.last_error().get("code", "")), String(PopulationModel.ERR_SYS07_10))
	## load _emit + set_class_cap _record = 2 push_error（GUT 計整測累計）.
	assert_push_error_count(errs.size() + 1)


## ——— helpers ———


func _run_up_day(sat: TestSat, class_cap_on: bool) -> Dictionary:
	## Near-cap start so off exceeds caps and on clamps（EX-07-18-04）.
	## s0: poor=70／cit=28／rich=18；cap 30／20；room 2／2.
	_boot_pop(sat)
	_setup_be_with_workshops(3)
	_apply_share_prms()
	Params._values["PRM-SYS07-HOUSE_CAPACITY"] = BEDS_EX
	_force_one_residence()
	_zero_pf_except_up()
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 1000000
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 1000000
	PopulationModel.set_port_state(PORT, 70, 28, 18, 0, 900, 900, 900)
	PopulationModel.set_upgrade_streaks(PORT, 999, 999)
	_staff_tier_workshops()
	PopulationModel.set_class_cap_layer(class_cap_on)
	PopulationModel.daily_step(1)
	return {
		"rich": PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH),
		"cit": PopulationModel.population(StringName(PORT), PopulationModel.CLASS_CITIZEN),
		"poor": PopulationModel.population(StringName(PORT), PopulationModel.CLASS_POOR),
	}


func _apply_share_prms() -> void:
	Params._values["PRM-SYS07-RICH_BED_SHARE_PPM"] = RICH_SHARE
	Params._values["PRM-SYS07-CITIZEN_BED_SHARE_PPM"] = CIT_SHARE


func _zero_pf_except_up() -> void:
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF5_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_BEGGAR_RATE_WK"] = 0
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 0


func _boot_pop(sat: SatisfactionInputProvider) -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	PopulationModel.set_satisfaction_input_provider(sat)
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	PopulationModel.set_master_seed(1)


func _setup_be_with_workshops(tier_max: int = 2) -> void:
	BuildingEconomy.set_population_provider(PopulationModel.get_population_provider())
	BuildingEconomy.set_workforce_provider(PopulationModel.get_workforce_provider())
	_setup_core_ledgers()
	_write_min_layout()
	var dir := ROOT + "buildings/"
	_save_def(dir, "KT-01", "KONTOR", "", 0, 1.0)
	_save_def(dir, "IB-A", "IND2", "GD-001", 2, 1.0)
	_save_def(dir, "IB-B", "IND2", "GD-001", 2, 1.0)
	if tier_max >= 3:
		_save_def(dir, "IB-C", "IND3", "GD-002", 3, 1.0)
	_save_def(dir, "RB-01", "RESIDENCE", "", 0, 1.0)
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)
	_force_workshop("IB-A", "IND2")
	_force_workshop("IB-B", "IND2")
	if tier_max >= 3:
		_force_workshop("IB-C", "IND3")


func _force_one_residence() -> void:
	## Clear auto residences from zone open-at-start if any; register exactly one.
	var bld := Building.new()
	bld.building_id = StringName("BLD:%s:RES0" % PORT)
	bld.type = &"RB-01"
	bld.build_class = &"RESIDENCE"
	bld.owner = ACTOR
	bld.port_id = PORT
	bld.state = Building.State.ACTIVE
	bld.slot_id = StringName("SLOT:%s:0010" % PORT)
	BuildingEconomy._register_building(bld)


func _staff_tier_workshops() -> void:
	for b in BuildingEconomy.workplaces(StringName(PORT)):
		var bid: StringName = (b as Building).building_id
		var def: BuildingDef = BuildingEconomy._building_defs[String((b as Building).type)]
		if def.tier >= 2:
			PopulationModel.set_workers(bid, 1)
		else:
			PopulationModel.set_workers(bid, 0)


func _setup_core_ledgers() -> void:
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var ports_dir := _build_valid_ports(port_count, ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)


func _force_workshop(type_id: String, bclass: String) -> void:
	var bld := Building.new()
	bld.building_id = StringName("BLD:%s:%s" % [PORT, type_id])
	bld.type = StringName(type_id)
	bld.build_class = StringName(bclass)
	bld.owner = ACTOR
	bld.port_id = PORT
	bld.state = Building.State.ACTIVE
	BuildingEconomy._register_building(bld)


func _write_min_layout() -> void:
	_write_zone(ROOT + "zones/", PORT, 1, 1, 8, 1)
	_write_zone(ROOT + "zones/", PORT, 2, 1, 4, 0)
	_write_city(ROOT + "city_center/", PORT, 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "buildings/"))


func _save_def(dir: String, type_id: String, bclass: String, out_g: String, tier: int, base: float) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = bclass
	d.output_good_id = out_g
	d.tier = tier
	d.max_workers = 4
	d.base_output_per_worker = base
	ResourceSaver.save(d, dir + type_id + ".tres")


func _write_zone(dir: String, port_id: String, zone: int, rings: int, slots: int, open_at: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var z := ZoneDef.new()
	z.port_id = port_id
	z.zone = zone
	z.slot_share = 0.5
	z.rings = rings
	z.slots = slots
	z.open_at_start = open_at
	ResourceSaver.save(z, dir + "%s__%d.tres" % [port_id, zone])


func _write_city(dir: String, port_id: String, public_slots: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c := CityCenterDef.new()
	c.port_id = port_id
	c.public_slots = public_slots
	ResourceSaver.save(c, dir + port_id + ".tres")


func _build_valid_goods(dir: String) -> String:
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": "米", "build": false},
		{"id": "GD-002", "name": "鹽", "build": false},
		{"id": "GD-003", "name": "木材", "build": true},
		{"id": "GD-004", "name": "魚乾", "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], false),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(_make_good(gid, gid, tier, false, false, false), dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	return dir


func _make_good(
	id: String, name_zh: String, tier: int, is_staple: bool, is_build: bool, is_strategic: bool
) -> GoodDef:
	var g := GoodDef.new()
	g.good_id = id
	g.name_zh = name_zh
	g.tier = tier
	g.is_staple = is_staple
	g.is_build_material = is_build
	g.is_strategic = is_strategic
	g.base_price_li = 10
	g.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
	return g


func _build_valid_ports(port_count: int, dir: String) -> String:
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var free_count: int = _valid_free_count(port_count)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	for i in range(port_count):
		var n: int = i + 1
		var port_id := "PT-%02d" % n
		var def := PortDef.new()
		def.port_id = port_id
		def.name_zh = "港%d" % n
		def.is_free_port = i < free_count
		def.draft_limit_class = 0
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


func _valid_free_count(port_count: int) -> int:
	var ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	for c in range(port_count + 1):
		var ratio: float = float(c) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return c
	return int(ceil(float(port_count) * ratio_min))


func _wipe(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var n: String = dir.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		var child: String = abs_path.path_join(n)
		if dir.current_is_dir():
			_wipe(path.path_join(n))
			DirAccess.remove_absolute(child)
		else:
			DirAccess.remove_absolute(child)
	dir.list_dir_end()
