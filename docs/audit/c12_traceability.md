# N4 C-12 註解追溯覆蓋率（17-76）

- **Pack:** 17-76 / lane=AUDIT
- **Repo tip:** `e2a99d26df99d640977f4699073bbc85dc48f82f`
- **Scope:** `autoload/`、`core/`、`sim/` `.gd`
- **Rule:** C-12 — 公式處註 FRM ID；錯誤分支註 ERR ID；參數讀取註 PRM ID
- **未改碼**

## 分母定義（怎麼數）

| 類 | 分母（站點） | 視為已覆蓋 |
|---|---|---|
| (a) FRM | 每個「公式味」`func`：函式上方 doc／體內前段含 `ceili`/`floori`/`quantize`/`Params.get`／經濟關鍵詞達門檻 | 出現完整 **`FRM-SYS##-##`**（縮寫 `FRM-07`／`FRM-08..11` **不算**） |
| (b) ERR | `push_error(`、`errors.append(`、以及 `_fail`／`_fail_sn`／`_record_fail(` **呼叫**（排除 `func _fail` 定義本體） | 同站點前後 3 行內有 `ERR-SYS##-##` 或 `ERR_*`／`CODE_*` token |
| (c) PRM | 每個 `Params.get_value`／`get_int`／`get_float`／`get_bool`／`get(` 呼叫 | 引數或上下 5 行有 `PRM-SYS…` 字串或 `PRM_*` const |

## 覆蓋率

| 類 | 分子（已覆蓋） | 分母 | 覆蓋率 |
|---|---:|---:|---:|
| (a) FRM | 153 | 219 | **69.9%** |
| (b) ERR | 387 | 548 | **70.6%** |
| (c) PRM | 235 | 235 | **100.0%** |

## (a) FRM 缺漏表（66）

| 檔案:行號 | 類別 | 應標什麼 | 為何判定缺 |
|---|---|---|---|
| `autoload/building_economy.gd:381` | 公式函式 `land_price` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:647` | 公式函式 `public_upgrade_fee` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:829` | 公式函式 `_step_produce` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:860` | 公式函式 `_step_wage_accrual` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:884` | 公式函式 `_produce_workshop` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:1023` | 公式函式 `warehouse_capacity` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:1153` | 公式函式 `_validate_order_build` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:1501` | 公式函式 `_scarcity_civil` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:2377` | 公式函式 `_frm18_price` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:2459` | 公式函式 `_step_garrison_procure` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:2567` | 公式函式 `_step_rent_accrual` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:2594` | 公式函式 `_step_zone_streak` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:2629` | 公式函式 `_season_wages` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:2652` | 公式函式 `_season_rents` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:2679` | 公式函式 `_season_land_and_vacancy` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:2725` | 公式函式 `_land_rent_li` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/building_economy.gd:3071` | 公式函式 `_season_levy` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/building_economy.gd:3152` | 公式函式 `_current_season_index` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/cash_ledger.gd:833` | 公式函式 `quantize_money` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/cash_ledger.gd:920` | 公式函式 `_mul_checked` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/clock.gd:59` | 公式函式 `load_and_validate` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/intel_ledger.gd:121` | 公式函式 `load_and_validate` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/intel_ledger.gd:633` | 公式函式 `_summarize_board` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/intel_ledger.gd:824` | 公式函式 `_mul_checked` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/params.gd:128` | 公式函式 `get_bool` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/params.gd:364` | 公式函式 `_parse_build_mat_object` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/params.gd:427` | 公式函式 `_parse_upgrade_per_capita_array` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/params.gd:494` | 公式函式 `_parse_kontor_upgrade_array` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:434` | 公式函式 `set_residence_occupants` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:449` | 公式函式 `housing_capacity` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:457` | 公式函式 `job_capacity` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:501` | 公式函式 `weighted_avg_sat` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:629` | 公式函式 `_target_sat` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:927` | 公式函式 `_class_basket_ppm` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:973` | 公式函式 `_season_of_day` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:1019` | 公式函式 `_apply_lost_workshop_workers` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/population_model.gd:1033` | 公式函式 `_apply_job_cap_overflow` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-##（附近有縮寫 FRM-* 但仍非 FRM-SYS##-##） |
| `autoload/population_model.gd:1127` | 公式函式 `_sync_port_residences` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:1277` | 公式函式 `_draw_u` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:1287` | 公式函式 `_place_one_in` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/population_model.gd:1377` | 公式函式 `_validate_params` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/port_registry.gd:227` | 公式函式 `queue_role_change` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/sim_loop.gd:233` | 公式函式 `tick_day` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/trader_registry.gd:225` | 公式函式 `load_and_validate` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/trader_registry.gd:557` | 公式函式 `_largest_remainder_ports` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/trader_registry.gd:591` | 公式函式 `_build_voyage_matrix` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `autoload/trader_registry.gd:953` | 公式函式 `_estimate_sell_revenue` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/demand_model.gd:249` | 公式函式 `rate_scaled` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/demand_model.gd:257` | 公式函式 `sat_weight_pct` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/demand_model.gd:383` | 公式函式 `_load_tables` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/demand_model.gd:535` | 公式函式 `_parse_subst_from_tres` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/demand_model.gd:783` | 公式函式 `_to_int` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/rng.gd:89` | 公式函式 `_mul_u64` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/trade_evaluator.gd:101` | 公式函式 `coarse_score` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `core/types/price_curve.gd:11` | 公式函式 `point_count` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/metrics.gd:13` | 公式函式 `compute` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/metrics.gd:210` | 公式函式 `_met01` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/metrics.gd:229` | 公式函式 `_met02` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/metrics.gd:519` | 公式函式 `_obs04_rows` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/relocator.gd:270` | 公式函式 `_mul_ok` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/sampler.gd:109` | 公式函式 `_sample_port_row` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/sampler.gd:282` | 公式函式 `_cell_row` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/scenario_validator.gd:321` | 公式函式 `_list_port_ids` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/sim_engine.gd:399` | 公式函式 `_emit_season_progress` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/sim_runner.gd:273` | 公式函式 `_run_job_file` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |
| `sim/sim_runner.gd:389` | 公式函式 `_copy_outputs` | `FRM-SYS…` 完整 ID | 公式味函式未見完整 FRM-SYS##-## |

## (b) ERR 缺漏表（161）

| 檔案:行號 | 類別 | 應標什麼 | 為何判定缺 | 原文片段 |
|---|---|---|---|---|
| `autoload/building_economy.gd:183` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("BuildingEconomy.set_population_provider called after load (D-11d); ignored")` |
| `autoload/building_economy.gd:194` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("BuildingEconomy.set_workforce_provider called after load (D-12c); ignored")` |
| `autoload/building_economy.gd:355` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(oe)` |
| `autoload/building_economy.gd:472` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("BuildingEconomy: %s" % str(e))` |
| `autoload/building_economy.gd:970` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(GoodsLedger.last_error())` |
| `autoload/building_economy.gd:984` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(GoodsLedger.last_error())` |
| `autoload/building_economy.gd:3394` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("BuildingEconomy: %s" % str(_last_error))` |
| `autoload/building_economy.gd:3403` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("BuildingEconomy: %s" % str(e))` |
| `autoload/cash_ledger.gd:1013` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("CashLedger: %s" % str(info))` |
| `autoload/cash_ledger.gd:1023` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("CashLedger: %s" % str(e))` |
| `autoload/clock.gd:67` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append({` |
| `autoload/clock.gd:77` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append({` |
| `autoload/clock.gd:85` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append({` |
| `autoload/clock.gd:98` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append({` |
| `autoload/clock.gd:108` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append({` |
| `autoload/clock.gd:135` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("Clock.advance_one_tick called while is_paused=true (GP-01)")` |
| `autoload/clock.gd:138` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("Clock.advance_one_tick called before load_and_validate")` |
| `autoload/clock.gd:146` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("Clock.advance_one_day called while is_paused=true (GP-01)")` |
| `autoload/clock.gd:149` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("Clock.advance_one_day called before load_and_validate")` |
| `autoload/clock.gd:158` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("Clock: %s" % str(e))` |
| `autoload/good_catalog.gd:278` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("GoodCatalog: %s" % str(info))` |
| `autoload/good_catalog.gd:288` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("GoodCatalog: %s" % str(e))` |
| `autoload/goods_ledger.gd:1160` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("GoodsLedger: %s" % str(info))` |
| `autoload/goods_ledger.gd:1170` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("GoodsLedger: %s" % str(e))` |
| `autoload/intel_ledger.gd:493` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("IntelLedger: %s" % str(_last_error))` |
| `autoload/intel_ledger.gd:502` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("IntelLedger: %s" % str(e))` |
| `autoload/intel_ledger.gd:514` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("IntelLedger: %s" % str(info))` |
| `autoload/market_pricer.gd:545` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("MarketPricer: %s" % str(info))` |
| `autoload/market_pricer.gd:555` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("MarketPricer: %s" % str(e))` |
| `autoload/params.gd:55` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("SCHEMA_TYPE", SCHEMA_PATH, "", schema_raw, "schema root must be Dictionary"))` |
| `autoload/params.gd:65` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("PARAMS_TYPE", params_path, "", params_raw, "params root must be Dictionary"))` |
| `autoload/params.gd:76` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "schema rule must be Dictionary"))` |
| `autoload/params.gd:80` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("MISSING_KEY", params_path, key, null, "required PRM key missing"))` |
| `autoload/params.gd:85` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("EMPTY_VALUE", params_path, key, value, "required PRM value empty"))` |
| `autoload/params.gd:97` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("UNKNOWN_KEY", params_path, key, params[key], "key not in TechSpec §4 / WP-16 params.json schema"))` |
| `autoload/params.gd:156` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("FILE_MISSING", path, "", null, "file not found"))` |
| `autoload/params.gd:160` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("FILE_OPEN", path, "", FileAccess.get_open_error(), "cannot open file"))` |
| `autoload/params.gd:165` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("JSON_PARSE", path, "", null, "JSON.parse_string failed"))` |
| `autoload/params.gd:202` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("SCHEMA_TYPE", SCHEMA_PATH, key, type_name, "unknown schema type"))` |
| `autoload/params.gd:208` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected int (JSON whole number)"))` |
| `autoload/params.gd:212` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, key, as_int, "int out of TechSpec range"))` |
| `autoload/params.gd:219` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected float/定點數"))` |
| `autoload/params.gd:223` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, key, as_float, "float out of TechSpec range"))` |
| `autoload/params.gd:230` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected {debug:bool, release:bool}"))` |
| `autoload/params.gd:234` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "missing debug/release"))` |
| `autoload/params.gd:237` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "debug/release must be bool"))` |
| `autoload/params.gd:247` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected int enum"))` |
| `autoload/params.gd:251` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "int_enum requires values array"))` |
| `autoload/params.gd:260` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("ENUM", file_path, key, as_int, "int not in allowed enum set"))` |
| `autoload/params.gd:267` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected int array"))` |
| `autoload/params.gd:271` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))` |
| `autoload/params.gd:279` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, field, elem, "expected int element"))` |
| `autoload/params.gd:284` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, field, as_int, "int element out of range"))` |
| `autoload/params.gd:295` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected float array"))` |
| `autoload/params.gd:299` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))` |
| `autoload/params.gd:307` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, field, elem, "expected float element"))` |
| `autoload/params.gd:312` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, field, as_float, "float element out of range"))` |
| `autoload/params.gd:323` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected int object"))` |
| `autoload/params.gd:326` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "int_object requires keys array"))` |
| `autoload/params.gd:335` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [key, req], null, "object missing required key"))` |
| `autoload/params.gd:340` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("UNKNOWN_KEY", file_path, "%s.%s" % [key, obj_key], obj[obj_key], "object has extra key"))` |
| `autoload/params.gd:350` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, field, elem, "expected int value"))` |
| `autoload/params.gd:355` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, field, as_int, "int value out of range"))` |
| `autoload/params.gd:367` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected build_mat object"))` |
| `autoload/params.gd:370` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "build_mat_object requires keys array"))` |
| `autoload/params.gd:379` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [key, req], null, "object missing required key"))` |
| `autoload/params.gd:384` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("UNKNOWN_KEY", file_path, "%s.%s" % [key, obj_key], obj[obj_key], "object has extra key"))` |
| `autoload/params.gd:394` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, field, nested_raw, "expected {good_id: int}"))` |
| `autoload/params.gd:404` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, gfield, gid, "good_id format mismatch"))` |
| `autoload/params.gd:409` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, gfield, qty, "expected int 擔數"))` |
| `autoload/params.gd:414` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, gfield, as_int, "擔數 out of range"))` |
| `autoload/params.gd:430` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected upgrade_per_capita array"))` |
| `autoload/params.gd:434` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))` |
| `autoload/params.gd:444` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, field, elem, "expected object element"))` |
| `autoload/params.gd:449` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [field, cash_key], null, "missing CASH_LI"))` |
| `autoload/params.gd:454` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, "%s.%s" % [field, cash_key], cash_raw, "expected int CASH_LI"))` |
| `autoload/params.gd:459` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, "%s.%s" % [field, cash_key], cash_int, "CASH_LI out of range"))` |
| `autoload/params.gd:471` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, gfield, k, "good_id format mismatch"))` |
| `autoload/params.gd:476` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, gfield, qty, "expected float/定點數"))` |
| `autoload/params.gd:481` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, gfield, as_float, "qty out of range"))` |
| `autoload/params.gd:497` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, key, value, "expected kontor_upgrade array"))` |
| `autoload/params.gd:501` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))` |
| `autoload/params.gd:513` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, field, elem, "expected object element"))` |
| `autoload/params.gd:518` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [field, cash_key], null, "missing CASH_LI"))` |
| `autoload/params.gd:522` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [field, days_key], null, "missing DAYS"))` |
| `autoload/params.gd:528` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, field, elem, "CASH_LI／DAYS must be int"))` |
| `autoload/params.gd:534` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, field, elem, "CASH_LI／DAYS out of range"))` |
| `autoload/params.gd:547` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, gfield, k, "good_id format mismatch"))` |
| `autoload/params.gd:552` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("TYPE", file_path, gfield, qty, "expected int 擔數"))` |
| `autoload/params.gd:557` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err("RANGE", file_path, gfield, as_int, "擔數 out of range"))` |
| `autoload/params.gd:626` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("Params: %s" % str(e))` |
| `autoload/population_model.gd:165` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("PopulationModel.set_satisfaction_input_provider after load (D-17c); ignored")` |
| `autoload/population_model.gd:1483` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("PopulationModel: %s" % str(_last_error))` |
| `autoload/population_model.gd:1492` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("PopulationModel: %s" % str(e))` |
| `autoload/port_registry.gd:752` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("PortRegistry: %s" % str(e))` |
| `autoload/sea_lanes.gd:664` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SeaLanes: %s" % str(_last_error))` |
| `autoload/sea_lanes.gd:679` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SeaLanes: %s" % str(err_variant))` |
| `autoload/ship_registry.gd:103` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("ShipRegistry.set_sailor_pool_provider called after load; ignored")` |
| `autoload/ship_registry.gd:851` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("ShipRegistry: %s" % str(_last_error))` |
| `autoload/ship_registry.gd:860` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("ShipRegistry: %s" % str(e))` |
| `autoload/sim_loop.gd:47` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimLoop.set_consumption_provider called after boot (D-08j); ignored")` |
| `autoload/sim_loop.gd:69` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimLoop: %s" % str(dup))` |
| `autoload/sim_loop.gd:170` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(missing)` |
| `autoload/sim_loop.gd:212` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(grant_err)` |
| `autoload/sim_loop.gd:213` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimLoop: genesis_grant failed: %s" % str(grant_err))` |
| `autoload/sim_loop.gd:239` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimLoop.tick_day called before successful boot (2.2-02)")` |
| `autoload/sim_loop.gd:242` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimLoop.tick_day called while Clock.is_paused=true (GP-01)")` |
| `autoload/sim_loop.gd:401` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `autoload/trade_desk.gd:86` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk.set_qualification_provider called after load; ignored")` |
| `autoload/trade_desk.gd:98` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk.set_trade_observers called after load; ignored")` |
| `autoload/trade_desk.gd:203` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk: %s" % str(_last_error))` |
| `autoload/trade_desk.gd:216` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk: %s" % str(_last_error))` |
| `autoload/trade_desk.gd:239` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk: %s" % str(_last_error))` |
| `autoload/trade_desk.gd:288` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk: can_transfer failed: %s" % str(_last_error))` |
| `autoload/trade_desk.gd:313` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk: transfer failed after post; cash rolled back: %s" % str(_last_error))` |
| `autoload/trade_desk.gd:429` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TradeDesk: %s" % str(_last_error))` |
| `autoload/trader_registry.gd:327` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TraderRegistry: genesis post failed %s" % str(_last_error))` |
| `autoload/trader_registry.gd:448` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(CashLedger.last_error())` |
| `autoload/trader_registry.gd:1099` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TraderRegistry: %s" % str(_last_error))` |
| `autoload/trader_registry.gd:1108` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("TraderRegistry: %s" % str(e))` |
| `core/demand_model.gd:427` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err(err_code, dir_path, null, "subdir missing (D-40c)"))` |
| `core/demand_model.gd:431` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(_err(err_code, dir_path, null, "subdir open failed (D-40c)"))` |
| `core/demand_model.gd:447` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append(` |
| `core/demand_model.gd:794` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("DemandModel: %s" % str(_last_error))` |
| `core/demand_model.gd:799` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("DemandModel: %s" % str(e))` |
| `core/interfaces/broker_provider.gd:44` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("BrokerProvider: %s" % str(_last_error))` |
| `core/interfaces/capacity_provider.gd:14` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("CapacityProvider.capacity: base interface called; override required (2.1-03)")` |
| `core/interfaces/consumption_provider.gd:15` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("ConsumptionProvider.consume_qty: base interface called; override required (2.1-03)")` |
| `core/interfaces/population_provider.gd:11` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/qualification_provider.gd:58` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("QualificationProvider: %s" % str(_last_error))` |
| `core/interfaces/sailor_pool_provider.gd:11` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/sailor_pool_provider.gd:19` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/sailor_pool_provider.gd:27` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/satisfaction_input_provider.gd:9` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/ship_event_observer.gd:10` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/ship_event_observer.gd:17` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/trade_observer.gd:28` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `core/interfaces/workforce_provider.gd:11` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/csv_out.gd:283` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimCsvOut: cannot write %s err=%s" % [path, str(FileAccess.get_open_error())])` |
| `sim/grid_expand.gd:32` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimGridExpand: non-integral seed rejected: %s" % str(seed_v))` |
| `sim/json_int.gd:21` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("SimJsonInt: non-integral rejected for %s: %s" % [field, str(v)])` |
| `sim/m1b_diag_z.gd:132` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("m1b_diag_z: cannot write %s" % abs_path)` |
| `sim/params_merge.gd:18` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append("formal params missing: %s" % formal_path)` |
| `sim/params_merge.gd:23` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append("formal params JSON root must be Dictionary")` |
| `sim/params_merge.gd:32` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append("cannot write merged params: %s" % out_user_path)` |
| `sim/sim_engine.gd:97` | errors_append | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `errors.append("SimCsvOut.write_all failed: %s" % str(written.get("failed_paths", [])))` |
| `sim/sim_runner.gd:62` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/sim_runner.gd:69` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/sim_runner.gd:99` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(String(e))` |
| `sim/sim_runner.gd:108` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/sim_runner.gd:136` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("sim_runner: non-integral run_id rejected: %s" % str(job["run_id"]))` |
| `sim/sim_runner.gd:154` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("sim_runner: cannot write job file %s" % job_file)` |
| `sim/sim_runner.gd:196` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/sim_runner.gd:224` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/sim_runner.gd:231` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("sim_runner: job run_id=%s bad result JSON" % str(job["run_id"]))` |
| `sim/sim_runner.gd:263` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("sim_runner: write_all failed paths=%s" % str(written.get("failed_paths", [])))` |
| `sim/sim_runner.gd:268` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("sim_runner: --out-dir copy failed dest=%s" % out_dir)` |
| `sim/sim_runner.gd:279` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/sim_runner.gd:288` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error(` |
| `sim/sim_runner.gd:333` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("sim_runner: cannot write result %s" % result_path)` |
| `sim/sim_runner.gd:378` | push_error | `ERR-SYS…` 或註解 ERR ID | no ERR-SYS*/ERR_*/CODE_* in lines-3..+3 | `push_error("sim_runner: log file missing %s" % log_path)` |

### ERR 缺漏分群

- **`autoload/params.gd`：** 大量 boot 驗證 `push_error`／`errors.append` 用散文訊息、未掛 ERR-SYS 碼。
- **`sim/sim_runner.gd`／`autoload/clock.gd`：** 執行期防護 `push_error`（paused／未 load）無 ERR ID。
- **轉傳 `last_error()`／`errors.append(oe)`：** 依賴上游 ErrorInfo，本行無 ERR token（是否算覆蓋 → **缺口**）。

## (c) PRM 缺漏表

**空表。** `{covered}/{n} = 100%` — 所有 `Params.get*` 呼叫附近皆有 `PRM_*` const 或 `PRM-SYS…`。

## 缺口（B-4）

1. 縮寫 `FRM-07`／`FRM-08..11` 是否接受，或必須寫全 `FRM-SYS08-07`？
2. 轉傳 `last_error()` 的 `errors.append` 是否仍要在呼叫點註 ERR？
3. params boot 散文 `push_error` 要不要補 ERR-SYS 碼（可能需新規 ERR）？

本報告：`docs/audit/c12_traceability.md`
