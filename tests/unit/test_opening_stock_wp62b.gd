extends GutTest
## WP-62b／D-97(c)／EX-08-21-01..03: opening MARKET stock GENESIS.


const PORT := "PT-10"
const PORT_B := "PT-01"


class PotProv:
	extends RefCounted
	var _map: Dictionary = {}

	func set_pot(port_id: String, good_id: String, v: int) -> void:
		_map["%s|%s" % [port_id, good_id]] = v

	func weekly_potential_demand(port_id: StringName, good_id: StringName) -> int:
		return int(_map.get("%s|%s" % [String(port_id), String(good_id)], 0))


func before_each() -> void:
	BuildingEconomy._loaded = false
	DemandModel.clear_potential_demand_provider()
	DemandModel._loaded = false
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false
	Params._loaded = false


func test_EX_08_21_01_wanggang_rice_opening_stock() -> void:
	## EX-08-21-01: PT-10 GD-001；pot=71；2×米坊 W=148.779 → q=879.
	var pot := PotProv.new()
	pot.set_pot(PORT, "GD-001", 71)
	_boot(pot)
	_spawn_workshop(PORT, "IB-01", "GD-001", 3.252, 25)
	_spawn_workshop(PORT, "IB-01b", "GD-001", 3.252, 25)
	assert_eq(BuildingEconomy.apply_opening_market_stock().size(), 0)
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-001"), 879)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_EX_08_21_02_yuegang_brick_opening_stock() -> void:
	## EX-08-21-02: PT-01 GD-004；pot=0；3×砖石 W=247.782 → q=1486.
	var pot := PotProv.new()
	pot.set_pot(PORT_B, "GD-004", 0)
	_boot(pot)
	var base: float = 247.782 / (25.0 * 1.83)
	for j in range(3):
		_spawn_workshop(PORT_B, "IB-BR-%d" % j, "GD-004", base, 25)
	assert_eq(BuildingEconomy.apply_opening_market_stock().size(), 0)
	var mkt: Dictionary = GoodsLedger.make_market(PORT_B)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-004"), 1486)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_EX_08_21_03_zero_q_skips_genesis() -> void:
	## EX-08-21-03: pot=0；no workshops → q=0；qty stays 0.
	var pot := PotProv.new()
	_boot(pot)
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-001"), 0)
	assert_eq(BuildingEconomy.apply_opening_market_stock().size(), 0)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-001"), 0)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func _boot(pot: PotProv) -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	Params._values["PRM-SYS08-OPENING_STOCK_DEMAND_WEEKS"] = 4
	Params._values["PRM-SYS08-OPENING_STOCK_OUTPUT_WEEKS"] = 2
	Params._values["PRM-SYS08-OUTPUT_PER_WORKER_K"] = 1.83
	assert_eq(GoodCatalog.load_and_validate("res://data/goods/").size(), 0)
	assert_eq(PortRegistry.load_and_validate("res://data/ports/").size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	DemandModel.set_potential_demand_provider(pot)
	DemandModel._loaded = true
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._building_defs = {}
	BuildingEconomy._buildings = {}
	BuildingEconomy._buildings_by_port = {}
	BuildingEconomy._bld_seq_by_port = {}


func _spawn_workshop(
	port_id: String, type_id: String, out_g: String, base: float, max_w: int
) -> void:
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = "IND1"
	d.output_good_id = out_g
	d.tier = 1
	d.max_workers = max_w
	d.base_output_per_worker = base
	BuildingEconomy._building_defs[type_id] = d
	var bld := Building.new()
	bld.building_id = BuildingEconomy._next_bld_id(port_id)
	bld.type = StringName(type_id)
	bld.build_class = &"IND1"
	bld.owner = CashLedger.make_city_id(port_id)
	bld.port_id = port_id
	bld.state = Building.State.ACTIVE
	BuildingEconomy._register_building(bld)
