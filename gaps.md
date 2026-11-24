# Gaps — evening-17-69-lane4

## Closed this lane
- **4.1 mark-errors-handled:** Removed on tip `ddc2447` (C-06/N-05 silent-swallow). Not re-added.
- **H5:** Orphan `review/evening-17-69-lane4` (no SharePoint for Cursor).
- **R9-73 L4-2 N-04:** #83 `make_market` stock-cap dropped on tip (see below). #84 Dictionary+`container_id` is sole formal stock-cap.
- **W3 D-126 甲（補正三／v6.99.222）:** Owner 核准 `base_price_li` 為**試驗值**；代碼邏輯不變，僅加註。status → **D-126 核准（試驗值）**（見 `trace.csv`）。

## Open / deferred
| ID | Gap | Notes |
|----|-----|-------|
| **D-126** | FRM-SYS17-04 未定義無 mid 時排序；explore 用 `GoodDef.base_price_li` 作排名替代 | **D-126 核准（試驗值）** — 補正三甲；非正式 FRM 數值；代碼保留 |
| G-L4-01 | Post-fix z-matrix trader_summary totals | H1 forbids z-1758-3 until Owner accepts packs. Pre-fix z-1758-2 all sails=0 in `trader_summary_raw/`. |
| G-L4-02 | Golden-30d full CSV diff for D-123 | K5 TRADERS=0 explain still pending (17-66). No golden CSV rewrite this lane. |
| G-L4-04 | Spec scan formal output | No separate scan.txt this lane; ownership grep only (S9a E). |

## R9-73 L4-2 — stock-cap removal SHA
- **Drop commit:** `3816c239f27cf430fa7fac5f6fc1927c379b49dd`（見 `r973_l4_2_drop_sha.txt`）.
- Restored `autoload/cash_ledger.gd` `max_affordable_qty` to `int-1758` (no `GoodsLedger.make_market` stock-cap).
- Formal stock-cap remains on #84 (Dictionary KIND+PORT → `get_qty`).
