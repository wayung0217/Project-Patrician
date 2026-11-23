extends GutTest
## WP-65／N1／D-97(a): ERR-SYS08-13 build_queue import validation.
## EX-08-21-04 + skip-level fixture + formal data 0 errors.

## Formal .tres under data/ are wiped by earlier suites (sim_loop／SYS23／trade_desk).
## Restore from git HEAD — never edit docs/spec (blank rows stay; D-111 hard rule).


func before_each() -> void:
	BuildingEconomy._loaded = false
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	CashLedger._loaded = false
	Params._loaded = false


func _restore_formal_data_tres() -> void:
	var root: String = ProjectSettings.globalize_path("res://").rstrip("/")
	var paths: Array = [
		"data/build_queue",
		"data/buildings",
		"data/city_center",
		"data/opening",
		"data/opening_public",
		"data/opening_population",
		"data/zones",
	]
	var args: PackedStringArray = PackedStringArray(["-C", root, "checkout", "HEAD", "--"])
	for p in paths:
		args.append(String(p))
	var output: Array = []
	var rc: int = OS.execute("git", args, output, true, false)
	assert_eq(rc, 0, "git restore formal data failed rc=%s out=%s" % [str(rc), str(output)])


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
	_restore_formal_data_tres()
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


func test_D111b_missing_cb_error_queue_pos_stuck() -> void:
	## D-111(b) blind-1: missing BuildingDef → error; queue_pos unchanged (no skip).
	_boot_registry()
	assert_eq(CashLedger.load_and_validate().size(), 0)
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	BuildingEconomy._building_defs = {}
	BuildingEconomy._slots_by_port["PT-10"] = []
	BuildingEconomy.set_build_queue("PT-10", [_step("PT-10", 0, "CB-MISSING", 1)])
	assert_eq(BuildingEconomy.city_queue_position(StringName("PT-10")), 0)
	var city: StringName = CashLedger.make_city_id("PT-10")
	CashLedger.create_account(city, Account.Kind.CITY)
	## Fund CITY so cost gate does not mask the missing-def stop.
	var fund: int = int(Params.get_value("PRM-SYS08-BUILD_CASH_LI").get("PUBLIC", 0)) + 1
	CashLedger.post(
		[CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - fund), CashLedger.make_entry(city, fund)],
		&"TEST_TOP_UP",
		BuildingEconomy.REQUESTER_SYS08
	)
	var started: bool = BuildingEconomy._try_start_city_public(
		"PT-10", city, BuildingEconomy._queue_by_port["PT-10"][0] as BuildStep, fund
	)
	assert_false(started, "missing CB must not start")
	assert_eq(
		String(BuildingEconomy.last_error().get("code", "")),
		String(BuildingEconomy.ERR_SYS08_08)
	)
	assert_eq(BuildingEconomy.city_queue_position(StringName("PT-10")), 0, "queue_pos must stay")
	## Season queue path: still stuck at 0 (no skip).
	BuildingEconomy._season_city_build_queue("PT-10")
	assert_eq(int(BuildingEconomy._queue_pos.get("PT-10", -1)), 0)
	for e in get_errors():
		e.handled = true


func test_D111b_formal_newbuild_defs_from_buildings() -> void:
	## D-111(b) blind-2 (static half): every formal target_level=1 cb_id has loaded BuildingDef.
	## 360d start-day listing is produced by tools/wp65_newbuild_360_probe.gd (F1 evidence).
	_restore_formal_data_tres()
	_boot_registry()
	BuildingEconomy._clear_state()
	BuildingEconomy._loaded = true
	var load_errs: Array = []
	BuildingEconomy._building_defs = BuildingEconomy._load_building_defs(
		BuildingEconomy.BUILDINGS_DIR, load_errs
	)
	assert_eq(load_errs.size(), 0, str(load_errs))
	BuildingEconomy._load_build_queues(BuildingEconomy.BUILD_QUEUE_DIR, [])
	var listed: PackedStringArray = PackedStringArray()
	var missing := 0
	var ports: Array = BuildingEconomy._queue_by_port.keys()
	ports.sort()
	for pid_v in ports:
		var pid: String = String(pid_v)
		for step_v in BuildingEconomy._queue_by_port[pid]:
			var step: BuildStep = step_v as BuildStep
			if step == null or step.target_level != 1:
				continue
			var cb: String = String(step.cb_id)
			listed.append("%s|%s|step=%s" % [pid, cb, str(step.step)])
			if not BuildingEconomy._building_defs.has(cb):
				missing += 1
				print("D111b missing def: port=%s cb=%s" % [pid, cb])
	assert_eq(missing, 0, "formal new-builds must have BuildingDef; missing=%d" % missing)
	assert_gt(listed.size(), 0, "expected formal new-build rows")
	print("D111b_FORMAL_NEWBUILDS count=%d" % listed.size())
	for line in listed:
		print("D111b_NEWBUILD %s" % line)


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
