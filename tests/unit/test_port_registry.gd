extends GutTest
## WP-04 PortRegistry tests. Fixture values from TechSpec §4 / TST-SYS02-01..05 / 3.3.
## D-04: failures are ErrorInfo Dictionaries {code, sys, detail}; no ERR→int.
## D-02: queue_role_change payload validated at enqueue.
## D-08b／D-08c: port_id／name_zh format; id lookups unknown → fail＋last_error (R3-02).


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const GOODS_FIXTURE_ROOT := "user://port_registry_goods/"
const PORTS_FIXTURE_ROOT := "user://port_registry_ports/"

const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"

const SYS_ID := &"SYS-02"
const ERR_SYS02_01 := &"ERR-SYS02-01"
const ERR_SYS02_02 := &"ERR-SYS02-02"
const ERR_SYS02_03 := &"ERR-SYS02-03"
const ERR_SYS02_05 := &"ERR-SYS02-05"
const ERR_SYS02_06 := &"ERR-SYS02-06"
const ERR_SYS02_07 := &"ERR-SYS02-07"
const ERR_SYS02_08 := &"ERR-SYS02-08"
const ERR_SYS02_09 := &"ERR-SYS02-09"

## D-08b fixture ids that violate PORT_ID_PATTERN (^PT-[0-9]{2}$).
const D08_BAD_PORT_ID_SHORT := "PT-1"
const D08_BAD_PORT_ID_LONG := "PT-001"
const D08_UNKNOWN_PORT_ID := "PT-99"
const D08_UNKNOWN_GOOD_ID := "GD-999"
const D08_BLANK_NAME_ZH := "   "

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"

## TST-SYS02-01 given: port count = 13 → ERR-SYS02-05
const TST_SYS02_01_PORT_COUNT := 13
## TST-SYS02-02 given: free port ratio = 0.25 → ERR-SYS02-06
const TST_SYS02_02_FREE_RATIO := 0.25
## TST-SYS02-05: queue on season day 30; role unchanged through days 31..D; apply at cutoff.
const TST_SYS02_05_QUEUE_DAY := 30


func before_each() -> void:
	var params_errors: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(params_errors.size(), 0, "params fixture must load")
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/")
	var goods_errors: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(goods_errors.size(), 0, "goods fixture must load")


func test_TST_SYS02_01_port_count_13_rejects() -> void:
	# TST-SYS02-01: 港口數 = 13 → ERR-SYS02-05
	var dir := _build_valid_ports(TST_SYS02_01_PORT_COUNT, PORTS_FIXTURE_ROOT + "count13/")
	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_05), "expected ERR-SYS02-05")


func test_TST_SYS02_02_free_port_ratio_025_rejects() -> void:
	# TST-SYS02-02: 自由港比例 = 0.25 → ERR-SYS02-06
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	# free = round(ratio * count); 0.25 * 14 = 3.5 → use exact free_count = ratio * count when divisible.
	# 16 * 0.25 = 4 exactly (PORT_COUNT_MAX).
	port_count = Params.get_int(PRM_PORT_COUNT_MAX)
	var free_count: int = int(TST_SYS02_02_FREE_RATIO * float(port_count))
	assert_eq(float(free_count) / float(port_count), TST_SYS02_02_FREE_RATIO, "fixture ratio must be 0.25")
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "ratio025/", free_count)
	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_06), "expected ERR-SYS02-06")


func test_TST_SYS02_03_missing_role_cell_rejects() -> void:
	# TST-SYS02-03: 某港 × 貨格無角色 → ERR-SYS02-01（無 NONE，9a-B）
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "missing_role/", free_count)
	var first_port_path := dir + "PT-01.tres"
	var def: PortDef = load(first_port_path) as PortDef
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	assert_gt(good_ids.size(), 0)
	var drop_good: String = good_ids[0]
	def.role_cells.erase(drop_good)
	var save_err: Error = ResourceSaver.save(def, first_port_path)
	assert_eq(save_err, OK)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_01), "expected ERR-SYS02-01")


# DELETED (D-20b／15-04／TST-SYS02-04 停用):
# test_TST_SYS02_04_transit_downstream_self_rejects
# test_TST_SYS02_04_transit_downstream_non_terminal_rejects


func test_TST_SYS02_05_role_change_queues_until_cutoff() -> void:
	# TST-SYS02-05: 建造完工於商季第 30 日排隊；第 31..D 日角色不變；cutoff 後生效並發 role_changed
	# D-02: TERMINAL payload must be empty.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "queue/", free_count)
	# Second producer so PRODUCER→TERMINAL still satisfies FRM-SYS02-01 (4).
	_add_second_producer(dir, "PT-04", GoodCatalog.all_ids()[0])

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_eq(errors.size(), 0, "valid ports must load")
	assert_true(PortRegistry.is_loaded())

	var port_id := "PT-01"
	var good_id: String = GoodCatalog.all_ids()[0]
	var old_role: int = PortRegistry.get_role(port_id, good_id)
	assert_eq(old_role, PortRegistry.ROLE_PRODUCER)

	# Day 30 (TST-SYS02-05): construction completion queues role change.
	var day_in_season: int = TST_SYS02_05_QUEUE_DAY
	assert_eq(day_in_season, TST_SYS02_05_QUEUE_DAY)
	var q_errors: Array = PortRegistry.queue_role_change(
		port_id, good_id, PortRegistry.ROLE_TERMINAL, {}
	)
	assert_eq(q_errors.size(), 0, "TERMINAL empty payload must enqueue")

	var days_per_season: int = Params.get_int(PRM_DAYS_PER_SEASON)
	# Days 31 .. D inclusive: role unchanged (SimLoop not present — observe via get_role).
	var day: int = TST_SYS02_05_QUEUE_DAY + 1
	while day <= days_per_season:
		assert_eq(PortRegistry.get_role(port_id, good_id), old_role, "role must stay queued through day %d" % day)
		day += 1

	watch_signals(PortRegistry)
	var apply_errors: Array = PortRegistry.apply_queued_role_changes()
	assert_eq(apply_errors.size(), 0)
	assert_eq(PortRegistry.get_role(port_id, good_id), PortRegistry.ROLE_TERMINAL)
	assert_eq(PortRegistry.get_port(port_id).role_cells[good_id].base_output_per_season, 0)
	assert_signal_emitted(PortRegistry, "role_changed")


func test_WP59_D02_queue_producer_payload_applies_output() -> void:
	# D-02: PRODUCER requires base_output_per_season > 0; applied at cutoff.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "q_producer/", free_count)
	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_eq(errors.size(), 0)

	var port_id := "PT-03"
	var good_id: String = GoodCatalog.all_ids()[0]
	assert_eq(PortRegistry.get_role(port_id, good_id), PortRegistry.ROLE_TERMINAL)

	var q_errors: Array = PortRegistry.queue_role_change(
		port_id, good_id, PortRegistry.ROLE_PRODUCER, {"base_output_per_season": 7}
	)
	assert_eq(q_errors.size(), 0)
	assert_eq(PortRegistry.get_role(port_id, good_id), PortRegistry.ROLE_TERMINAL, "must not apply before cutoff")

	var apply_errors: Array = PortRegistry.apply_queued_role_changes()
	assert_eq(apply_errors.size(), 0)
	assert_eq(PortRegistry.get_role(port_id, good_id), PortRegistry.ROLE_PRODUCER)
	assert_eq(PortRegistry.get_port(port_id).role_cells[good_id].base_output_per_season, 7)


func test_WP59_D02_queue_transit_payload_applies_downstream() -> void:
	# WP-32／15-04: TRANSIT may carry downstream_terminals (stored, not validated); applied at cutoff.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "q_transit/", free_count)
	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_eq(errors.size(), 0)

	var port_id := "PT-03"
	var good_id: String = GoodCatalog.all_ids()[0]
	var q_errors: Array = PortRegistry.queue_role_change(
		port_id, good_id, PortRegistry.ROLE_TRANSIT, {"downstream_terminals": PackedStringArray(["PT-02"])}
	)
	assert_eq(q_errors.size(), 0)

	var apply_errors: Array = PortRegistry.apply_queued_role_changes()
	assert_eq(apply_errors.size(), 0)
	assert_eq(PortRegistry.get_role(port_id, good_id), PortRegistry.ROLE_TRANSIT)
	var downs: PackedStringArray = PortRegistry.get_downstream(port_id, good_id)
	assert_eq(downs.size(), 1)
	assert_eq(downs[0], "PT-02")


func test_WP59_D02_queue_rejects_bad_producer_payload_at_enqueue() -> void:
	# D-02: missing / forbidden / wrong-type PRODUCER payload → ERR-SYS02 at enqueue, not cutoff.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "q_bad_prod/", free_count)
	assert_eq(PortRegistry.load_and_validate(dir).size(), 0)

	var port_id := "PT-03"
	var good_id: String = GoodCatalog.all_ids()[0]
	var role_before: int = PortRegistry.get_role(port_id, good_id)

	var push_total: int = 0

	var missing: Array = PortRegistry.queue_role_change(port_id, good_id, PortRegistry.ROLE_PRODUCER, {})
	assert_gt(missing.size(), 0)
	push_total += missing.size()
	assert_true(_has_code(missing, ERR_SYS02_03), "missing output → ERR-SYS02-03")

	var zero_out: Array = PortRegistry.queue_role_change(
		port_id, good_id, PortRegistry.ROLE_PRODUCER, {"base_output_per_season": 0}
	)
	push_total += zero_out.size()
	assert_true(_has_code(zero_out, ERR_SYS02_03), "output <= 0 → ERR-SYS02-03")

	# A30／EV-SYS02-ROLE_CHANGE: PRODUCER + downstream_terminals rejected at enqueue.
	var with_down: Array = PortRegistry.queue_role_change(
		port_id,
		good_id,
		PortRegistry.ROLE_PRODUCER,
		{"base_output_per_season": 1, "downstream_terminals": PackedStringArray(["PT-02"])}
	)
	push_total += with_down.size()
	assert_gt(with_down.size(), 0, "PRODUCER + downstream must be rejected")
	assert_true(_has_code(with_down, ERR_SYS02_01), "PRODUCER + downstream → ERR-SYS02-01")

	var bad_type: Array = PortRegistry.queue_role_change(
		port_id, good_id, PortRegistry.ROLE_PRODUCER, {"base_output_per_season": 1.5}
	)
	push_total += bad_type.size()
	assert_true(_has_code(bad_type, ERR_SYS02_03), "non-int output → ERR-SYS02-03")

	assert_push_error_count(push_total)

	# Bad payloads rejected; nothing enqueued → role unchanged.
	assert_eq(PortRegistry.apply_queued_role_changes().size(), 0)
	assert_eq(PortRegistry.get_role(port_id, good_id), role_before)


func test_WP59_D02_queue_rejects_bad_transit_and_terminal_payload_at_enqueue() -> void:
	# WP-32／15-04: TRANSIT empty／missing downstream allowed (ERR-SYS02-02 retired);
	# TRANSIT + output and TERMINAL non-empty still reject.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "q_bad_tt/", free_count)
	assert_eq(PortRegistry.load_and_validate(dir).size(), 0)

	var port_id := "PT-03"
	var good_id: String = GoodCatalog.all_ids()[0]

	var push_total: int = 0

	var empty_transit: Array = PortRegistry.queue_role_change(port_id, good_id, PortRegistry.ROLE_TRANSIT, {})
	assert_eq(empty_transit.size(), 0, "TRANSIT missing downstream allowed")

	# Clear queue so next cases are isolated.
	PortRegistry.apply_queued_role_changes()

	var empty_list: Array = PortRegistry.queue_role_change(
		port_id, good_id, PortRegistry.ROLE_TRANSIT, {"downstream_terminals": PackedStringArray()}
	)
	assert_eq(empty_list.size(), 0, "TRANSIT empty downstream allowed")
	PortRegistry.apply_queued_role_changes()

	var with_output: Array = PortRegistry.queue_role_change(
		port_id,
		good_id,
		PortRegistry.ROLE_TRANSIT,
		{"downstream_terminals": PackedStringArray(["PT-02"]), "base_output_per_season": 1}
	)
	push_total += with_output.size()
	assert_true(_has_code(with_output, ERR_SYS02_03), "TRANSIT + output → ERR-SYS02-03")

	var terminal_extra: Array = PortRegistry.queue_role_change(
		port_id, good_id, PortRegistry.ROLE_TERMINAL, {"base_output_per_season": 1}
	)
	push_total += terminal_extra.size()
	assert_true(_has_code(terminal_extra, ERR_SYS02_03), "TERMINAL non-empty → ERR-SYS02-03")

	# A30: TERMINAL + downstream_terminals rejected.
	var terminal_down: Array = PortRegistry.queue_role_change(
		port_id,
		good_id,
		PortRegistry.ROLE_TERMINAL,
		{"downstream_terminals": PackedStringArray(["PT-02"])}
	)
	push_total += terminal_down.size()
	assert_gt(terminal_down.size(), 0, "TERMINAL + downstream must be rejected")
	assert_true(_has_code(terminal_down, ERR_SYS02_01), "TERMINAL + downstream → ERR-SYS02-01")

	assert_push_error_count(push_total)

	assert_eq(PortRegistry.apply_queued_role_changes().size(), 0)
	assert_eq(PortRegistry.get_role(port_id, good_id), PortRegistry.ROLE_TRANSIT)


func test_WP59_valid_ports_load_queries_and_warnings() -> void:
	# Happy path: FRM-SYS02-01 pass, queries sorted, WRN-SYS02-01 does not block.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "ok/", free_count)
	# Put controlled_scale_only PRODUCER on a free port → warning only.
	FixtureBuilders.force_controlled_producer_on_free_port(dir)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_eq(errors.size(), 0)
	assert_true(PortRegistry.is_loaded())
	assert_gt(PortRegistry.get_warnings().size(), 0, "FRM-SYS02-02 should warn")

	var ids: PackedStringArray = PortRegistry.all_ids()
	assert_eq(ids.size(), port_count)
	for i in range(ids.size()):
		if i == 0:
			continue
		assert_true(ids[i - 1] < ids[i], "all_ids must be ascending")

	var good_id: String = GoodCatalog.all_ids()[0]
	var producers: PackedStringArray = PortRegistry.producers_of(good_id)
	var terminals: PackedStringArray = PortRegistry.terminals_of(good_id)
	assert_gt(producers.size(), 0)
	assert_gt(terminals.size(), 0)
	assert_eq(PortRegistry.get_role(producers[0], good_id), PortRegistry.ROLE_PRODUCER)
	assert_eq(PortRegistry.get_role(terminals[0], good_id), PortRegistry.ROLE_TERMINAL)
	var port: PortDef = PortRegistry.get_port(ids[0])
	assert_false(port.port_id.is_empty())
	assert_true(PortRegistry.last_error().is_empty(), "successful get_port clears last_error")
	# draft_limit_class stored, unused (B3).
	assert_true(port.get("draft_limit_class") != null)

	var recheck: Array = PortRegistry.validate()
	assert_eq(recheck.size(), 0)


func test_D08_TST_port_id_format_rejects() -> void:
	# D-08b／TST: port_id 不符 ^PT-[0-9]{2}$（一位數）→ ERR-SYS02-07；拒絕啟動（C-06 收集）。
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "bad_port_id/", free_count)
	var path := dir + "PT-01.tres"
	var def: PortDef = load(path) as PortDef
	def.port_id = D08_BAD_PORT_ID_SHORT
	assert_eq(ResourceSaver.save(def, path), OK)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_07), "expected ERR-SYS02-07 PORT_ID_FORMAT")


func test_D08_TST_port_id_format_three_digits_rejects() -> void:
	# D-08b／TST: 固定兩位寬度，PT-001 → ERR-SYS02-07.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "bad_port_id_long/", free_count)
	var path := dir + "PT-01.tres"
	var def: PortDef = load(path) as PortDef
	def.port_id = D08_BAD_PORT_ID_LONG
	assert_eq(ResourceSaver.save(def, path), OK)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_07), "PT-001 must be ERR-SYS02-07")


func test_D08_TST_name_zh_blank_rejects() -> void:
	# D-08b／TST: name_zh 去除前後空白後為空 → ERR-SYS02-08.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "blank_name/", free_count)
	var path := dir + "PT-01.tres"
	var def: PortDef = load(path) as PortDef
	def.name_zh = D08_BLANK_NAME_ZH
	assert_eq(ResourceSaver.save(def, path), OK)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_08), "expected ERR-SYS02-08 NAME_EMPTY")


func test_D08_TST_name_zh_empty_rejects() -> void:
	# D-08b／TST: name_zh 空字串 → ERR-SYS02-08.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "empty_name/", free_count)
	var path := dir + "PT-02.tres"
	var def: PortDef = load(path) as PortDef
	def.name_zh = ""
	assert_eq(ResourceSaver.save(def, path), OK)

	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(PortRegistry.is_loaded())
	assert_true(_has_code(errors, ERR_SYS02_08), "empty name_zh → ERR-SYS02-08")


func test_D08_TST_get_port_unknown_id_null_last_error() -> void:
	# D-08c／TST: get_port 未知 id → null＋last_error ERR-SYS02-09；不得中止、不得回空白物件.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "unknown_id/", free_count)
	var errors: Array = PortRegistry.load_and_validate(dir)
	assert_eq(errors.size(), 0)
	assert_true(PortRegistry.is_loaded())

	var missing: PortDef = PortRegistry.get_port(D08_UNKNOWN_PORT_ID)
	assert_true(missing == null, "unknown id must return null (not blank PortDef)")
	assert_true(_last_error_is(ERR_SYS02_09), "expected ERR-SYS02-09 UNKNOWN_ID in last_error")

	var known_id: String = PortRegistry.all_ids()[0]
	var found: PortDef = PortRegistry.get_port(known_id)
	assert_true(found != null)
	assert_eq(found.port_id, known_id)
	assert_true(PortRegistry.last_error().is_empty(), "success clears last_error")


func test_WP59_D08c_get_role_unknown_returns_role_invalid() -> void:
	# R3-02 ①: get_role unknown port/good → ROLE_INVALID (0) + last_error ERR-SYS02-09; no assert abort.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "d08c_role/", free_count)
	assert_eq(PortRegistry.load_and_validate(dir).size(), 0)

	assert_eq(PortRegistry.ROLE_INVALID, 0, "ROLE_INVALID must be 0 (D-04)")
	assert_ne(PortRegistry.ROLE_PRODUCER, 0, "valid roles renumbered from 1")
	assert_ne(PortRegistry.ROLE_TRANSIT, 0)
	assert_ne(PortRegistry.ROLE_TERMINAL, 0)

	var good_id: String = GoodCatalog.all_ids()[0]
	assert_eq(PortRegistry.get_role(D08_UNKNOWN_PORT_ID, good_id), PortRegistry.ROLE_INVALID)
	assert_true(_last_error_is(ERR_SYS02_09), "unknown port → ERR-SYS02-09")

	var known_port: String = PortRegistry.all_ids()[0]
	assert_eq(PortRegistry.get_role(known_port, D08_UNKNOWN_GOOD_ID), PortRegistry.ROLE_INVALID)
	assert_true(_last_error_is(ERR_SYS02_09), "unknown good → ERR-SYS02-09")

	var role: int = PortRegistry.get_role(known_port, good_id)
	assert_ne(role, PortRegistry.ROLE_INVALID)
	assert_true(PortRegistry.last_error().is_empty(), "success clears last_error")


func test_WP59_D08c_array_lookups_unknown_empty_last_error() -> void:
	# R3-02 ②: get_downstream／producers_of／terminals_of unknown id → empty + last_error ERR-SYS02-09.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "d08c_arrays/", free_count)
	assert_eq(PortRegistry.load_and_validate(dir).size(), 0)

	var good_id: String = GoodCatalog.all_ids()[0]
	var downs_bad: PackedStringArray = PortRegistry.get_downstream(D08_UNKNOWN_PORT_ID, good_id)
	assert_eq(downs_bad.size(), 0)
	assert_true(_last_error_is(ERR_SYS02_09), "get_downstream unknown port → ERR-SYS02-09")

	var known_port: String = PortRegistry.all_ids()[0]
	var downs_bad_good: PackedStringArray = PortRegistry.get_downstream(known_port, D08_UNKNOWN_GOOD_ID)
	assert_eq(downs_bad_good.size(), 0)
	assert_true(_last_error_is(ERR_SYS02_09), "get_downstream unknown good → ERR-SYS02-09")

	var producers_bad: PackedStringArray = PortRegistry.producers_of(D08_UNKNOWN_GOOD_ID)
	assert_eq(producers_bad.size(), 0)
	assert_true(_last_error_is(ERR_SYS02_09), "producers_of unknown → ERR-SYS02-09")

	var terminals_bad: PackedStringArray = PortRegistry.terminals_of(D08_UNKNOWN_GOOD_ID)
	assert_eq(terminals_bad.size(), 0)
	assert_true(_last_error_is(ERR_SYS02_09), "terminals_of unknown → ERR-SYS02-09")


func test_WP59_D08c_success_clears_last_error_empty_not_failure() -> void:
	# R3-02 ③: all id-lookup public methods clear last_error on success so empty array ≠ failure.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "d08c_clear/", free_count)
	assert_eq(PortRegistry.load_and_validate(dir).size(), 0)

	# Seed a failure first.
	assert_eq(PortRegistry.get_role(D08_UNKNOWN_PORT_ID, GoodCatalog.all_ids()[0]), PortRegistry.ROLE_INVALID)
	assert_true(_last_error_is(ERR_SYS02_09))

	var good_id: String = GoodCatalog.all_ids()[0]
	var known_port: String = PortRegistry.all_ids()[0]
	assert_true(PortRegistry.get_port(known_port) != null)
	assert_true(PortRegistry.last_error().is_empty(), "get_port success clears")

	assert_eq(PortRegistry.producers_of(D08_UNKNOWN_GOOD_ID).size(), 0)
	assert_true(_last_error_is(ERR_SYS02_09))
	var producers: PackedStringArray = PortRegistry.producers_of(good_id)
	assert_gt(producers.size(), 0)
	assert_true(PortRegistry.last_error().is_empty(), "producers_of success clears")

	assert_eq(PortRegistry.terminals_of(D08_UNKNOWN_GOOD_ID).size(), 0)
	assert_true(_last_error_is(ERR_SYS02_09))
	var terminals: PackedStringArray = PortRegistry.terminals_of(good_id)
	assert_gt(terminals.size(), 0)
	assert_true(PortRegistry.last_error().is_empty(), "terminals_of success clears")

	# TERMINAL cells have empty downstream; success must still clear last_error.
	assert_eq(PortRegistry.get_downstream(D08_UNKNOWN_PORT_ID, good_id).size(), 0)
	assert_true(_last_error_is(ERR_SYS02_09))
	var downs: PackedStringArray = PortRegistry.get_downstream(known_port, good_id)
	assert_eq(downs.size(), 0, "TERMINAL fixture has empty downstream")
	assert_true(PortRegistry.last_error().is_empty(), "empty success ≠ failure")


func test_WP59_D08c_queue_role_change_unknown_rejects() -> void:
	# R3-02 ④: queue_role_change unknown port/good → reject enqueue ERR-SYS02-09 (D-02); no assert.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var free_count: int = _valid_free_count(port_count)
	var dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "d08c_queue/", free_count)
	assert_eq(PortRegistry.load_and_validate(dir).size(), 0)

	var good_id: String = GoodCatalog.all_ids()[0]
	var bad_port: Array = PortRegistry.queue_role_change(
		D08_UNKNOWN_PORT_ID, good_id, PortRegistry.ROLE_TERMINAL, {}
	)
	assert_eq(bad_port.size(), 1)
	assert_true(_has_code(bad_port, ERR_SYS02_09), "unknown port → ERR-SYS02-09")
	assert_true(_last_error_is(ERR_SYS02_09))
	assert_push_error_count(1)

	var known_port: String = PortRegistry.all_ids()[0]
	var bad_good: Array = PortRegistry.queue_role_change(
		known_port, D08_UNKNOWN_GOOD_ID, PortRegistry.ROLE_TERMINAL, {}
	)
	assert_eq(bad_good.size(), 1)
	assert_true(_has_code(bad_good, ERR_SYS02_09), "unknown good → ERR-SYS02-09")
	assert_true(_last_error_is(ERR_SYS02_09))
	assert_push_error_count(2)

	# Nothing enqueued.
	assert_eq(PortRegistry.apply_queued_role_changes().size(), 0)
	assert_ne(PortRegistry.get_role(known_port, good_id), PortRegistry.ROLE_INVALID)


func _build_valid_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
		{"id": "GD-004", "name": STAPLE_FISH, "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(_make_good(s["id"], s["name"], 1, true, s["build"], false, 1), dir + "%s.tres" % s["id"])
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(_make_good(gid, "填料%d" % next_n, tier, false, false, false, next_n), dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	return dir


func _build_valid_ports(port_count: int, dir: String, free_count: int = -1) -> String:
	return FixtureBuilders.build_valid_ports(port_count, dir, free_count)


func _valid_free_count(port_count: int) -> int:
	return FixtureBuilders.valid_free_count(port_count)


func _set_transit(dir: String, port_id: String, good_id: String, downstream: PackedStringArray) -> void:
	var path := dir + "%s.tres" % port_id
	var def: PortDef = load(path) as PortDef
	var cell: RoleCell = def.role_cells[good_id]
	cell.role = PortRegistry.ROLE_TRANSIT
	cell.base_output_per_season = 0
	cell.downstream_terminals = downstream
	def.role_cells[good_id] = cell
	ResourceSaver.save(def, path)


func _add_second_producer(dir: String, port_id: String, good_id: String) -> void:
	var path := dir + "%s.tres" % port_id
	var def: PortDef = load(path) as PortDef
	var cell: RoleCell = def.role_cells[good_id]
	cell.role = PortRegistry.ROLE_PRODUCER
	cell.base_output_per_season = 1
	cell.downstream_terminals = PackedStringArray()
	def.role_cells[good_id] = cell
	ResourceSaver.save(def, path)


func _make_good(
	good_id: String,
	name_zh: String,
	tier: int,
	is_staple: bool,
	is_build_material: bool,
	is_strategic: bool,
	base_price_li: int
) -> GoodDef:
	return FixtureBuilders.make_good(
		good_id, name_zh, tier, is_staple, is_build_material, is_strategic, base_price_li
	)


func _wipe_dir(dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs_path):
		var d := DirAccess.open(dir)
		if d:
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if not d.current_is_dir():
					d.remove(fn)
				fn = d.get_next()
			d.list_dir_end()
	DirAccess.make_dir_recursive_absolute(abs_path)


func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if not _is_error_info(e):
			continue
		if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) == code:
			assert_eq(StringName(e.get(ErrorInfoUtil.KEY_SYS, &"")), SYS_ID, "ErrorInfo.sys must be SYS-02")
			var detail: Variant = e.get(ErrorInfoUtil.KEY_DETAIL, null)
			assert_eq(typeof(detail), TYPE_DICTIONARY, "ErrorInfo.detail must be Dictionary")
			return true
	return false


func _last_error_is(code: StringName) -> bool:
	var e: Dictionary = PortRegistry.last_error()
	if not _is_error_info(e):
		return false
	if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) != code:
		return false
	assert_eq(StringName(e.get(ErrorInfoUtil.KEY_SYS, &"")), SYS_ID, "ErrorInfo.sys must be SYS-02")
	return true


func _is_error_info(e: Variant) -> bool:
	# D-04 carrier: {code: StringName, sys: StringName, detail: Dictionary}.
	if typeof(e) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = e
	if not d.has(ErrorInfoUtil.KEY_CODE):
		return false
	if not d.has(ErrorInfoUtil.KEY_SYS):
		return false
	if not d.has(ErrorInfoUtil.KEY_DETAIL):
		return false
	# Reject legacy flat shape and any int-coded errors (D-04 withdraw −1..−5 / ERR→int).
	if typeof(d[ErrorInfoUtil.KEY_CODE]) == TYPE_INT:
		return false
	return true
