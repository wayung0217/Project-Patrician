extends GutTest
## WP-65／N1／D-97(a): ERR-SYS08-13 build_queue import validation.
## EX-08-21-04 + skip-level fixture + formal data 0 errors.


func before_each() -> void:
	BuildingEconomy._loaded = false
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	Params._loaded = false


func test_EX_08_21_04_opening_plus_new_exceeds_slots() -> void:
	## EX-08-21-04: slots=4; opening 2; three target_level=1 → ERR on step 3 CB-04.
	_boot_registry()
	var opens: Array = [_opening("PT-10", "CB-01", 1), _opening("PT-10", "CB-02", 1)]
	var steps: Array = [
		_step("PT-10", 1, "CB-10", 1),
		_step("PT-10", 2, "CB-16", 1),
		_step("PT-10", 3, "CB-04", 1),
	]
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy.set_build_queue("PT-10", steps)
	var city_by: Dictionary = {"PT-10": _city("PT-10", 4)}
	## Other registry ports: empty city → slots 0, no opens/steps → ok.
	var errs: Array = []
	BuildingEconomy._validate_build_queue_import_d97a(city_by, opens, errs)
	assert_gt(errs.size(), 0)
	var hit := false
	for e_v in errs:
		var e: Dictionary = e_v
		if StringName(e.get("code", &"")) != BuildingEconomy.ERR_SYS08_13:
			continue
		var detail: Dictionary = e.get("detail", {})
		var val: Variant = detail.get("value", {})
		if typeof(val) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = val
		if (
			String(d.get("port_id", "")) == "PT-10"
			and int(d.get("step", 0)) == 3
			and String(d.get("cb_id", "")) == "CB-04"
		):
			hit = true
			break
	assert_true(hit, "EX-08-21-04 must flag step 3 CB-04 with ERR-SYS08-13")


func test_EX_08_21_skip_level_fixture_err_sys08_13() -> void:
	## Skip-level: opening CB-01@1; queue asks CB-01 target_level=3 → ERR-SYS08-13.
	_boot_registry()
	var opens: Array = [_opening("PT-10", "CB-01", 1)]
	var steps: Array = [_step("PT-10", 1, "CB-01", 3)]
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy.set_build_queue("PT-10", steps)
	var city_by: Dictionary = {"PT-10": _city("PT-10", 4)}
	var errs: Array = []
	BuildingEconomy._validate_build_queue_import_d97a(city_by, opens, errs)
	assert_gt(errs.size(), 0)
	var hit := false
	for e_v in errs:
		var e: Dictionary = e_v
		if StringName(e.get("code", &"")) != BuildingEconomy.ERR_SYS08_13:
			continue
		var detail: Dictionary = e.get("detail", {})
		var val: Variant = detail.get("value", {})
		if typeof(val) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = val
		if String(d.get("port_id", "")) == "PT-10" and String(d.get("cb_id", "")) == "CB-01":
			hit = true
			assert_eq(int(d.get("value", 0)), 3)
			assert_eq(int(d.get("expected", 0)), 2)
			break
	assert_true(hit, "skip-level fixture must report ERR-SYS08-13")


func test_D102d_city_queue_position() -> void:
	## D-102(d): city_queue_position returns next index; unknown port → −1 + last_error.
	_boot_registry()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._slots_by_port["PT-10"] = []
	BuildingEconomy.set_build_queue("PT-10", [_step("PT-10", 0, "CB-01", 2), _step("PT-10", 1, "CB-02", 1)])
	assert_eq(BuildingEconomy.city_queue_position(StringName("PT-10")), 0)
	BuildingEconomy._queue_pos["PT-10"] = 2
	assert_eq(BuildingEconomy.city_queue_position(StringName("PT-10")), 2)
	assert_eq(BuildingEconomy.city_queue_position(StringName("PT-NOPE")), -1)
	assert_eq(
		String(BuildingEconomy.last_error().get("code", "")),
		String(BuildingEconomy.ERR_SYS08_08)
	)
	for e in get_errors():
		e.handled = true


func test_N1_formal_data_zero_queue_import_errors() -> void:
	## Formal city centers + opening_public + build_queue → 0 ERR-SYS08-13.
	_boot_registry()
	var city_by: Dictionary = {}
	var dir := DirAccess.open("res://data/city_center/")
	assert_ne(dir, null)
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for fname_v in names:
		var fname: String = String(fname_v)
		if not fname.ends_with(".tres"):
			continue
		var res: Resource = load("res://data/city_center/".path_join(fname))
		if res is CityCenterDef:
			var cc: CityCenterDef = res as CityCenterDef
			city_by[cc.port_id] = cc
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._load_build_queues(BuildingEconomy.BUILD_QUEUE_DIR, [])
	var opens: Array = BuildingEconomy._load_opening_public(BuildingEconomy.OPENING_PUBLIC_DIR, [])
	var errs: Array = []
	BuildingEconomy._validate_build_queue_import_d97a(city_by, opens, errs)
	var n13 := 0
	for e_v in errs:
		if StringName((e_v as Dictionary).get("code", &"")) == BuildingEconomy.ERR_SYS08_13:
			n13 += 1
			print("N1 unexpected: ", e_v)
	assert_eq(n13, 0, "formal data must yield 0 ERR-SYS08-13; got %d" % n13)


func _boot_registry() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodCatalog.load_and_validate("res://data/goods/").size(), 0)
	assert_eq(PortRegistry.load_and_validate("res://data/ports/").size(), 0)


func _opening(port_id: String, cb: String, level: int) -> OpeningPublic:
	var op := OpeningPublic.new()
	op.port_id = port_id
	op.cb_id = cb
	op.level = level
	return op


func _step(port_id: String, step_n: int, cb: String, target: int) -> BuildStep:
	var s := BuildStep.new()
	s.port_id = port_id
	s.step = step_n
	s.cb_id = cb
	s.target_level = target
	return s


func _city(port_id: String, slots: int) -> CityCenterDef:
	var c := CityCenterDef.new()
	c.port_id = port_id
	c.public_slots = slots
	return c
