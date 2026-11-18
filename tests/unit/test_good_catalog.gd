extends GutTest
## WP-03 GoodCatalog tests. Fixture values from TechSpec §4 / TST-SYS01-01..04 / 3.2 G.
## D-04: failures are ErrorInfo Dictionaries {code, sys, detail}; no ERR→int.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const FIXTURE_ROOT := "user://goods_fixtures/"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_GOOD_COUNT_MAX := "PRM-SYS01-GOOD_COUNT_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"

const SYS_ID := &"SYS-01"
const ERR_SYS01_01 := &"ERR-SYS01-01"
const ERR_SYS01_02 := &"ERR-SYS01-02"
const ERR_SYS01_03 := &"ERR-SYS01-03"
const ERR_SYS01_04 := &"ERR-SYS01-04"
const ERR_SYS01_05 := &"ERR-SYS01-05"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"


func before_each() -> void:
	var params_errors: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(params_errors.size(), 0, "params fixture must load")
	_wipe_dir(FIXTURE_ROOT)


func test_TST_SYS01_01_duplicate_good_id_rejects() -> void:
	# TST-SYS01-01: 兩筆貨物 good_id 相同 → ERR-SYS01-01，拒絕啟動
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var dir := _build_valid_catalog(count_min, FIXTURE_ROOT + "dup/")
	# Second file reuses first good_id (GD-001).
	var twin := _make_good("GD-001", "填料重複", 1, false, false, false, 1)
	var twin_path := dir + "dup_extra.tres"
	var save_err: Error = ResourceSaver.save(twin, twin_path)
	assert_eq(save_err, OK)

	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(GoodCatalog.is_loaded())
	assert_true(_has_code(errors, ERR_SYS01_01), "expected ERR-SYS01-01")


func test_TST_SYS01_02_tier_zero_rejects() -> void:
	# TST-SYS01-02: 某貨 tier = 0 → ERR-SYS01-02
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var dir := _build_valid_catalog(count_min, FIXTURE_ROOT + "tier0/")
	var bad := _make_good("GD-099", "壞層級", 0, false, false, false, 1)
	ResourceSaver.save(bad, dir + "bad_tier.tres")
	# Keep count in range: remove one filler so total files stay at count_min.
	_remove_file(dir + "GD-005.tres")

	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(GoodCatalog.is_loaded())
	assert_true(_has_code(errors, ERR_SYS01_02), "expected ERR-SYS01-02")


func test_TST_SYS01_02_tier_above_max_rejects() -> void:
	# TST-SYS01-02: 某貨 tier > TIER_MAX → ERR-SYS01-02 (PRM-SYS01-TIER_MAX)
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var dir_hi := _build_valid_catalog(count_min, FIXTURE_ROOT + "tier_hi/")
	var tier_max: int = Params.get_int(PRM_TIER_MAX)
	var bad_hi := _make_good("GD-098", "超層級", tier_max + 1, false, false, false, 1)
	ResourceSaver.save(bad_hi, dir_hi + "bad_tier_hi.tres")
	_remove_file(dir_hi + "GD-005.tres")
	var errors_hi: Array = GoodCatalog.load_and_validate(dir_hi)
	assert_gt(errors_hi.size(), 0)
	assert_push_error_count(errors_hi.size())
	assert_true(_has_code(errors_hi, ERR_SYS01_02), "expected ERR-SYS01-02 for tier > TIER_MAX")
	assert_false(GoodCatalog.is_loaded())


func test_ERR_SYS01_03_non_positive_price_rejects() -> void:
	# TechSpec 3.2 G: ERR-SYS01-03 fixture (價格≤0); not in TST-SYS01-01..04 list but required by G.
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var dir := _build_valid_catalog(count_min, FIXTURE_ROOT + "price0/")
	var bad := _make_good("GD-097", "零價", 1, false, false, false, 0)
	ResourceSaver.save(bad, dir + "bad_price.tres")
	_remove_file(dir + "GD-005.tres")

	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(GoodCatalog.is_loaded())
	assert_true(_has_code(errors, ERR_SYS01_03), "expected ERR-SYS01-03")


func test_TST_SYS01_03_count_below_min_rejects() -> void:
	# TST-SYS01-03: 貨物數 < GOOD_COUNT_MIN → ERR-SYS01-04
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var too_few: int = count_min - 1
	var dir := _build_valid_catalog(too_few, FIXTURE_ROOT + "few/")

	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(GoodCatalog.is_loaded())
	assert_true(_has_code(errors, ERR_SYS01_04), "expected ERR-SYS01-04")


func test_TST_SYS01_04_missing_dried_fish_staple_rejects() -> void:
	# TST-SYS01-04: 剛需四項缺魚乾 → ERR-SYS01-05
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var dir := _build_valid_catalog(count_min, FIXTURE_ROOT + "no_fish/", false)

	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(GoodCatalog.is_loaded())
	assert_true(_has_code(errors, ERR_SYS01_05), "expected ERR-SYS01-05")


func test_valid_catalog_loads_sorted_ids_and_derives_scale() -> void:
	# Happy path: FRM-SYS01-01 pass, FRM-SYS01-02 controlled_scale_only, all_ids ascending, catalog_loaded.
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var dir := _build_valid_catalog(count_min, FIXTURE_ROOT + "ok/")
	watch_signals(GoodCatalog)

	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_eq(errors.size(), 0)
	assert_true(GoodCatalog.is_loaded())
	assert_signal_emitted(GoodCatalog, "catalog_loaded")

	var ids: PackedStringArray = GoodCatalog.all_ids()
	assert_eq(ids.size(), count_min)
	for i in range(ids.size()):
		if i == 0:
			continue
		assert_true(ids[i - 1] < ids[i], "all_ids must be ascending")

	var rice: GoodDef = GoodCatalog.get_good("GD-001")
	assert_eq(rice.name_zh, STAPLE_RICE)
	assert_true(rice.is_staple)

	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	# GD-006 is tier free_max+1 filler when count allows — find any controlled_scale_only via formula.
	var found_high_tier := false
	for id in ids:
		var g: GoodDef = GoodCatalog.get_good(id)
		var expected: bool = (g.tier > free_max) or g.is_strategic
		assert_eq(g.controlled_scale_only, expected, "FRM-SYS01-02 for %s" % id)
		if g.tier > free_max:
			found_high_tier = true
	assert_true(found_high_tier, "fixture should include tier > FREE_PORT_TIER_MAX")

	var recheck: Array = GoodCatalog.validate()
	assert_eq(recheck.size(), 0)


func test_count_above_max_rejects() -> void:
	# ERR-SYS01-04 upper bound (FRM-SYS01-01 goods count ∈ [MIN,MAX]).
	var count_max: int = Params.get_int(PRM_GOOD_COUNT_MAX)
	var too_many: int = count_max + 1
	var dir := _build_valid_catalog(too_many, FIXTURE_ROOT + "many/")
	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_true(_has_code(errors, ERR_SYS01_04), "expected ERR-SYS01-04 for count > MAX")
	assert_false(GoodCatalog.is_loaded())


func _build_valid_catalog(count: int, dir: String, include_fish: bool = true) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var staples: Array = [
		{"id": "GD-001", "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
	]
	if include_fish:
		staples.append({"id": "GD-004", "name": STAPLE_FISH, "build": false})

	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		var def := _make_good(s["id"], s["name"], 1, true, s["build"], false, 1)
		ResourceSaver.save(def, dir + "%s.tres" % s["id"])
		written += 1

	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		# Alternate tiers 1..free_max+1 so FRM-SYS01-02 is exercised (test literals OK).
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		var def := _make_good(gid, "填料%d" % next_n, tier, false, false, false, next_n)
		ResourceSaver.save(def, dir + "%s.tres" % gid)
		written += 1
		next_n += 1

	return dir


func _make_good(
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
	def.season_mask = 0
	return def


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


func _remove_file(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if not _is_error_info(e):
			continue
		if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) == code:
			assert_eq(StringName(e.get(ErrorInfoUtil.KEY_SYS, &"")), SYS_ID, "ErrorInfo.sys must be SYS-01")
			var detail: Variant = e.get(ErrorInfoUtil.KEY_DETAIL, null)
			assert_eq(typeof(detail), TYPE_DICTIONARY, "ErrorInfo.detail must be Dictionary")
			return true
	return false


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
	return typeof(d[ErrorInfoUtil.KEY_DETAIL]) == TYPE_DICTIONARY


func test_D04_error_info_shape_not_int_codes() -> void:
	# D-04: ErrorInfo Dictionary only; no ERR→int / −1..−5.
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var dir := _build_valid_catalog(count_min - 1, FIXTURE_ROOT + "d04_shape/")
	var errors: Array = GoodCatalog.load_and_validate(dir)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	for e in errors:
		assert_true(_is_error_info(e), "every failure must be D-04 ErrorInfo Dictionary")
		assert_false(typeof(e) == TYPE_INT, "must not return bare int error codes")
	assert_true(_has_code(errors, ERR_SYS01_04), "expected ERR-SYS01-04 as StringName code")
