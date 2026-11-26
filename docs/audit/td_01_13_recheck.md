# N5 TD-01 至 TD-13 逐項回核（17-76）

- **Pack:** 17-76 / lane=AUDIT
- **Repo tip:** `e2a99d26df99d640977f4699073bbc85dc48f82f`
- **Source of TD text:** `docs/spec/05_TechSpec.csv` rows 955–967（TD-01…TD-13）
- **Method:** 對照原文描述 → 在現 `main` 產品碼搜尋／讀上下文 → 必要時 `git log -S`／合併提交佐證。**未改碼；不動手修 TD。**

## 總表

| TD | 原描述（縮） | 現況 | 證據（commit／位置） | 結論 |
|---|---|---|---|---|
| TD-01 | 跨模組私有存取；餘項＝`PopulationModel` 讀 `BuildingEconomy._building_defs` | 產品碼 `autoload/`/`core/`/`sim/` **無** `BuildingEconomy._building_defs`；`population_model.gd` 無該讀取。測試仍有白盒觸碰（例 `tests/unit/test_population_model_wp21.gd`） | `git log -S'_building_defs' -- autoload/population_model.gd` → `de59138`（WP-52 A2–A5／D-86 public accessors） | **已消解**（就規格列仍有效的產品碼餘項）；測試白盒非本列 D-128 產品餘項 |
| TD-02 | BE 兩條採購：先扣現金再搬貨，失敗不退款 | **一條已改、一條仍在**：`_try_garrison_buy` 有 `can_transfer` 預檢＋失敗沖銷 post；`_acquire_materials_into` 市場購料仍 `CashLedger.post`→`GoodsLedger.transfer` 且無預檢／無沖銷 | `building_economy.gd:2517–2558`（已改）；`building_economy.gd:1372–1388`（仍在） | **仍存在**（部分緩解） |
| TD-03 | DemandModel 缺貨需求率／權重時 `.get(...,0)` 静默 | 仍 `by_good.get(String(good_id), 0)` 於 rate／sat | `core/demand_model.gd:254`、`:262`、`:590–592` | **仍存在** |
| TD-04 | `csv_import` 舊路徑 `int(row[...])` | 多處仍在（zones／buildings／opening／population 等） | `tools/csv_import.gd:742–745`、`:804–805`、`:869`、`:1116–1147` 等 | **仍存在** |
| TD-05 | (a) ZONE 陣列過短静默不開區；(b) 舊測名無 TST ID | (a) `_step_zone_streak`／`_season_zone_open` 在 `idx>=size` 時 `continue`/`return` **不報錯**；(b) 規格已裁決不追溯 | `building_economy.gd:2605–2607`、`:2906–2907`；TechSpec TD-05 D 欄「(b) 已裁決不追溯」 | (a) **仍存在**；(b) **描述已不適用（需重寫／維持已裁決）** |
| TD-06 | `SimJsonInt.as_int` 非整數 `push_error` 後回 `0` | 行為原文仍在 | `sim/json_int.gd:16–24`（註解亦自承 C-06） | **仍存在** |
| TD-07 | `ship_registry` 讀 `GoodsLedger._container_meta`；冗餘 `int(` | 產品碼改走公開 `GoodsLedger.get_container_port_id`；註解明示 never `_container_meta` | `ship_registry.gd:490–506`；`git log -S'_container_meta' -- autoload/ship_registry.gd` → `de59138`／`687a0a4` | **已消解**（就 `_container_meta` 跨模組讀取）；冗餘 `int(` 未逐一清冊 → 若仍要追 `int(` 冗餘請另開缺口 |
| TD-08 | `sim_engine` 寫 `TradeDesk._loaded` | 改呼叫公開 `TradeDesk.mark_unloaded()` | `sim/sim_engine.gd:164–167`；`trade_desk.gd:74–76`；`de59138` | **已消解** |
| TD-09 | `population_model` 讀 `_building_defs`；字面量 `1000000`／`1.0e-9` | 私有讀取已無；`1000000` 已無；`1.0e-9` 收成具名 EX-02 const | `population_model.gd:37–39`；無 `BuildingEconomy._`；`de59138` | **已消解**（字面量改具名哨兵；跨模組讀取消失） |
| TD-10 | 存檔占用重建不實作等觀察 | Phase 0 仍無存檔重建實作（與原文「維持不實作」一致） | 規格 D 欄「部分押後」；碼側無 save/load rebuild 入口可證 | **描述已不適用／押後**（非缺陷未修，屬已接受範圍外） |
| TD-11 | BE 讀 `CashLedger._postings`；`sim_engine` 叫 `SimScenarioValidator._as_int` | 無 `_postings`／`_as_int` 跨模組命中；改 `SimScenarioValidator.as_int`／`SimJsonInt.as_int` | `rg` 無命中；`sim_engine.gd:231` `SimScenarioValidator.as_int`；`de59138` | **已消解** |
| TD-12 | `data/import` 空；`opening_public` 多 PT-07 | `data/import` **仍僅 `.gitkeep`**；`data/opening_public` 含 PT-01…16（含 PT-07），且 `docs/spec/opening_public.csv` 亦有 PT-07 → 「多出 PT-07」已與規格對齊。資料主體在 `data/ports` 等子樹，非 `import/` | `data/import/.gitkeep`；`docs/spec/opening_public.csv:58–59`；`7c3e46f` WP-52 A1 reimport | **仍存在**（`import/` 空殼）；PT-07 多餘說 **已不適用** |
| TD-13 | 取整未統一（`int`／float 厘） | 仍見 `int(ceili(float…))`、`float` 金額徑 | `building_economy.gd:2644`、`:2662`、`:2717` 等；WP-52 有 A3 提交 `de59138` 但未清光 | **仍存在**（部分收斂） |

## 逐項證據摘要

### TD-01 — 已消解（產品餘項）
- 原文餘項：PopulationModel→`BuildingEconomy._building_defs` 三處。
- 現況：`rg 'BuildingEconomy\._building_defs' autoload core sim` → 空。
- Commit：`de59138` WP-52 A2–A5／D-86。

### TD-02 — 仍存在
- 已緩解：`_try_garrison_buy`（`can_transfer` + 失敗沖銷，`building_economy.gd:2517–2558`）。
- 未修：`_acquire_materials_into` 市場購料（`:1372–1388`）無預檢／無沖銷。

### TD-03 — 仍存在
- `DemandModel.rate`／sat 路徑 `.get(..., 0)`（`demand_model.gd:254`、`:262`）。

### TD-04 — 仍存在
- `tools/csv_import.gd` 多處 `int(row[...])`（例 `:742–745`）。

### TD-05 — (a) 仍存在；(b) 已裁決
- (a) 短陣列静默：`building_economy.gd:2605–2607`、`:2906–2907`。
- (b) TechSpec：「不改舊測試名，不追溯」。

### TD-06 — 仍存在
```text
sim/json_int.gd:16-24
push_error(...); return 0
```

### TD-07 — 已消解（私有 meta）
- `ship_registry.gd:490` 註解 + `GoodsLedger.get_container_port_id`。

### TD-08 — 已消解
- `TradeDesk.mark_unloaded()`（`trade_desk.gd:74`）；`sim_engine.gd:167` 呼叫。

### TD-09 — 已消解
- 無 `BuildingEconomy._*`；`RING_WEIGHT_FLOOR`／`U_UNIT_FLOOR` 具名。

### TD-10 — 描述已不適用（押後）
- 存檔重建維持不實作＝現行 Phase 0 範圍。

### TD-11 — 已消解
- 無 `CashLedger._postings`；公開 `as_int`。

### TD-12 — 部分仍存在
- `data/import` 仍空；PT-07 已與規格同步 → 原「多出」不再成立。

### TD-13 — 仍存在
- 仍有 float／`int(ceili(...))` 厘徑（例 `:2644`）。

## 缺口（B-4，只列）
1. TD-02 是否只認 garrison 為「兩條」之一、購料路徑是否仍算同一 TD？
2. TD-12 `data/import` 空殼是否改指向「正式資料在 data/<domain>/」並重寫描述？
3. TD-05 是否拆號（規格已警告重複）？
4. TD-07 若仍要追「冗餘 int(」需另列清單。

本報告：`docs/audit/td_01_13_recheck.md`
