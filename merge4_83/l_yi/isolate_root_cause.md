# Isolate 根因（D-133／L-乙）

## 完整 diff
見同目錄 `isolate_wp67.diff`（commit `4d0fc3c`，僅 `tests/unit/test_wp67_garrison_obs05.gd` +19 行）。

## 失敗現象（tip `615d410` run 45633284310 gut-unit (2)）
- Gate：`SCRIPT ERROR detected in GUT unit/property log`
- `test_WP67_garrison_goods_fail_restores_cash_and_stock` → `MarketPricer.quote`
- 呼叫鏈：`quote` → `DemandModel.weekly_potential_demand` → `weekly_demand` → `_w_num`/`_has_neg_pop` → `PopulationModel.population` **before load**

## 根因
1. **新增** `tests/unit/test_d123_opening_board_1766.gd`（~15KB）改變 CI **size-balanced 4-way** 分片結果（D-132 分片規則未改；只是檔案集合變了 → 同規則下 WP67 換了 shard mates）。
2. 同 shard 先前測試留下 **`DemandModel._loaded=true`**，且 **未保有** `PopulationModel` load。
3. D-123 `after_each` 只做 `DemandModel.set_potential_demand_provider(null)`：清掉 `PotentialDemandAll` 後，後續 WP67 的 `MarketPricer.quote` 走 **null provider → 真實 DemandModel 路徑**，因而撞上未 load 的 PopulationModel → SCRIPT ERROR。
4. 未改：skip 測試、改 shard 序、加長 timeout（違禁）。

## 修補方向（已合 tip `4d0fc3c`）
與 WP56／R972（D-128）相同：**offtake-only** — `_boot_world` 注入 `_ZeroPotentialDemand`（`weekly_potential_demand`→0），`before_each`/`after_each` clear providers。不碰 D-132 分片。
