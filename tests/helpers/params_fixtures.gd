class_name ParamsFixtures
extends RefCounted
## WP-59 G3: single baseline params fixture + programmatic variants (demo／missing-key).


const BASELINE_PATH := "res://tests/fixtures/params_all_keys.json"

const KEY_START_CASH := "PRM-SYS05-START_CASH"
const KEY_ARREARS := "PRM-SYS05-ARREARS_SEASONS_TO_BANKRUPT"
const KEY_WEIGHT_SUM := "PRM-SYS06-WEIGHT_SUM"
const KEY_DAYS_PER_WEEK := "PRM-SYS04-DAYS_PER_WEEK"

## Demo variant values (former params_sys05_demo.json).
const DEMO_START_CASH := 150000
const DEMO_ARREARS_SEASONS := 2


static func load_baseline() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(BASELINE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert(typeof(parsed) == TYPE_DICTIONARY, "params baseline must be Dictionary")
	return (parsed as Dictionary).duplicate(true)


static func write_user_dict(data: Dictionary, filename: String) -> String:
	var path := "user://%s" % filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "open user params fixture %s" % path)
	file.store_string(JSON.stringify(data))
	file.close()
	return path


static func path_demo() -> String:
	## START_CASH／ARREARS values needed for genesis_grant／boot paths.
	var data: Dictionary = load_baseline()
	data[KEY_START_CASH] = DEMO_START_CASH
	data[KEY_ARREARS] = DEMO_ARREARS_SEASONS
	return write_user_dict(data, "params_sys05_demo.json")


static func path_missing_key(erase_key: String) -> String:
	var data: Dictionary = load_baseline()
	data.erase(erase_key)
	var safe: String = erase_key.replace("/", "_").replace(":", "_")
	return write_user_dict(data, "params_missing_%s.json" % safe)


static func path_missing_weight_sum() -> String:
	return path_missing_key(KEY_WEIGHT_SUM)


static func path_missing_days_per_week() -> String:
	return path_missing_key(KEY_DAYS_PER_WEEK)
