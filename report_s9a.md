# S9a — evening-17-69-lane2 (#84 / 17-69 2.1–2.10) — R9-73 unified tip

**Final tip (unified):** `6a731ff051874c767be52c1904df898e294c180f`  
**Branch:** `cursor/ci-hang-1767-866d` → `main` (PR #84)  
**B9:** v6.99.220 · **Merge:** no

## git branch -r (H7)
```
origin/HEAD -> origin/main
  origin/cursor/ci-hang-1767-866d
  origin/cursor/int-1755-merge-0a6e
  origin/cursor/int-1756-295f
  origin/cursor/int-1757-5ae9
  origin/cursor/int-ci-1767-866d
  origin/cursor/lane-a-wp36-traders-26f5
  origin/cursor/m1b-fix-1766-3fe3
  origin/cursor/ui-1755-debug-panels-ff98
  origin/diag-z-1758
  origin/housing-1758
  origin/int-1758
  origin/main
  origin/review/evening-17-55
  origin/review/evening-17-57
  origin/review/evening-17-69-lane1
  origin/review/evening-17-69-lane2
  origin/review/evening-17-69-lane4
  origin/review/evening-17-69-lane5
  origin/tools-1758
  origin/tools-1769
```
Remote count (all refs incl. review/*): 20. review/* excluded for S9i②; remaining ≫8 — H-1 Owner list is Integration/H lane.

## A 基線
對／有改動。見 `baseline_A.txt`。
- head **`6a731ff051874c767be52c1904df898e294c180f`**
- base `origin/main` = `191a7ee6aaa0f03c0cb32d6a803105fca7f95ee9`
- main 基線 unit+property **555** 名 → `.github/ci/gut_unit_property_baseline_names.txt`
- 本包新增 **3** EX 測 → 期望 Passing **≥558**；gate = ≥555 + 舊名 set 差集（2.4）

## B 變更清單
對。`git diff --stat origin/main...HEAD`：
```
 .github/ci/README.md                            |  13 +
 .github/ci/gut_unit_property_baseline_names.txt | 555 ++++++++++++++++++++++++
 .github/workflows/ci.yml                        | 127 ++++--
 autoload/cash_ledger.gd                         |  37 +-
 tests/unit/test_r972_cash_stock_cap_1769.gd     | 292 +++++++++++++
 tests/unit/test_r972_cash_stock_cap_1769.gd.uid |   1 +
 tests/unit/test_sys23_wp27.gd                   |   9 +-
 7 files changed, 994 insertions(+), 40 deletions(-)
```
### 產品碼
- `autoload/cash_ledger.gd` — FRM-SYS05-09／D-124 stock bound；**MarketPricer guard kept** (D-125 gap)
- `.github/workflows/ci.yml` — timeouts／gate ADDED/REMOVED／ANSI name strip／golden fail／actions@v5
- `.github/ci/*` — names baseline + README（paths.txt **deleted**；Owner 丙）

### 測試
- `tests/unit/test_r972_cash_stock_cap_1769.gd` (+`.uid`) — 3 EX tests
- `tests/unit/test_sys23_wp27.gd` — BuildingEconomy unload（1a3e5f1；ERR-SYS08-08）

## C 規格對照表
| ID | 實作 | 測試 |
| --- | --- | --- |
| FRM-SYS05-09／D-124 | `max_affordable_qty` MIN(cash,s) | EX-05-09-01/02/03 |
| ERR-SYS04-06 抑制 | exclusive hi=s+1；s=0→0 | EX delta==0 |
| MarketPricer-only guard | `_quote_provider == MarketPricer` | **D-125 gap**（keep） |
| D-08d | Dictionary→container_id | EX fixtures |
| 17-69 2.2–2.6 | `ci.yml` | tip CI evidence |

## D 介面清單
對／有改動（行為）：`max_affordable_qty` 在 MarketPricer 路徑設庫存 exclusive 上界（簽名未變）。無新 Autoload／無 project.godot 變更。

## E 自查掃描＋`_mark_errors_handled`（R9-73 L2-3）
產品 hunk：無新增業務 magic（`abs_hi=-1`＝EX-02 哨兵）；無跨模組 `_`／int(／round(／await／Timer／rand*／Dictionary 遍歷新增。FRM-SYS05-09＋D-124 註解有。

### `_mark_errors_handled` in R972 tests ≠ L4 product-side mark-handled（不是 C-06）
| | #84 R972 **tests** (`_mark_errors_handled`) | #83 L4 **product-path** mitigation (removed `ddc2447`) |
| --- | --- | --- |
| Where | GUT test helper only; never in `cash_ledger.gd` | Called around M1b afford probes in trader/sim test path to swallow expected `buy qty>` push_errors |
| Why present | Fixture setup may quote at high qty while seeding cash; GUT would otherwise flag leftover Unexpected Errors **after** the assertion window | Hang-era binary search **did** probe qty>stock → ERR-SYS04-06 storms; mark-handled hid them |
| Assertion integrity | ERR-SYS04-06 **delta** is counted **between** two `_count_err_sys04_06()` calls that bracket `max_affordable_qty`; mark-handled is outside that window (Owner confirmed) | Silent swallow of product-path errors → C-06／N-05 risk |
| Product fix | Stock-cap on MarketPricer path makes search never probe qty>stock | Same product fix allowed L4 to **remove** mark-handled |
| C-06? | **No** — test harness housekeeping; does not alter product error reporting or collect-all | **Would be** if retained after product fix; L4 removed it |

See also Lane4 `evening-17-69-lane4/item_4_1.md`. R972 keeps test-only helper; no FRM gap; not C-06.

## F 測試名單與計數（R9-73 L2-2）
- 新增：`test_names_added.txt` → **3** EX：
  - `test_R972_EX_05_09_01_stock_bottleneck_q_300`
  - `test_R972_EX_05_09_02_cash_bottleneck_q_120`
  - `test_R972_EX_05_09_03_zero_stock_no_quote`
- 刪除：無（baseline 555 未改名）
- 計算：555 + 3 − 0 → Passing **≥558**；gate baseline file still 555 names（≥ + set-diff）
- Baseline control（Owner 乙）：任何未來對 `gut_unit_property_baseline_names.txt` 的增刪須本節逐名＋理由；刪名需 Owner 事前核准；不得與產品同 commit
- CI：`ci_links.md` + `ci_evidence/`（L2-4）

## G 排程與信號
對／無改動。

## H 偏離與缺口
- **D-125 only**（R9-73 L2-1）：見 `gaps_2_8_2_10.txt` — keep MarketPricer guard；甲／乙待裁。
- H5：orphan `review/evening-17-69-lane2`（非 SharePoint／非 store-only）。
- 2.5：`GOLDEN_BASE_MISSING` 直至 main 綠 golden — 見 `ci_evidence/golden_base_missing_excerpt.txt`。
- 未合併、未打 tag。

## I 格式
- 2.1 新測全文：`test_r972_cash_stock_cap_1769.gd.txt`
- 2.4 gate：`ci.yml.diff` + baseline names
- 2.5／2.9：`probe_2_9.txt` + `ci_evidence/`
- 2.6：`actions_versions.txt`
- READY_FOR_LANE3：`READY_FOR_LANE3.txt` = tip SHA above

## H5 orphan
- branch: `review/evening-17-69-lane2`
- product tip: `6a731ff051874c767be52c1904df898e294c180f`

## Owner 追認 甲／乙／丙（落地）
- (甲) `.github/ci/` ∈ Lane2 2.4
- (乙) gate 印 ADDED_NAMES／REMOVED_NAMES（或 無）
- (丙) **deleted** `gut_unit_property_baseline_paths.txt`

---

---

## Amend R9-73 timeout bumps → tip `6a731ff051874c767be52c1904df898e294c180f`

### Why timeout bumps (D-120(e))
| Tip | Run | gut-unit(0) | Wall |
| --- | --- | --- | --- |
| `bb1b50d` | [45424793984](https://github.com/wayung0217/Project-Patrician/actions/runs/45424793984) | cancelled | hit `timeout-minutes: 30` (~30m20s) → gate skipped |
| `e99b495` | [45432147322](https://github.com/wayung0217/Project-Patrician/actions/runs/45432147322) | cancelled | hit `timeout-minutes: 35` (~35m18s) → gate skipped |
| `6a731ff` | [45440174473](https://github.com/wayung0217/Project-Patrician/actions/runs/45440174473) | **success** (~29m) | `timeout-minutes: 45` |

Shard0 carries unit+**property**; other shards finish ≪10m. Prior tip `b998cea` shard0 ~29m — later tips crossed 30/35 walls. Bumps are CI-only; product unchanged. Whole-CI wall still ≤50m under parallel jobs.

### READY
`6a731ff051874c767be52c1904df898e294c180f`

---

## L2-4 FINAL (tip `6a731ff051874c767be52c1904df898e294c180f`)

- Tip run https://github.com/wayung0217/Project-Patrician/actions/runs/45440174473
- gut-unit(0..3)+gate **success**; TOTAL_PASSING=558; REMOVED=無; ADDED=3 EX
- golden-30d **failure** GOLDEN_BASE_MISSING (2.5 intentional)
- actions@v5 resolved on tip gate + golden jobs — `actions_versions.txt`
- Timeout 45m justified: prior tips cancelled at 30/35; this tip shard0 finished ~29m
