# N6 params_schema 全鍵必填查證（17-76）

- **Pack:** 17-76 / lane=AUDIT
- **Repo tip:** `e2a99d26df99d640977f4699073bbc85dc48f82f`
- **未改碼**

## (a) schema 中「決定必填」的原文

`data/params/params_schema.json` **沒有** per-key `"required": true/false` 欄位（129 個頂層 PRM 規則皆無 `required` 鍵）。

「必填」不是 schema JSON 的欄位語意，而是：**出現在 schema 根物件裡的每一個 PRM 鍵，驗證器一律當必填。**

schema 條目形狀（例，檔案:行號）：

```1:6:data/params/params_schema.json
{
  "PRM-SYS00-DAYS_PER_SEASON": {
    "type": "int",
    "min": 90,
    "max": 90
  },
```

物件型規則用 `"keys": [...]` 列出**物件內**必填子鍵（例 `PRM-SYS08-BUILD_CASH_LI`），同樣沒有 optional 標記：

```text
"PRM-SYS08-BUILD_CASH_LI": {
  "type": "int_object",
  "keys": ["RESIDENCE", "WAREHOUSE", "IND1", "IND2", "IND3", "PUBLIC", "KONTOR"],
  "min": 0
}
```

（`rg '"required"' data/params/params_schema.json` → 0 命中。）

## (b) 驗證器讀 schema 的程式碼

載入：`autoload/params.gd` `SCHEMA_PATH := "res://data/params/params_schema.json"`（約 L6）；`load_and_validate` 讀入 `_schema`（約 L50–58）。

頂層全鍵必填迴圈（檔案:行號）：

```70:85:autoload/params.gd
	var schema_keys: Array = _schema.keys()
	schema_keys.sort()
	for key_variant in schema_keys:
		var key: String = String(key_variant)
		var rule: Variant = _schema[key]
		if typeof(rule) != TYPE_DICTIONARY:
			errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "schema rule must be Dictionary"))
			continue
		if not params.has(key):
			# 1-A8 / TechSpec §4 / D-09f: missing required PRM key → refuse boot.
			errors.append(_err("MISSING_KEY", params_path, key, null, "required PRM key missing"))
			continue
		var value: Variant = params[key]
		if _is_empty_value(value):
			# TechSpec 10-04 / brief: empty value → refuse boot; do not invent defaults.
			errors.append(_err("EMPTY_VALUE", params_path, key, value, "required PRM value empty"))
			continue
```

註：同函式尚會對 `params.json` 多出的未知鍵報 `UNKNOWN_KEY`（約 L91–97）。

## (c) 一句話結論

**是——在 schema 根新增任一 PRM 鍵後，`params.json` 必須同時有該鍵且非空值，否則 boot 以 `MISSING_KEY`／`EMPTY_VALUE` 拒絕；schema 本身沒有「登記但不必填」的開關。**

（這與情境 `overrides`／`sim_overrides_draft` 只覆寫已存在 PRM 的路徑不同：覆寫不能代替 schema∩params 的必填對。D-48b／D-45b 通則需在此約束下訂。）

本報告：`docs/audit/params_schema_required.md`
