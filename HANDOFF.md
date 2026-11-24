# 17-71 HANDOFF

Branch tip: `2b6ff456fdb82aecd0cb655661a6cdf9435395fd`（`review/1771-handoff`）  
Main tip at closeout: `fd5eb16c8d598b7a82f31097c9fb2207c0e4ebcd`  
Main CI: `45735400939` success（7 success ＋ 2 skipped；勿報「9／9」成功——N-21）。  
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
CI 沒有「main push 後自動比對前後兩份 golden 基準」的步驟，因此 ⑥ 這類 int→main 的合併無法取得 CI 層級的 golden 比對證據，只能以本機比對替代（本次即是）。這是 CI 結構缺口，留給下一輪評估是否補。

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

## Tech debt TD-01..TD-18（05_TechSpec §18；Owner 原文照錄，不改寫編號／狀態）

TD-01｜測試與產品碼的跨模組私有成員存取；缺統一的公開查詢
      未處理（解法須重訂）。原解法已被 D-91 否決（不允許測試專用重置介面），
      現僅剩「PopulationModel 讀 BuildingEconomy._building_defs 三處改為公開查詢」仍有效。
TD-02｜BuildingEconomy 兩條採購路徑扣款後搬貨失敗不退款
      未處理。日後小 WP；TD-17 併入本項一併處理。
TD-03｜DemandModel 不檢查「每一種貨都有需求率與權重」
      未處理。待 SYS-23 模擬器可跑後，與 TD-01、TD-02 一併處理。
TD-04｜csv_import 舊路徑殘留 int(row[...])
      未處理（WP-52 A2 可能已涵蓋，未逐項回核）。
TD-05｜★ 本號被重複使用，含兩個不同事項
      (a) ZONE 陣列過短時城市永不開區且不報錯 — 未處理；
      (b) 226 個測試名不含 TST ID — 已裁決不追溯（D-60e）。
      ★ 不得重用此號；日後處理 (a) 須另立新號。
TD-06｜sim/ 非整數 JSON 值 push_error 後回 0
      未處理，只記工作簿。
TD-07｜冗餘 int( 與產品碼跨模組私有存取（_container_meta）
      推定由 WP-52 處理（WP-52 至 60 已全部合併入 main）；★ 未逐項回核。
TD-08｜sim_engine.gd 寫入 TradeDesk._loaded（跨模組私有寫入）
      推定由 WP-52 處理；★ 未逐項回核。
TD-09｜population_model.gd 既有的跨模組私有讀取與字面量
      推定由 WP-52 處理；★ 未逐項回核。
TD-10｜#43 合併報告揭露的既有項目與缺口
      部分押後：存檔讀檔後的占用重建維持不實作（存檔不在 Phase 0）。
TD-11｜building_economy.gd 讀 CashLedger._postings；sim_engine.gd 呼叫 SimScenarioValidator._as_int
      推定由 WP-52 A4 處理；★ 未逐項回核。
TD-12｜data/ 與 docs/spec 不同步
      推定由 WP-52 A1 處理；★ 未逐項回核。
TD-13｜取整未統一（含 int／int 經 float 的除法、float 處理厘金額）
      推定由 WP-52 A3 處理；★ 未逐項回核。注意修正後鏡像測試期望值須同步改。
TD-14｜是否允許單一「測試專用重置介面」
      ★ 已結案：D-91 裁決【不允許】。一律改用正式注入介面或既有 fixture。
TD-15｜工作簿側驗證用或補代碼檢查（原始定義）
      未處理（定義待釐清）。完整定義散在 D-80 內，處理前須先回查確認範圍。
      ★ 注意：TD-15 不是 wp26 拆檔，那是 TD-18。
TD-16｜建築升級期間的效果歸零
      ★ 已結案：D-84(b) 裁決升級期間維持原等級效果；規格與代碼皆已處理。
TD-17｜GoodsLedger 容器查詢（get_qty、can_transfer）會順帶登記容器，
      使 is_container_registered 失去「未登記」判斷力；MarketPricer.quote 對不存在的港照樣報價為同一延伸。
      未處理，併入 TD-02。
TD-18｜test_sys23_wp26.gd 單檔約 34 分鐘，為 CI 關鍵路徑
      已派工（17-71），#88 待交付；合併不預批。D-132 已據此修正 D-130(1) 判準。

## R9-75 未結項（照 R9-75 審查紀錄原文；來源：docs/spec/05_TechSpec.csv R9-75 C 欄）

【四、新缺失】N-10 HANDOFF 的 W9 聲明不實；N-11 _clear_state() 跨模組呼叫；N-12 orphan 分支 SHA 漂移（lane5：6dba86b／8468b864／8b7df9a9；int：ae816f2／7d8ece439／8b41864eb）；N-13 黃金比較未輸出 COMPARED_CELLS；N-14 #86 不在合併順序內。

【五、D 系列核對】D-127：量級對帳仍無法進行——無 season_cells.csv；現有僅帶別總計 band0＝385、中段＝126、band4＝3,521、合計 4,032（每組 448 格），商人 sail_count＝0（run 45356709933／71b094d），D-126 之後無新矩陣。

【七、處置】17-69 不通過；四個 PR 一律不合併；z-1758-3 與 M3 不開。

★ Owner 2026-11-25 14:00 覆核摘錄：season_cells.csv 與驗收門改寫（§8.2 其餘項）待 PR 全部合併、repo 乾淨後交下一個編寫程序 AI。

（註：N-10～N-14／D-128／D-129／合併序其後由 17-70／17-71 執行；上列仍照 R9-75 原文登錄為「該筆審查時」未結項。）

## R9-78 未結項
(1) D-128 要求的 tests/ 完整 diff 從未交出，因此「兩處 _clear_state() 已刪」
    與期望值 300／120／0／124 未改，至今只有自述，無逐行證據。
(2) #85（0b0e220）對 origin/int-1758 的三點差異中含 5 個 docs/spec 檔，
    其歸屬經 D-134 判定為情境檔區、非 C-14 違規，但未逐 commit 核對作者。

## N-20 / N-21
N-20｜manifest 曾在最後一次 push 之前產生，三筆 SHA 與實檔不符；
      D-133 硬規則 (a) 已要求往後一律在最後一次 CI 完成之後才產生。
N-21｜CI 結果曾以「9／9」回報，實為 7 success ＋ 2 skipped；往後須區分。

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
1fd181acf5012a49494b3084e4045202987e4507	refs/heads/cursor/ui-1755-debug-panels-ff98
2b6ff456fdb82aecd0cb655661a6cdf9435395fd	refs/heads/review/1771-handoff
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

## TD-18／#88 L-乙（not TD-15；**依 Owner 指示暫不合併**）
PR **#88** `cursor/td18-wp26-split-5665` @ `dc6aa1c`  
CI run **`45738371952`** conclusion **`success`**（7 success ＋ 2 skipped）。

### gate（verbatim）
```
TOTAL_PASSING=611
BASELINE_COUNT=555
SEEN_NAMES=611 BASELINE_NAMES=555
REMOVED_NAMES:
無
```

### test names before ≡ after（30；逐名）
```
test_TST_SYS23_01_two_runs_csv_match_except_elapsed
test_TST_SYS23_02_formal_params_unchanged_sha256
test_TST_SYS23_03_unknown_scenario_key
test_TST_SYS23_04_grid_cartesian_run_id_order
test_TST_SYS23_08_fnv_vectors
test_TST_SYS23_09_one_combo_aborts_on_conservation
test_TST_SYS23_09_print_summary_csv
test_TST_SYS23_10_met_hand_fixture
test_TST_SYS23_11_missing_threshold_pass_na
test_WP26_abort_summary_mets_blank
test_WP26_bad_missing_required_key_errors
test_WP26_bad_override_grid_clash_errors
test_WP26_csv_integer_columns_no_dot
test_WP26_empty_sample_mets_blank_not_zero
test_WP26_evidence_accounts_after_boot_layer1
test_WP26_evidence_bad_triple_all_at_once
test_WP26_evidence_cli_twice_cmp
test_WP26_evidence_ERR_SYS23_01_missing_file
test_WP26_evidence_ERR_SYS23_03_type
test_WP26_evidence_ERR_SYS23_05_unknown_port
test_WP26_evidence_ERR_SYS23_06_relocate_f
test_WP26_evidence_years10_player_arrears
test_WP26_json_int_rejects_non_integral
test_WP26_layer1_two_years_headers_and_counts
test_WP26_obs03_blank_not_zero
test_WP58_A32_bad_job_json_exits_nonzero
test_WP58_A32_missing_job_exits_nonzero
test_WP58_A33_sampler_uses_market_pricer_stock_weeks
test_WP58_A34_write_failure_reports_ok_false
test_WP58_Y1_A31_day_error_aborts_summary
```

### shard wall-clock
- Before（Owner／E3 tip `80d3d68` run `45620046075`）：slowest **gut-unit (3) = 2078s**
- Before main `fd5eb16` run `45735400939`：0=24s，1=143s，2=603s，3=1302s（slowest 1302s）
- After #88 run `45738371952`：0=19s，1=596s，2=1733s，3=31s（slowest **1733s**）

Pack: `evening-17-69-lane3/td18_wp26/`

## Pack index
- `evening-17-69-lane3/merge4_83/` — merge④
- `evening-17-69-lane3/merge6_gate/` — ⑥ + golden + W5 + ABUND
- `evening-17-69-lane3/td18_wp26/` — TD-18
- `1771-handoff/` — this HANDOFF
