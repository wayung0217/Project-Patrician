# 17-71 HANDOFF

Branch tip: `2c1c2c08ae12983593c93d8ea93e9dce6b2a35b7`（`review/1771-handoff`）  
Main tip at closeout: `fd5eb16c8d598b7a82f31097c9fb2207c0e4ebcd`  
Main CI: `45735400939` success (9 checks).  
Golden artifact id: **`15078752004`**（name `golden-30d`，run `45735400939`）.

## GUT at main `fd5eb16`
From CI `45735400939` gut-unit-gate:
```
TOTAL_PASSING=611
BASELINE_COUNT=555
SEEN_NAMES=611 BASELINE_NAMES=555
REMOVED_NAMES:
無
```
Shard Passing: 0→2, 1→208, 2→190, 3→211（合計 611）.  
gut-ui: Passing Tests 6.

## Open PRs
**1 個（#88 TD-18，依 Owner 指示暫不合併）**。  
另：#78 `cursor/ui-1755-debug-panels-ff98` 為搁置 UI 枝（見下方 disposition；不計入 17-71 收尾「應為 0」目標，Owner 明示保留）。

## Merges closed
| Step | Result |
|------|--------|
| W1 #87→main | `7be70ce` · CI `45642156227` |
| ④ #83→int | merge `196c9e6` · int tip `adb30f9` · CI `45649446070` |
| W3 #86→main | merge `3fb252a` · kick tip `989db8f` · CI `45652584571` |
| ⑥ int→main | merge `fd5eb16` · CI `45735400939` · golden DIFF_CELLS=0 |

## Golden (⑥)
```
GOLDEN_BOOTSTRAP=0
COMPARED_CELLS=10013  # 527×19
DIFF_CELLS=0
IDENTICAL=1
GOLDEN_GATE PASS
GOLDEN_SUMMARY rows=527 cols=19
```
本項為本機比對，非 CI 實證（D-121(f)）。  
已知缺口：CI 在 main **push** 後不會自動比對連續兩次 golden baseline（compare 步驟僅 `pull_request`）→ ⑥ 類合併的 DIFF 無 CI 自動實證，屬結構缺口。

## z-1758-3
z-1758-3 尚未跑。

## C-14 / D-45b
- Owner: C-14 = docs/spec workbook CSV exports only；scenario JSON 屬 AI_README §9 範圍。
- D-45b PASS: ac44031 僅新增 TOP_N；5fc9853 新增 TOP_N + 結構性自 overrides 移除 ABUND→grid。
- Pack: `evening-17-69-lane3/merge6_gate/`

## #86 / run_m1b_report.gd — ⑥ conflict resolve
**Rule:** L5 (#86/main) base + transplant L4 (int) `duration_s` + per-season sails/cargo.

### #86 (L5) brought
- SEED_NO_EFFECT check (§ + helpers)
- §⑥ `season_sail_count` / `season_cargo_dan` column-presence
- §⑦ `trader_sails_total` / `trader_cargo_dan_total`
- `_cargo_dan_sum` / column helpers

### L4 transplant kept
- §⑤ keeps `duration_s`; adds `cargo_dan_sum` column
- New §⑤b: `sail_sum` / `cargo_dan_sum` / `season_sails` (from `season_index`)
- Trader parse aggregates `season_sails` + sets `cargo_dan_sum`

### Impact on m1b report columns/format (next calibration)
- Table ⑤ gains `cargo_dan_sum` beside `sail_sum` / `duration_s`
- New table ⑤b exposes per-season sail map (`season:count,…`)
- L5 SEED_NO_EFFECT and season_* column probes remain — readers must not treat N/A as FAIL
- Evidence: `merge6_gate/RUN_M1B_RESOLVE.md`, `run_m1b_POST_RESOLVE.diff`, `run_m1b_RESOLVED.txt`

## ABUND_BONUS_MAX_PPM (Owner record)
**(a)** Authorized by **R9-71 中-4 / F5** (TechSpec + `dispatch-17-58.md`): remove from G0/G1/G2/G0H overrides; keep in grid (0 & 250000). Commit `5fc9853`: 「F5 ABUND_BONUS only in M1b grid」.

**(b)** Override `0` was an **Owner-approved trial** under **D-108(c)** (pause abundance accel on M1b), not a boot-validation placeholder; grid still runs 0 and 250000.

本項與 D-108(c)（M1b 期間 ABUND_BONUS_MAX_PPM 固定為 0）可能抵觸，Owner 裁決中（D-136），grid 是否保留 250000 待定。

## Tech debt TD-01..TD-17（自 docs/spec/05_TechSpec.csv D 列／審計；不臆造）
來源：工作簿對應之 TechSpec CSV（D-32b、D-39c、D-40d、D-43b、D-60e、D-60g、D-63d、D-69、D-75、D-76、D-80、D-82、D-84、D-91 等）。R9-78：截至本寫入時 `docs/spec`／store **未見** R9-78 列。

| ID | 摘要（照 TechSpec） | 狀態摘記 |
|----|---------------------|----------|
| TD-01 | 測試重置／公開查詢介面；PopulationModel 讀 BuildingEconomy._building_defs | D-32b；日後小 WP |
| TD-02 | BuildingEconomy 扣款後搬貨失敗不退款 | D-39c；日後小 WP |
| TD-03 | DemandModel 不檢查每貨皆有需求率與權重 | D-40d |
| TD-04 | csv_import 舊路徑殘留 int(row[…]) | D-43b |
| TD-05 | 測試名無 TST ID（後更新 255／427） | D-60e；舊測不追溯 |
| TD-06 | sim/ 非整數 JSON push_error 後回 0 | D-60g |
| TD-07 | 冗餘 int( 與產品碼跨模組私有存取 | D-63d |
| TD-08 | sim_engine 寫入 TradeDesk._loaded | D-69 |
| TD-09 | population_model 既有跨模組私有讀取與字面量 | D-75 |
| TD-10 | #43 合併報告既有項與占用重建缺口 | D-76 |
| TD-11 | building_economy 讀 CashLedger._postings；sim_engine 呼叫 _as_int | D-80；WP-52 |
| TD-12 | data/ 與 docs/spec 不同步 | D-80；WP-52 |
| TD-13 | building_economy floor/ceil 未用 floori/ceili | D-80；WP-52 |
| TD-14 | 測試大量碰私有；**不允許**測試專用重置介面 | D-80／D-91；改正式注入 |
| TD-15 | params_schema 有鍵代碼未讀（工作簿側驗證） | D-80／D-91；代碼不重複檢查（**非** wp26 拆檔；wp26＝**TD-18**） |
| TD-16 | 升級期間維持原等級效果 | D-82／D-84(b) 已裁決 |
| TD-17 | GoodsLedger 查詢時登記容器 | D-82；併 TD-02 小 WP |

### R9-75 未結／交接相關（開項）
- N-10～N-14：收尾過程已處理（D-128／D-129 甲、COMPARED_CELLS、#86 入序、W9 三枝為 stale false positive）；細節見 R9-75 原文。
- **仍開：** D-127 量級對帳缺 `season_cells.csv`；R9-75 §8.2 其餘項（驗收門改寫）交下一模型；z-1758-3 尚未跑。
- **R9-78：** `docs/spec`／store **未見** R9-78 列（不臆造）。
- Golden push 無連續 baseline 自動比對（本 HANDOFF 結構缺口）。

## W5 / branch disposition

### Deleted (named list + 0-ahead extras)
- `int-1758`；#83–#87 heads；其後刪 `diag-z-1758`、`housing-1758`、`tools-1758`、`cursor/lane-a-wp36-traders-26f5`（皆 0 ahead of main）。
- `int-1755-merge-0a6e`／`int-1756-295f`／`int-1757-5ae9`（含 `cursor/` 前綴）：遠端本無；先前 `git branch -r --no-merged` 為 **stale local tracking false positive**；`git fetch --prune` 後確認遠端從未（再）持有。

### Keep
- 全部 `review/*`
- **`cursor/ui-1755-debug-panels-ff98`**（5 commits ahead；PR **#78**）：D-115(e)／Step U traders panel + port zone fields；R9-71「待 A」搁置，Owner 明示保留，不刪。

### `git ls-remote --heads origin`（刪除 0-ahead extras 後；全文）
```
0bcb548aaf78c5865ef784d421b581bc4fe5b523	refs/heads/review/1770-evidence3
173d731beb2fbc1bdfca521abe8507bcad10297e	refs/heads/review/evening-17-69-lane3
1927947fb1119c9713278cae275f736b8774ce95	refs/heads/review/1771-handoff
1fd181acf5012a49494b3084e4045202987e4507	refs/heads/cursor/ui-1755-debug-panels-ff98
32f0a43c2d8c680178d610f907a8869d73f69598	refs/heads/review/1770-d130
40670fc03681a1b8eabee618eebf4401c7d5fdac	refs/heads/review/1770-t3
69a793a473bb8eb8c0696eb7a5944d34eb726228	refs/heads/review/1770-t1
76bacbf848a7dc7d6220fa5f1818130254ec3c71	refs/heads/review/1770-merge1
7d8ece439134c109e5f8a112771f3c32029a91e4	refs/heads/review/evening-17-69-int
8468b864149604e8e6b2cb8acf060ced8b559e4e	refs/heads/review/evening-17-69-lane5
85627c4576e1b96ba112187cb36eb57d2d8aa7d9	refs/heads/review/evening-17-57
88da300c61dcf2c340e3bdd705b14307068b4af5	refs/heads/review/1770-t2
88fdddb3ed46c0b1ceb2fe73095447abd58c70e8	refs/heads/review/evening-17-69-lane2
add25848677bf95be8e430ff9f6a8c1bcab977f9	refs/heads/review/evening-17-55
c1fd855611cad108c5c03604f4e47b1e63c95dda	refs/heads/review/evening-17-69-lane1
d52d92ac1909ae995b429e65e814774da83a1ab2	refs/heads/review/1770-evidence2
d789f0410feee33d1cd65c3ecd5df2cc919e8fa5	refs/heads/review/evening-17-69-lane4
d834963e3903bad8461fa2ff74e2445d26bac515	refs/heads/review/evening-17-69-handoff
dc6aa1c30f7d46cffb9a7986e2da5e3d43602d5b	refs/heads/cursor/td18-wp26-split-5665
fd5eb16c8d598b7a82f31097c9fb2207c0e4ebcd	refs/heads/main
```
（推送本 HANDOFF 修訂後，`review/1771-handoff` tip SHA 將更新；以本檔開頭 Branch tip 為準。）

## TD-18（not TD-15）
PR **#88** `cursor/td18-wp26-split-5665` @ `dc6aa1c` — CI run **`45738371952` success**；L-乙：30 測名 before≡after、REMOVED_NAMES=無、TOTAL_PASSING=611／BASELINE_COUNT=555；wall before slowest 2078s（E3）／main 1302s → after 1733s。**依 Owner 指示暫不合併**。  
Pack: `evening-17-69-lane3/td18_wp26/`

## Pack index
- `evening-17-69-lane3/merge4_83/` — merge④
- `evening-17-69-lane3/merge6_gate/` — ⑥ + golden + W5 + ABUND
- `evening-17-69-lane3/td18_wp26/` — TD-18
- `1771-handoff/` — this HANDOFF
