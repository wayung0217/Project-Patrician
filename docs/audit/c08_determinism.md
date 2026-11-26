# N3 C-08 決定性稽核（17-76）

- **Pack:** 17-76 / lane=AUDIT
- **Repo tip:** `e2a99d26df99d640977f4699073bbc85dc48f82f`
- **Scope:** `autoload/`、`core/`、`sim/`（72 `.gd`）
- **Rules:** C-08；例外 EX-04／D-78（sim `Time.get_ticks_msec`→elapsed_ms）；EX-01…06／D-77 對照
- **Method:** (a)(b)(c)(e) 關鍵字＋人工判註；(d) 先列全部 `for … in *.keys()/values()/items()`，再逐段讀前後文是否 `sort`／交換律。**未改碼。**

## 總覽

| 類 | 掃描命中 | 結論摘要 |
|---|---:|---|
| (a) rand*／未種子 RNG | **0** | 無 `randi`／`randf`／`randomize`／`RandomNumberGenerator` |
| (b) Time.*／OS.get_ticks_* | **5** | 全在 `sim/sim_engine.gd`，皆 `Time.get_ticks_msec()` → **EX-04／D-78** |
| (c) priority／deferred／await／Timer | **0**（活碼） | 僅註解提及 `call_deferred`／Timer |
| (d) 未排序集合遍歷 | 見下 | `.keys()` 直接遍歷 **35** 處；其中 11 處迴圈後有 sort；其餘需裁決 |
| (e) 特定 ID 分支 | **0** 實體 ID | 掃描命中為階級／建類列舉字串（非 PT-/ACT- 特例） |

## (a) 隨機 API

指令：`rg -n 'randi|randf|randomize|RandomNumberGenerator|randi_range|randf_range' autoload core sim -g'*.gd'` → **無命中**（產品碼用 `core/rng.gd` 種子 RNG，屬決定性路徑，非本條禁用 API）。

## (b) 時間來源（5）— 均核准

| 檔案:行號 | 原文 | 例外 |
|---|---|---|
| `sim/sim_engine.gd:123` | `var t0: int = Time.get_ticks_msec()` | EX-04 / D-78 (sim/ elapsed_ms only) |
| `sim/sim_engine.gd:241` | `_progress_t0_msec = Time.get_ticks_msec()` | EX-04 / D-78 (sim/ elapsed_ms only) |
| `sim/sim_engine.gd:298` | `var elapsed: int = Time.get_ticks_msec() - t0` | EX-04 / D-78 (sim/ elapsed_ms only) |
| `sim/sim_engine.gd:347` | `"elapsed_ms": Time.get_ticks_msec() - t0,` | EX-04 / D-78 (sim/ elapsed_ms only) |
| `sim/sim_engine.gd:424` | `var elapsed_ms: int = Time.get_ticks_msec() - _progress_t0_msec` | EX-04 / D-78 (sim/ elapsed_ms only) |

證據：`05_TechSpec.csv` D-78；AI_README 6.2 EX-04。autoload／core **無** `Time.*`／`OS.get_ticks_*`。

## (c) 非決定排序／延遲

- `process_priority`／`z_index`／活碼 `call_deferred(`／`await`／`Timer`：**0**
- 註解證據：`autoload/sim_loop.gd:330`「no signal / call_deferred」；`sim/sim_runner.gd:12`「No call_deferred／await／Timer」。

## (d) Dictionary／集合遍歷（最重要）

### d-1 直接 `for … in *.keys()` 且後續有 sort（11）— 符合 C-08

樣例：

| 檔案:行號 | 函數 | 證據 |
|---|---|---|
| `autoload/building_economy.gd:756` | `season_step` | 收集 port ids 後 sort |
| `autoload/building_economy.gd:832` | `_step_produce` | keys→array→sort |
| `autoload/ship_registry.gd:517` | `tick_step` | keys 後 sort |
| `autoload/goods_ledger.gd:381` 等 | conservation／offtake／aggregate | collect+sort |
| `sim/relocator.gd:66` | `plan_one_good` | stocks.keys 後排序 |
| `sim/metrics.gd:333/377` | `_met04/_met05` | 後續 sort_custom |

### d-2 交換律／純累加（順序不影響數值）

| 檔案:行號 | 函數 | 為何像交換律 |
|---|---|---|
| `building_economy.gd:2240` | `city_auto_housing_count` | 計數 `n+1` |
| `cash_ledger.gd:979` | `_reset_season_stats_opening` | 逐帳戶重置 |
| `demand_model.gd:271` | `sat_weight_sum` | 權重求和 |
| `sim_engine.gd:355` | `_combo_count` | 乘法累積候選數 |
| `building_economy.gd:2621` | `_step_land_held_days` | 每槽 `+=1`（鍵獨立） |
| `building_economy.gd:3120` | `_clear_season_accums` | 逐鍵清零 |

**缺口：** 交換律是否視為滿足 C-08「先排序」字面要求，還是仍要先 sort 再累加？（只記不動手）

### d-3 可能影響輸出／選擇結果 — 違規候選（需裁決）

| # | 檔案:行號 | 函數 | 字面量／迭代 | 風險 | 證據摘要 |
|---:|---|---|---|---|---|
| 1 | `autoload/building_economy.gd:2002` | `_def_for_output_good` | `_building_defs.keys()` | **高** | 找到第一個匹配 IND* 即 `break` — **依賴 Dictionary 插入序** 決定回傳哪一個 BuildingDef |
| 2 | `autoload/building_economy.gd:1309` | `_apply_acquire` | `need.keys()` | 中 | 依鍵順序呼叫已取得結果折入 `locked`；若下游依 locked 插入序，可能影響 |
| 3 | `autoload/building_economy.gd:568/663` | `order_upgrade`／`public_upgrade_fee` | `row.keys()` | 中 | 組 `mat_need`／`mats` Dictionary；之後若未再 sort 即消耗材料，插入序=遍歷序 |
| 4 | `autoload/cash_ledger.gd:930` | `_restore_snap` | `balances.keys()` | 中 | 還原餘額順序；若觸發副作用需確認 |
| 5 | `autoload/trader_registry.gd:409` | `daily_step` | `excl_v.keys()` | 中 | 探索排除集遍歷 |
| 6 | `autoload/params.gd:337/381/400/465/541` | 各 `_parse_*` | `obj.keys()` 等 | 低–中 | boot 解析／錯訊順序；通常不改模擬態，但錯誤列表順序非決定性 |
| 7 | `sim/scenario_validator.gd:209/248/261/316` | 驗證器 | layers/overrides/grid/schema keys | 低–中 | 同上，錯訊順序 |
| 8 | `sim/sim_engine.gd:83` / `sim_runner.gd:247` | merge daily_rows | `daily_rows.keys()` | 中 | 合併各 port 日列；**CSV 列順序**可能隨 Dictionary 序變 |

#### 關鍵原文（#1）

```
autoload/building_economy.gd:2000-2012
func _def_for_output_good(good_id: String) -> BuildingDef:
    var best: BuildingDef = null
    for k in _building_defs.keys():
        ...
        if d.build_class == "IND1" or ...:
            best = d
            break
    return best
```

### d-4 其餘 for（Array／已排序 API）

大量 `for x in PortRegistry.all_ids()`／已 sort 的 pending 陣列等：掃描標為 MEDIUM 供複核；抽樣見 `all_ids()` 本身是否保證升序（若 all_ids 已 sort 則合規）。**缺口：** 請確認 `PortRegistry.all_ids()`／`GoodCatalog` 等入口的排序契約是否寫死。

## (e) 特定 ID 的 if

未發現 `if … == "PT-.."`／`ACT-..` 等實體特例。

掃描誤報（列舉／欄名，不是實體 ID）：

| 檔案:行號 | 片段 | 判定 |
|---|---|---|
| `building_economy.gd:570` | `ks == "CASH_LI" or … "DAYS"` | 參數欄名 |
| `building_economy.gd:1736` 等 | `build_class == "IND1"` | 規格建類列舉 |
| `demand_model.gd:771-777` | `s == "POOR"/"CITIZEN"/"RICH"/"BEGGAR"` | 人口階級列舉 |

## 缺口彙總（B-4）

1. `_def_for_output_good` 是否必須 keys 排序後再選（或改唯一索引）？
2. 交換律迴圈是否仍強制先 sort？
3. 驗證器／params 錯訊順序是否納入決定性契約？
4. daily_rows 合併輸出順序是否要 port_id 升序？

本報告：`docs/audit/c08_determinism.md`
