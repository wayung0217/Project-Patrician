# 17-69 補正三 W10 — HANDOFF

**Orphan:** `review/evening-17-69-handoff`  
**Tip SHA:** `07cc97a38941eccdff671e7ab55ebad8072e6a67`  
**Pack body (`orphan_sha.txt`):** 見該檔  
**Queried:** 2026-11-25 ~10:15 Asia/Hong_Kong（`gh` 即時；勿抄過期數字）  
**Hard rules:** 不合併、不打 tag、不跑 `z-1758-3`；未獲 Owner **一次批准**前 PR 原樣保留。  
**Spec gate:** docs/spec v6.99.222

---

## 1. 開著的 PR（即時）

| PR | 分支 | tip SHA | base | draft | merge | CI 最新結論 | CI 連結 | 未解缺口 | 依賴 |
|----|------|---------|------|-------|-------|-------------|---------|----------|------|
| [#72](https://github.com/wayung0217/Project-Patrician/pull/72) | `cursor/lane-a-wp36-traders-26f5` | `114885290a641f3e053cb04c0f87a0db3b6b0c94` | `main` | draft | CLEAN | **success**（舊式 gut-unit-property + gut-ui；雙 run push+PR） | [45320457100](https://github.com/wayung0217/Project-Patrician/actions/runs/45320457100) / [45320450314](https://github.com/wayung0217/Project-Patrician/actions/runs/45320450314) | F1(a) 30d trader_summary 需 M1b／Owner；F4① explore 定點精度未定；F4② `SHIP_DRAFT` 仍在 ship_registry（非 Lane F） | 已併入 `int-1758`（#81）；對 main 草稿勿直併 |
| [#78](https://github.com/wayung0217/Project-Patrician/pull/78) | `cursor/ui-1755-debug-panels-ff98` | `1fd181acf5012a49494b3084e4045202987e4507` | `main` | draft | CLEAN | **success** | [45215277319](https://github.com/wayung0217/Project-Patrician/actions/runs/45215277319) | City auto-housing 無公開計數（UI 顯示 gap）；G-INT-01 formal L1 未 wire TRADERS | 原建於 int-1755 tip；獨立 debug UI；非 17-69 合併鏈 |
| [#79](https://github.com/wayung0217/Project-Patrician/pull/79) | `housing-1758` | `e484548e00ef552ff875a57988049837893a2fd3` | `main` | draft | CLEAN | **success** | [45312155342](https://github.com/wayung0217/Project-Patrician/actions/runs/45312155342) | 草稿勿併；已進 int | G→#81 第一步；依賴 main `@1252ab1` 時代 |
| [#80](https://github.com/wayung0217/Project-Patrician/pull/80) | `tools-1758` | `bbd4975768a773486f4485d78d02e04616cb7a0a` | `main` | draft | **DIRTY／CONFLICTING** | tip **success**（含 golden／H4／W4 on push） | [45321456614](https://github.com/wayung0217/Project-Patrician/actions/runs/45321456614) / push [45321451648](https://github.com/wayung0217/Project-Patrician/actions/runs/45321451648) | vs main **衝突**；勿直併 main；Z tag 禁推 | 已併入 #81；`m1b-z.yml` 待 int 綠後 Owner 授權 |
| [#81](https://github.com/wayung0217/Project-Patrician/pull/81) | `int-1758` | `71b094d773125cc96ee66ff65691d5219a22eedf` | `main` | draft | **DIRTY／CONFLICTING** | tip CI **success**；z-1758-2 M1b-Z **success** | CI [45356713051](https://github.com/wayung0217/Project-Patrician/actions/runs/45356713051)／[45356709899](https://github.com/wayung0217/Project-Patrician/actions/runs/45356709899)；Z [45356709933](https://github.com/wayung0217/Project-Patrician/actions/runs/45356709933) | vs main **衝突**；整合幹；勿直併；**禁** `z-1758-3` | 合併序 G(#79)→F(#72)→H(#80)；#83/#85 的 base |
| [#83](https://github.com/wayung0217/Project-Patrician/pull/83) | `cursor/m1b-fix-1766-3fe3` | `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70` | `int-1758` | open | UNSTABLE | tip 最新 run **cancelled**（gut-unit(0) 取消；其餘 shard／ui／golden success；gate skipped）。父 tip `3816c23` 曾 **9/9 success** | tip [45522909540](https://github.com/wayung0217/Project-Patrician/actions/runs/45522909540)；父綠 [45426826871](https://github.com/wayung0217/Project-Patrician/actions/runs/45426826871) | tip 僅 W3 註解／docs；需重跑或接受父綠；I3 rebase 後再驗；等 Owner 批准 | 依 INT-1 rebase 到「int + #85 workflow」；禁動 `ci.yml`／`cash_ledger` |
| [#84](https://github.com/wayung0217/Project-Patrician/pull/84) | `cursor/ci-hang-1767-866d` | `b28012ca49407433e229e8cfc698e083e7680e8f` | `main` | open | CLEAN | **9/9 success**（gut-unit0–3／gut-ui／golden-30d／gut-unit-gate＝success；H4/W4 skipped） | [45528301812](https://github.com/wayung0217/Project-Patrician/actions/runs/45528301812) | **等 Owner 批准合併**（無其他產品缺口） | 合併序第一步 → main；lane2 orphan `88fdddb` |
| [#85](https://github.com/wayung0217/Project-Patrician/pull/85) | `cursor/int-ci-1767-866d` | `da3d911a9a6882d85a4d1bee523b78e9af0ad365` | `int-1758` | open | UNSTABLE | **failure**：gut-unit(3)＝WP27 int gap；**golden OK**；gate skipped | [45523639567](https://github.com/wayung0217/Project-Patrician/actions/runs/45523639567) | WP27 unload 在 #84 產品測、不在 int；L3 禁加產品；#84→main 後需重移植確認 | 移植自 #84 `19d1a4e` CI；ci.yml 若再變須重移植 |
| [#86](https://github.com/wayung0217/Project-Patrician/pull/86) | `tools-1769` | `9b333c704c62fe00fe59ce1b67684de9b7e88948` | `main` | open | UNSTABLE | tip 唯 run **cancelled**（gut-unit(0) 取消；1–3／ui／golden success；gate skipped） | [45411941948](https://github.com/wayung0217/Project-Patrician/actions/runs/45411941948) | tip CI 未完整結束；tools-only；與 L4 `run_m1b_report.gd` 重疊見 lane5 overlap | 獨立 tools；非 #84→#85→#83 主鏈 |

### #84 tip 證據（線 2 最終確認）

| 項 | 值 |
|----|-----|
| tip | `b28012ca49407433e229e8cfc698e083e7680e8f` |
| run | https://github.com/wayung0217/Project-Patrician/actions/runs/45528301812 |
| conclusion | **success（9/9）** |
| gate | `TOTAL_PASSING=558`／`BASELINE_COUNT=555`；`REMOVED_NAMES=無`；`ADDED_NAMES`＝三 EX-05-09 |
| golden | `GOLDEN_BOOTSTRAP=0`；`DIFF_CELLS=0`；`IDENTICAL=1`；artifact `14983617491` |
| lane2 orphan | `review/evening-17-69-lane2` @ `88fdddb3ed46c0b1ceb2fe73095447abd58c70e8` |
| 未解缺口 | **等 Owner 批准合併** |

### #83 tip 說明（與「全綠」傳聞）

tip `4d05f0d`＝`3816c23`＋W3 docs/comment only。`gh` 上 tip 唯 run `45522909540`＝**cancelled**（concurrency／長 shard）。父 tip 綠＝`45426826871`。交接以 tip 的 `gh` 狀態為準。

### #86 tip 核對

指派短 SHA `9b333c7` → 全長 **`9b333c704c62fe00fe59ce1b67684de9b7e88948`**（`gh` 確認）。

---

## 2. 建議合併順序（Owner 一次批准後）

1. **#84 → main**（tip `b28012c`；CI 已綠；含 D-125／D-124、CI gate、golden bootstrap 路徑、WP27 unload 測）。
2. **main 產出 golden-30d artifact**（非 bootstrap；確認 main 上傳／保留）。
3. **#85 重移植確認**：若 #84 tip 相對移植源 `19d1a4e` 的 `ci.yml`／`.github/ci/` 有變 → 重做 BYTE_MATCH 移植並更新 tip；否則確認仍 `da3d911` 定稿後再併入 `int-1758`。WP27 產品測隨 #84→main→int 路徑解決（L3 不加產品）。
4. **#83 依 INT-1 rebase 到 int-1758（含 #85 workflow）**：衝突時 `ci.yml` 取 L3；rebase 完強制 `git checkout <L3 tip> -- .github/workflows/ci.yml`；**禁** `==608`／revive `paths.txt`。

並行／後續（非主鏈阻塞，仍需 Owner）：#86 tools；#72/#79/#80 已在 int；#78 UI 獨立；#81 對 main 衝突待整併策略。

**禁止至批准：** merge、tag、`z-1758-3`、推產品碼到 feature。

---

## 3. Cursor 自建 CI 規則與 `.github/ci` 基線

來源：#84 tip `b28012c` 的 `.github/workflows/ci.yml` + `.github/ci/README.md`。

### 觸發／併發

- `pull_request`；`push` 僅 `main`／`tools-1758`／`int-1758`；`workflow_dispatch`（ci／h4-smoke／w4-inline-cmp）。
- concurrency：`CI-${{ github.head_ref \|\| github.ref_name }}`，`cancel-in-progress: true`（push+PR 互取消 → #83/#86 tip 見 cancelled）。

### Gate names set（`gut-unit-gate`）

- 基線檔：`.github/ci/gut_unit_property_baseline_names.txt`（555 names；**paths.txt 已刪，禁復活**）。
- 規則：Passing ≥ baseline；印 `ADDED_NAMES`／`REMOVED_NAMES`（或 `無`）；**REMOVED 非空 → fail**（須 Owner 預批才可刪名）。
- #84 tip 實績：558／555；REMOVED＝無；ADDED＝三 `test_R972_EX_05_09_*`。

### GOLDEN_BOOTSTRAP

- 主路徑：PR 下載 main 未過期 `golden-30d` artifact 比對 → `GOLDEN_BOOTSTRAP=0`。
- 例外（S9b）：無 main artifact 時用 `.github/ci/golden_30d_bootstrap_1764.{csv,sha256}`（17-64 凍結，`8b25c951…`）→ `GOLDEN_BOOTSTRAP=1` + `DIFF_CELLS`。
- #84 tip：`GOLDEN_BOOTSTRAP=0`，`DIFF_CELLS=0`。

### Timeouts（#84 tip）

| Job | timeout-minutes |
|-----|-----------------|
| gut-unit（shard 0–3） | 45 |
| gut-unit-gate | 5 |
| gut-ui | 15 |
| golden-30d | 15 |
| m1b-h4-smoke／m1b-w4-inline-cmp | 15（僅 tools-1758／int-1758／dispatch） |

### 其他

- SCRIPT ERROR gate（unit log 含 `SCRIPT ERROR` → fail）。
- Import clean tree（缺 `.uid`／`.import` → fail）。
- `tools/*.ps1` 純 ASCII（shard 0）。
- actions：checkout／cache／artifact @v5 線（歷史曾試 v7；以 tip `ci.yml` 為準）。
- Fork PR skip golden（P6b）；Z 工作流另檔 `m1b-z.yml`（tag `z-1758-*`）。

`.github/ci/` **屬 Lane2（#84）擁有**（Owner 追認甲）；L3 只移植、不改產品。

---

## 4. 已知風險

1. **D-127**：指標對商人不敏感（交接保留；後續 Owner／規格）。
2. **band4 87.3%**：Y5 以**價格地板**為主（過剩 `w≥10`），非天花板；Za_G0_A0 例 band4／448＝87.3%（W8／lane4 `w8_band_terminology.md`）。band0+4 仍遠高於 ≤30% M1b 閘。
3. **#85 gut-unit(3)**：int 缺 #84 WP27 unload → Unexpected Errors（ERR-SYS08-08）；golden 已綠。
4. **#81／#80 vs main CONFLICTING**；整併需策略。
5. **Concurrency cancel** 可讓 tip run 顯示 cancelled／UNSTABLE（#83／#86），解讀時對照父 tip／job 明細。

---

## 5. Orphan 索引（證據包；非產品）

| Orphan | tip（遠端） |
|--------|-------------|
| `review/evening-17-69-lane1` | `c1fd855611cad108c5c03604f4e47b1e63c95dda` |
| `review/evening-17-69-lane2` | `88fdddb3ed46c0b1ceb2fe73095447abd58c70e8` |
| `review/evening-17-69-lane3` | `0b4b795670ec8ddbf7b2b8fad79c5bf5b02edfc1` |
| `review/evening-17-69-lane4` | `d789f0410feee33d1cd65c3ecd5df2cc919e8fa5` |
| `review/evening-17-69-lane5` | `8468b864149604e8e6b2cb8acf060ced8b559e4e` |
| `review/evening-17-69-int` | `7d8ece439134c109e5f8a112771f3c32029a91e4` |
| `review/evening-17-69-handoff` | `07cc97a38941eccdff671e7ab55ebad8072e6a67` |

W9 已刪：`cursor/int-1755-merge-0a6e`／`int-1756-295f`／`int-1757-5ae9`；關 #69／#70。

---

## 6. Owner 決策門

**等 Owner 一次批准；未批准不合併。**  
批准範圍建議明示：#84→main → golden → #85 重移植確認 → #83 INT-1 rebase；其餘 PR 是否一併處理。  
Cursor 於本交接後**暫停**（不再推 commit）。
