# N2 C-03 magic number 全碼稽核（17-76）

- **Pack:** 17-76 / lane=AUDIT
- **Repo tip:** `e2a99d26df99d640977f4699073bbc85dc48f82f`
- **Scope:** `autoload/**/*.gd`, `core/**/*.gd`, `sim/**/*.gd`（**72** files）
- **Rules:** C-03 + D-56a（0/1/0.0/1.0 允許）+ AI_README 6.2 EX-01…EX-06 + D-40a（本範圍無 csv_import）+ D-77
- **Method:** strip `#` comments & string literals; regex numeric literals including optional leading `-`; classify per exception text. **未改任何產品碼。**

## 合計

| 分類 | 筆數 |
|---|---:|
| ALLOWED | 1627 |
| UNCOVERED | 61 |
| EX-01 | 43 |
| EX-02 | 18 |
| EX-03 | 8 |
| EX-06 | 1 |
| **總字面量命中** | **1758** |

### 分類說明（證據來源）

- **ALLOWED：** C-03「只准 0、1」+ D-56a「0.0／1.0 視同允許」（`05_TechSpec.csv` C-03；D-56a）。
- **EX-01：** 全部位於 `core/rng.gd`（AI_README 6.2 EX-01）。
- **EX-02：** 具名 const 哨兵（名含 SENTINEL／FAILURE／FLOOR／UNREACHABLE 等，或行註 `EX-02`／「哨兵」）。
- **EX-03：** `enum` 成員或具名規格列舉 const（Role／DRAFT_*／WORKSHOP_TIER_*／CONTACT_LEVEL_*；或行註 EX-03）。
- **EX-06：** `population_model.gd` `ACADEMY_MULT_UNIT := 1000`。
- **EX-04／EX-05／D-40a：** 本掃描範圍無命中（EX-04 是 Time.*；EX-05／D-40a 限 `tools/csv_import.gd`）。
- **UNCOVERED：** 無對應核准例外 → 違規候選（只列不動手）。

## (3) UNCOVERED 違規候選（61 筆）

| # | 檔案:行號 | 字面量 | 所在函數／const | 看起來代表什麼 | 原文片段 |
|---:|---|---|---|---|---|
| 1 | `autoload/building_economy.gd:521` | `-1` | `order_build` | in order_build | `slot.vacancy_start_day = -1` |
| 2 | `autoload/building_economy.gd:1298` | `-1` | `_is_gathering_belt` | in _is_gathering_belt | `var max_open: int = int(_max_open_zone.get(slot.port_id, -1))` |
| 3 | `autoload/building_economy.gd:1428` | `-1` | `_build_port_slots` | in _build_port_slots | `var max_open: int = -1` |
| 4 | `autoload/building_economy.gd:1993` | `-1` | `_spawn_active_building` | in _spawn_active_building | `slot.vacancy_start_day = -1` |
| 5 | `autoload/building_economy.gd:2068` | `-1` | `_find_open_civil_slot_outermost` | in _find_open_civil_slot_outermost | `var best_ring := -1` |
| 6 | `autoload/building_economy.gd:2238` | `-1` | `city_auto_housing_count` | in city_auto_housing_count | `return -1` |
| 7 | `autoload/building_economy.gd:2273` | `-1` | `city_queue_position` | in city_queue_position | `return -1` |
| 8 | `autoload/building_economy.gd:2602` | `-1` | `_step_zone_streak` | in _step_zone_streak | `var next_zone: int = int(_max_open_zone.get(port_id, -1)) + 1` |
| 9 | `autoload/building_economy.gd:2901` | `-1` | `_season_zone_open` | in _season_zone_open | `var next_zone: int = int(_max_open_zone.get(port_id, -1)) + 1` |
| 10 | `autoload/building_economy.gd:3050` | `-1` | `_find_city_housing_slot` | in _find_city_housing_slot | `var best_ring := -1` |
| 11 | `autoload/building_economy.gd:3194` | `-1` | `season_land_rent_li` | in season_land_rent_li | `return -1` |
| 12 | `autoload/building_economy.gd:3198` | `-1` | `season_land_rent_li` | in season_land_rent_li | `return -1` |
| 13 | `autoload/building_economy.gd:3209` | `-1` | `season_vacancy_tax_li` | in season_vacancy_tax_li | `return -1` |
| 14 | `autoload/building_economy.gd:3213` | `-1` | `season_vacancy_tax_li` | in season_vacancy_tax_li | `return -1` |
| 15 | `autoload/cash_ledger.gd:90` | `2` | `<const INT_DIV_MID_DENOM>` | const INT_DIV_MID_DENOM = 2 | `const INT_DIV_MID_DENOM := 2` |
| 16 | `autoload/cash_ledger.gd:682` | `-1` | `max_affordable_qty` | in max_affordable_qty | `var abs_hi: int = -1` |
| 17 | `autoload/intel_ledger.gd:27` | `2` | `<const MIN_SAMPLES_FOR_TREND>` | const MIN_SAMPLES_FOR_TREND = 2 | `const MIN_SAMPLES_FOR_TREND := 2` |
| 18 | `autoload/market_pricer.gd:42` | `2.0` | `<const TRAPEZOID_DENOM>` | const TRAPEZOID_DENOM = 2.0 | `const TRAPEZOID_DENOM := 2.0 ## D-84f: trapezoid area divisor (was 1.0+1.0)` |
| 19 | `autoload/population_model.gd:108` | `-1` | `<top>` | top-N cutoff | `var _last_flow_season: int = -1` |
| 20 | `autoload/population_model.gd:266` | `-1` | `set_port_state` | in set_port_state | `sat_poor: int = -1,` |
| 21 | `autoload/population_model.gd:267` | `-1` | `set_port_state` | in set_port_state | `sat_citizen: int = -1,` |
| 22 | `autoload/population_model.gd:268` | `-1` | `set_port_state` | in set_port_state | `sat_rich: int = -1` |
| 23 | `autoload/population_model.gd:1470` | `-1` | `_clear_state` | in _clear_state | `_last_flow_season = -1` |
| 24 | `autoload/population_model.gd:1500` | `-1` | `_emit` | in _emit | `var sat_poor: int = -1` |
| 25 | `autoload/population_model.gd:1501` | `-1` | `_emit` | in _emit | `var sat_citizen: int = -1` |
| 26 | `autoload/population_model.gd:1502` | `-1` | `_emit` | in _emit | `var sat_rich: int = -1` |
| 27 | `autoload/ship_registry.gd:738` | `2` | `_lane_other` | arity/size check | `if ends.size() != 2:` |
| 28 | `autoload/ship_registry.gd:836` | `2` | `_flush_signals` | array index (>1 not in C-03 0/1 allow-list) | `ship_departed.emit(args[0], args[1], args[2], args[3], args[4])` |
| 29 | `autoload/ship_registry.gd:836` | `3` | `_flush_signals` | array index (>1 not in C-03 0/1 allow-list) | `ship_departed.emit(args[0], args[1], args[2], args[3], args[4])` |
| 30 | `autoload/ship_registry.gd:836` | `4` | `_flush_signals` | array index (>1 not in C-03 0/1 allow-list) | `ship_departed.emit(args[0], args[1], args[2], args[3], args[4])` |
| 31 | `autoload/ship_registry.gd:838` | `2` | `_flush_signals` | array index (>1 not in C-03 0/1 allow-list) | `ship_rerouted.emit(args[0], args[1], args[2])` |
| 32 | `autoload/ship_registry.gd:840` | `2` | `_flush_signals` | array index (>1 not in C-03 0/1 allow-list) | `ship_arrived.emit(args[0], args[1], args[2], args[3])` |
| 33 | `autoload/ship_registry.gd:840` | `3` | `_flush_signals` | array index (>1 not in C-03 0/1 allow-list) | `ship_arrived.emit(args[0], args[1], args[2], args[3])` |
| 34 | `autoload/trader_registry.gd:429` | `2` | `flush_signals` | array index (>1 not in C-03 0/1 allow-list) | `trader_plan_set.emit(args[0], args[1], args[2])` |
| 35 | `autoload/trader_registry.gd:651` | `1e-9` | `_pick_explore_traders` | inline epsilon (EX-02 requires named const) | `var n_pick: int = int(floor(float(ids.size()) * rate + 1e-9))` |
| 36 | `core/trade_evaluator.gd:103` | `-9223372036854775807` | `coarse_score` | inline int64-min-ish sentinel (not named) | `return -9223372036854775807` |
| 37 | `sim/csv_out.gd:129` | `-1` | `_write_season_ports` | in _write_season_ports | `_fmt(r.get("queue_position", -1)),` |
| 38 | `sim/csv_out.gd:130` | `-1` | `_write_season_ports` | in _write_season_ports | `_fmt(r.get("land_rent_li", -1)),` |
| 39 | `sim/csv_out.gd:131` | `-1` | `_write_season_ports` | in _write_season_ports | `_fmt(r.get("vacancy_tax_li", -1)),` |
| 40 | `sim/m1b_diag_z.gd:105` | `7` | `note_day_eval` | calendar day threshold (business candidate) | `if day == 1 or day == 7 or day == 30:` |
| 41 | `sim/m1b_diag_z.gd:105` | `30` | `note_day_eval` | calendar day threshold (business candidate) | `if day == 1 or day == 7 or day == 30:` |
| 42 | `sim/metrics.gd:10` | `4` | `<const OBS02_ZERO_STREAK_WARN>` | const OBS02_ZERO_STREAK_WARN = 4 | `const OBS02_ZERO_STREAK_WARN := 4` |
| 43 | `sim/metrics.gd:508` | `-1` | `_obs02_ext_rows` | in _obs02_ext_rows | `scenario_id, combo_index, seed, -1, pid, "",` |
| 44 | `sim/metrics.gd:513` | `-1` | `_obs02_ext_rows` | in _obs02_ext_rows | `scenario_id, combo_index, seed, -1, pid, "",` |
| 45 | `sim/metrics.gd:555` | `2` | `_obs04_rows` | arity/size check | `if parts.size() != 2:` |
| 46 | `sim/metrics.gd:597` | `-1` | `_obs04_rows` | in _obs04_rows | `scenario_id, combo_index, seed, -1, pid, gid2,` |
| 47 | `sim/metrics.gd:601` | `-1` | `_obs04_rows` | in _obs04_rows | `scenario_id, combo_index, seed, -1, pid, gid2,` |
| 48 | `sim/metrics.gd:630` | `-1` | `_obs05_rows` | in _obs05_rows | `var rent_v: int = _json_int(r.get("land_rent_li", -1))` |
| 49 | `sim/metrics.gd:631` | `-1` | `_obs05_rows` | in _obs05_rows | `var vac_v: int = _json_int(r.get("vacancy_tax_li", -1))` |
| 50 | `sim/sampler.gd:91` | `-1` | `sample_season` | in sample_season | `season_cells.append(_cell_row(run_id, seed, season_index, -1, port_s, good_s, true))` |
| 51 | `sim/sampler.gd:105` | `-1` | `sample_daily` | in sample_daily | `_cell_row(run_id, seed, -1, day, port_id, good_s, false)` |
| 52 | `sim/sampler.gd:121` | `-1` | `_sample_port_row` | in _sample_port_row | `var land_rent := -1` |
| 53 | `sim/sampler.gd:122` | `-1` | `_sample_port_row` | in _sample_port_row | `var vac_tax := -1` |
| 54 | `sim/sampler.gd:275` | `3` | `_top3_unmet_for_class` | top-N cutoff | `var n: int = mini(3, items.size())` |
| 55 | `sim/sim_engine.gd:423` | `100.0` | `_emit_season_progress` | percent scale for progress | `var pct_job: float = 100.0 * float(days_done) / float(maxi(total_days, 1))` |
| 56 | `sim/sim_engine.gd:425` | `1000` | `_emit_season_progress` | msec/sec time formatting (progress UI; not EX-04) | `var elapsed_s: int = int(elapsed_ms / 1000)` |
| 57 | `sim/sim_engine.gd:432` | `-1` | `_emit_season_progress` | in _emit_season_progress | `if int(row.get("season_index", -1)) != season_index:` |
| 58 | `sim/sim_engine.gd:466` | `3600` | `_fmt_hmm` | msec/sec time formatting (progress UI; not EX-04) | `var h: int = int(s / 3600)` |
| 59 | `sim/sim_engine.gd:467` | `3600` | `_fmt_hmm` | msec/sec time formatting (progress UI; not EX-04) | `var m: int = int((s % 3600) / 60)` |
| 60 | `sim/sim_engine.gd:467` | `60` | `_fmt_hmm` | msec/sec time formatting (progress UI; not EX-04) | `var m: int = int((s % 3600) / 60)` |
| 61 | `sim/sim_runner.gd:195` | `40` | `_run_scenario_orchestrator` | log tail line count | `_print_log_tail(log_abs, 40)` |

### UNCOVERED 分群（觀察，非改碼建議）

1. **裸 `-1` 哨兵（37）** — EX-02 要求「具名 const」；多處 inline `-1`（空缺／失敗／未設）。
2. **陣列索引 >1（args[2..]）** — C-03 允許索引僅 0／1；信號 flush 路徑。
3. **算術結構字面量** — `INT_DIV_MID_DENOM:=2`、`TRAPEZOID_DENOM:=2.0`（D-84：算術字面量不核准）。
4. **業務／觀測閾值** — `OBS02_ZERO_STREAK_WARN:=4`、`day==7/30`、`mini(3,…)`、`MIN_SAMPLES_FOR_TREND:=2`。
5. **進度 UI 時間換算** — `100.0`／`1000`／`3600`／`60`（EX-04 只涵蓋 `Time.get_ticks_msec` 本身，不含這些除數）。
6. **其他** — inline `1e-9`、`-9223372036854775807`、`log_tail(40)`、`size()!=2`。

## 已核准例外樣例（抽樣證據）

### EX-01（共 43）

- `core/rng.gd:8` `-3750763034362895579` — `const FNV_OFFSET := -3750763034362895579`
- `core/rng.gd:10` `1099511628211` — `const FNV_PRIME := 1099511628211`
- `core/rng.gd:12` `-7046029254386353131` — `const SPLITMIX_INC := -7046029254386353131`
- `core/rng.gd:13` `-4658895280553007687` — `const SPLITMIX_M1 := -4658895280553007687`
- `core/rng.gd:14` `-7723592293110705685` — `const SPLITMIX_M2 := -7723592293110705685`
- `core/rng.gd:16` `0x1f` — `const FIELD_SEP := 0x1f`
- `core/rng.gd:28` `-1` — `draw_seq: int = -1`
- `core/rng.gd:62` `30` — `z = _mul_u64(z ^ _ushr64(z, 30), SPLITMIX_M1)`
- … 另 35 筆（完整清單見掃描 JSON 備存於本機 `/tmp/n2_scan.json`，未入庫）

### EX-02（共 18）

- `autoload/building_economy.gd:77` `0x7fffffff` — `const FEAS_UNBOUNDED := 0x7fffffff`
- `autoload/building_economy.gd:81` `999999` — `const RING_SENTINEL_UNSET := 999999`
- `autoload/building_economy.gd:83` `-1` — `const PUBLIC_UPGRADE_CASH_FAIL := -1`
- `autoload/cash_ledger.gd:92` `-1` — `const INT_API_FAILURE := -1`
- `autoload/goods_ledger.gd:117` `-1` — `const DAY_SENTINEL_UNSET := -1`
- `autoload/population_model.gd:38` `1.0e-9` — `const RING_WEIGHT_FLOOR := 1.0e-9`
- `autoload/population_model.gd:39` `1.0e-9` — `const U_UNIT_FLOOR := 1.0e-9`
- `autoload/population_model.gd:41` `-1.0e30` — `const SCORE_SENTINEL_MIN := -1.0e30`
- … 另 10 筆（完整清單見掃描 JSON 備存於本機 `/tmp/n2_scan.json`，未入庫）

### EX-03（共 8）

- `autoload/intel_ledger.gd:25` `2` — `const CONTACT_LEVEL_KONTOR := 2`
- `autoload/market_pricer.gd:41` `2` — `const MIN_BREAKPOINTS := 2 ## EX-03: curve needs ≥2 breakpoints`
- `autoload/population_model.gd:43` `2` — `const WORKSHOP_TIER_CITIZEN := 2`
- `autoload/population_model.gd:44` `3` — `const WORKSHOP_TIER_RICH := 3`
- `autoload/port_registry.gd:24` `2` — `TRANSIT = 2,`
- `autoload/port_registry.gd:25` `3` — `TERMINAL = 3,`
- `autoload/ship_registry.gd:74` `2` — `const DRAFT_DEEP := 2`
- `core/types/slot.gd:16` `-1` — `var vacancy_start_day: int = -1`

### EX-06（共 1）

- `autoload/population_model.gd:36` `1000` — `const ACADEMY_MULT_UNIT := 1000`

## 缺口（B-4／C-05）

1. 是否將「inline `-1` 空缺哨兵」追認為 EX-02 擴充，或強制一律具名 const？
2. `args[2]` 這類 >1 索引是否另開結構例外？
3. 進度格式化的 1000／3600／60／100.0 是否併入 EX-04 延伸？
4. `TRAPEZOID_DENOM`／`INT_DIV_MID_DENOM` 算術 2：維持不核准或個別登記？

本報告路徑：`docs/audit/c03_magic_numbers.md`
