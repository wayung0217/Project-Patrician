extends GutTest
## WP-68／D-115(a)／FRM-SYS08-24＋D-100 built-ratio.
## Fixtures／in-memory only；no git；no res://data writes (D-114d).


const PORT := "PT-10"


func before_each() -> void:
	BuildingEconomy._loaded = false
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	Params._loaded = false
	PopulationModel._loaded = false
	BuildingEconomy.set_city_housing_layer(false)
	## Swallow expected push_error from failed order_build／validate paths.
	for e in get_errors():
		e.handled = true


func test_WP68_switch_off_never_runs() -> void:
	_boot_min()
	BuildingEconomy.set_city_housing_layer(false)
	_prep_port_with_empty_slot()
	_force_housing_trigger_conditions()
	var before: int = _residence_count()
	BuildingEconomy._season_city_auto_housing(PORT)
	assert_eq(_residence_count(), before, "switch off → no housing build")


func test_WP68_02_beggars_below_capacity_no_build() -> void:
	## ② beggars < HOUSE_CAPACITY → no build.
	_boot_min()
	BuildingEconomy.set_city_housing_layer(true)
	_prep_port_with_empty_slot()
	_inject_pop(0, 0, 0, 10) ## beggars 10 < 100
	_zero_free_beds_by_filling()
	var before: int = _residence_count()
	BuildingEconomy._season_city_auto_housing(PORT)
	assert_eq(_residence_count(), before)


func test_WP68_02_free_beds_blocks() -> void:
	## ② free beds > 0 → no build even with many beggars.
	_boot_min()
	BuildingEconomy.set_city_housing_layer(true)
	_prep_port_with_empty_slot()
	## One empty ACTIVE residence → beds=100, residents=0 → free>0.
	_add_active_residence("BLD-R-EMPTY")
	_inject_pop(0, 0, 0, 200)
	var before: int = _residence_count()
	BuildingEconomy._season_city_auto_housing(PORT)
	assert_eq(_residence_count(), before)


func test_WP68_03_insufficient_reserve_no_build() -> void:
	## ③ balance < 2× build cash → no build.
	_boot_min()
	BuildingEconomy.set_city_housing_layer(true)
	_prep_port_with_empty_slot()
	_force_housing_trigger_conditions()
	var city: StringName = CashLedger.make_city_id(PORT)
	var build_cash: int = int(Params.get_value("PRM-SYS08-BUILD_CASH_LI")["RESIDENCE"])
	## Fund less than 2×.
	_set_city_balance(city, build_cash)
	var before: int = _residence_count()
	BuildingEconomy._season_city_auto_housing(PORT)
	assert_eq(_residence_count(), before)


func test_WP68_04_max_per_season() -> void:
	## ④ MAX_PER_SEASON＝1 → at most one.
	_boot_min()
	BuildingEconomy.set_city_housing_layer(true)
	_prep_port_with_empty_slot(3)
	_force_housing_trigger_conditions()
	var city: StringName = CashLedger.make_city_id(PORT)
	var build_cash: int = int(Params.get_value("PRM-SYS08-BUILD_CASH_LI")["RESIDENCE"])
	_set_city_balance(city, build_cash * 10)
	## One season_step call：MAX_PER_SEASON＝1 → exactly one new residence even with many empty slots.
	var before: int = _residence_count()
	BuildingEconomy._season_city_auto_housing(PORT)
	assert_eq(_residence_count(), before + 1)


func test_WP68_05_outermost_unowned_only() -> void:
	## ⑤ prefers outermost；skips player-owned.
	_boot_min()
	BuildingEconomy.set_city_housing_layer(true)
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	_register_rb01()
	var city: StringName = CashLedger.make_city_id(PORT)
	CashLedger.create_account(city, Account.Kind.CITY)
	var s_inner := _make_civil_slot("SL-IN", 1, 1, city)
	var s_outer := _make_civil_slot("SL-OUT", 1, 5, city)
	var s_player := _make_civil_slot("SL-PL", 1, 9, &"ACTOR-P1")
	BuildingEconomy._slots_by_port[PORT] = [s_inner, s_outer, s_player]
	BuildingEconomy._slots[String(s_inner.slot_id)] = s_inner
	BuildingEconomy._slots[String(s_outer.slot_id)] = s_outer
	BuildingEconomy._slots[String(s_player.slot_id)] = s_player
	BuildingEconomy._buildings_by_port[PORT] = []
	_force_housing_trigger_conditions()
	_set_city_balance(city, int(Params.get_value("PRM-SYS08-BUILD_CASH_LI")["RESIDENCE"]) * 4)
	BuildingEconomy._season_city_auto_housing(PORT)
	## Outer city slot should be occupied；player slot untouched.
	## Inner may hold the beds filler residence from _force_housing_trigger_conditions.
	assert_ne(s_outer.building_id, &"")
	assert_eq(s_player.building_id, &"")
	assert_ne(s_outer.building_id, s_inner.building_id)


func test_WP68_05_no_empty_slot_no_build() -> void:
	## ⑤ no empty slot → no build this season.
	_boot_min()
	BuildingEconomy.set_city_housing_layer(true)
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	_register_rb01()
	BuildingEconomy._slots_by_port[PORT] = []
	BuildingEconomy._buildings_by_port[PORT] = []
	_force_housing_trigger_conditions()
	var city: StringName = CashLedger.make_city_id(PORT)
	_set_city_balance(city, int(Params.get_value("PRM-SYS08-BUILD_CASH_LI")["RESIDENCE"]) * 4)
	var before: int = _residence_count()
	BuildingEconomy._season_city_auto_housing(PORT)
	assert_eq(_residence_count(), before)


func test_WP68_07_only_residence() -> void:
	## ⑦ path only calls order_build RESIDENCE（RB-01）.
	_boot_min()
	BuildingEconomy.set_city_housing_layer(true)
	_prep_port_with_empty_slot()
	_force_housing_trigger_conditions()
	var city: StringName = CashLedger.make_city_id(PORT)
	_set_city_balance(city, int(Params.get_value("PRM-SYS08-BUILD_CASH_LI")["RESIDENCE"]) * 4)
	BuildingEconomy._season_city_auto_housing(PORT)
	for bld_v in BuildingEconomy._buildings_by_port.get(PORT, []):
		var bld: Building = bld_v
		if bld.owner == city:
			assert_eq(String(bld.build_class), "RESIDENCE")
			assert_eq(String(bld.type), "RB-01")


func test_D100_built_ratio_below_blocks() -> void:
	## Built-ratio 未達 → zone open blocked.
	_boot_min()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	var city: StringName = CashLedger.make_city_id(PORT)
	CashLedger.create_account(city, Account.Kind.CITY)
	## Zone 1: 10 civil slots, 0 built → ratio 0 < 700000.
	var slots: Array = []
	for i in range(10):
		var s := _make_civil_slot("SL-%d" % i, 1, 1 + i, city)
		s.zone_open = true
		slots.append(s)
		BuildingEconomy._slots[String(s.slot_id)] = s
	## Zone 2 closed target.
	var s2 := _make_civil_slot("SL-Z2", 2, 20, city)
	s2.zone_open = false
	slots.append(s2)
	BuildingEconomy._slots[String(s2.slot_id)] = s2
	BuildingEconomy._slots_by_port[PORT] = slots
	BuildingEconomy._max_open_zone[PORT] = 1
	BuildingEconomy._zone_streak[PORT] = Params.get_int("PRM-SYS08-ZONE_SAT_DAYS")
	_set_city_balance(city, 999999999)
	assert_eq(BuildingEconomy.zone_built_ratio_ppm(StringName(PORT), 2), 0)
	BuildingEconomy._season_zone_open(PORT)
	assert_eq(int(BuildingEconomy._max_open_zone.get(PORT, -1)), 1, "must not open zone 2")


func test_D100_built_ratio_exactly_ok() -> void:
	## Exactly 70% built → may open (other gates pass).
	_boot_min()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	_register_rb01()
	var city: StringName = CashLedger.make_city_id(PORT)
	CashLedger.create_account(city, Account.Kind.CITY)
	var slots: Array = []
	## 10 slots zone 1; 7 with buildings（含 BUILDING／PAUSED）.
	for i in range(10):
		var s := _make_civil_slot("SL-%d" % i, 1, 1 + i, city)
		s.zone_open = true
		slots.append(s)
		BuildingEconomy._slots[String(s.slot_id)] = s
		if i < 7:
			var b := Building.new()
			b.building_id = StringName("BLD-%d" % i)
			b.type = &"RB-01"
			b.build_class = BuildingEconomy.CLASS_RESIDENCE
			b.owner = city
			b.port_id = PORT
			b.slot_id = s.slot_id
			b.state = Building.State.BUILDING if i % 2 == 0 else Building.State.PAUSED
			s.building_id = b.building_id
			BuildingEconomy._buildings[String(b.building_id)] = b
	var s2 := _make_civil_slot("SL-Z2", 2, 20, city)
	s2.zone_open = false
	slots.append(s2)
	BuildingEconomy._slots[String(s2.slot_id)] = s2
	BuildingEconomy._slots_by_port[PORT] = slots
	BuildingEconomy._buildings_by_port[PORT] = []
	BuildingEconomy._max_open_zone[PORT] = 1
	BuildingEconomy._zone_streak[PORT] = Params.get_int("PRM-SYS08-ZONE_SAT_DAYS")
	_set_city_balance(city, 999999999)
	var ppm: int = BuildingEconomy.zone_built_ratio_ppm(StringName(PORT), 2)
	assert_eq(ppm, 700000)
	BuildingEconomy._season_zone_open(PORT)
	assert_eq(int(BuildingEconomy._max_open_zone.get(PORT, -1)), 2)


func test_D100_under_construction_and_paused_count() -> void:
	## 建造中＋暫停算已建；空購地不算.
	_boot_min()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	var city: StringName = CashLedger.make_city_id(PORT)
	var s_build := _make_civil_slot("SL-B", 1, 1, city)
	var s_pause := _make_civil_slot("SL-P", 1, 2, city)
	var s_empty_bought := _make_civil_slot("SL-E", 1, 3, &"ACTOR-P1") ## purchased empty
	s_build.zone_open = true
	s_pause.zone_open = true
	s_empty_bought.zone_open = true
	var b1 := Building.new()
	b1.building_id = &"BLD-B"
	b1.build_class = BuildingEconomy.CLASS_RESIDENCE
	b1.type = &"RB-01"
	b1.state = Building.State.WAITING_MATERIAL
	b1.port_id = PORT
	b1.slot_id = s_build.slot_id
	s_build.building_id = b1.building_id
	var b2 := Building.new()
	b2.building_id = &"BLD-P"
	b2.build_class = BuildingEconomy.CLASS_IND1
	b2.type = &"IB-01"
	b2.state = Building.State.PAUSED
	b2.port_id = PORT
	b2.slot_id = s_pause.slot_id
	s_pause.building_id = b2.building_id
	BuildingEconomy._buildings[String(b1.building_id)] = b1
	BuildingEconomy._buildings[String(b2.building_id)] = b2
	BuildingEconomy._slots = {
		"SL-B": s_build, "SL-P": s_pause, "SL-E": s_empty_bought
	}
	BuildingEconomy._slots_by_port[PORT] = [s_build, s_pause, s_empty_bought]
	var counts: Dictionary = BuildingEconomy._zone_built_counts(PORT, 2)
	assert_eq(int(counts["total"]), 3)
	assert_eq(int(counts["built"]), 2)


func test_WP68_scenario_layer_city_housing_allowed() -> void:
	## Minimal fixture（avoid pre-existing M1b override／grid ABUND overlap）.
	var sc := {
		"scenario_id": "wp68_city_housing_layer",
		"years": 2,
		"warmup_years": 0,
		"seeds": [1],
		"layers": {"RELOCATE": false, "CITY_HOUSING": true},
	}
	var path := ParamsFixtures.write_user_dict(sc, "scenario_wp68_city_housing.json")
	var r: Dictionary = SimScenarioValidator.validate_file(path)
	assert_true(bool(r.get("ok", false)), str(r.get("errors", [])))
	var out: Dictionary = r["scenario"]
	assert_true(bool((out["layers"] as Dictionary).get("CITY_HOUSING", false)))


func _boot_min() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	## CashLedger.post requires GoodsLedger seq（A22）.
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	## Goods／ports optional for most unit paths；load if present for order_build mats.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://data/goods/")):
		GoodCatalog.load_and_validate("res://data/goods/")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://data/ports/")):
		PortRegistry.load_and_validate("res://data/ports/")


func _register_rb01() -> void:
	var def := BuildingDef.new()
	def.type = "RB-01"
	def.build_class = "RESIDENCE"
	def.tier = 0
	def.max_workers = 0
	def.base_output_per_worker = 0.0
	BuildingEconomy._building_defs["RB-01"] = def


func _prep_port_with_empty_slot(n: int = 1) -> void:
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	_register_rb01()
	var city: StringName = CashLedger.make_city_id(PORT)
	CashLedger.create_account(city, Account.Kind.CITY)
	var slots: Array = []
	for i in range(n):
		var s := _make_civil_slot("SL-%d" % i, 1, 3 + i, city)
		s.zone_open = true
		slots.append(s)
		BuildingEconomy._slots[String(s.slot_id)] = s
	BuildingEconomy._slots_by_port[PORT] = slots
	BuildingEconomy._buildings_by_port[PORT] = []


func _make_civil_slot(sid: String, zone: int, ring: int, owner: StringName) -> Slot:
	var s := Slot.new()
	s.slot_id = StringName(sid)
	s.kind = Slot.Kind.CIVIL
	s.port_id = PORT
	s.zone = zone
	s.ring = ring
	s.land_owner = owner
	s.building_id = &""
	s.zone_open = true
	return s


func _force_housing_trigger_conditions() -> void:
	## beggars ≥ HOUSE_CAP and free beds = 0 via full occupancy on existing residences.
	var cap: int = Params.get_int("PRM-SYS07-HOUSE_CAPACITY")
	## Ensure at least one residence so beds==cap with residents==cap → free=0.
	if _residence_count() == 0:
		_add_active_residence("BLD-R-FULL")
	_inject_pop(cap, 0, 0, cap)


func _zero_free_beds_by_filling() -> void:
	pass


func _inject_pop(poor: int, citizen: int, rich: int, beggar: int) -> void:
	## Use PopulationModel.set_port_state（product reads PopulationModel）.
	if not PopulationModel.is_loaded():
		PopulationModel.reset_runtime_state()
		PopulationModel._loaded = true
	PopulationModel.set_port_state(PORT, poor, citizen, rich, beggar)


func _add_active_residence(bid: String) -> void:
	var city: StringName = CashLedger.make_city_id(PORT)
	var b := Building.new()
	b.building_id = StringName(bid)
	b.type = &"RB-01"
	b.build_class = BuildingEconomy.CLASS_RESIDENCE
	b.owner = city
	b.port_id = PORT
	b.state = Building.State.ACTIVE
	BuildingEconomy._buildings[String(b.building_id)] = b
	if not BuildingEconomy._buildings_by_port.has(PORT):
		BuildingEconomy._buildings_by_port[PORT] = []
	(BuildingEconomy._buildings_by_port[PORT] as Array).append(b)
	## Attach to first free slot if any.
	for s_v in BuildingEconomy._slots_by_port.get(PORT, []):
		var s: Slot = s_v
		if s.building_id == &"":
			s.building_id = b.building_id
			b.slot_id = s.slot_id
			break


func _residence_count() -> int:
	var n := 0
	for bld_v in BuildingEconomy._buildings_by_port.get(PORT, []):
		var bld: Building = bld_v
		if bld.build_class == BuildingEconomy.CLASS_RESIDENCE:
			n += 1
	## Also count via _buildings map for safety.
	if n == 0:
		for id_v in BuildingEconomy._buildings.keys():
			var b2: Building = BuildingEconomy._buildings[id_v]
			if b2.port_id == PORT and b2.build_class == BuildingEconomy.CLASS_RESIDENCE:
				n += 1
	return n


func _set_city_balance(city: StringName, want: int) -> void:
	CashLedger.create_account(city, Account.Kind.CITY)
	var bal: int = CashLedger.balance(city)
	if bal == want:
		return
	if bal < want:
		var add: int = want - bal
		CashLedger.post(
			[CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - add), CashLedger.make_entry(city, add)],
			&"TEST_TOP_UP",
			BuildingEconomy.REQUESTER_SYS08
		)
	else:
		var sub: int = bal - want
		CashLedger.post(
			[CashLedger.make_entry(city, 0 - sub), CashLedger.make_entry(CashLedger.ID_SINK, sub)],
			&"TEST_DRAIN",
			BuildingEconomy.REQUESTER_SYS08
		)
