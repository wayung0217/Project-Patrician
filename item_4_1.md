# 4.1 Three tip mitigations + mark-handled removal

Tip at delivery: `ddc2447484468670aca114e62bd6e84555510b65` on `cursor/m1b-fix-1766-3fe3` (#83).

## Mitigations (on tip before removal)

| # | Mitigation | Why | Introduced | Diff |
|---|------------|-----|------------|------|
| 1 | **Mark errors handled** (`_mark_afford_probe_errors_handled`) | `max_affordable_qty` binary search probed `qty>stock` → MarketPricer `ERR-SYS04-06` / GUT Unexpected Errors | `c49e015` | `diffs/mitigation_modest_stock_and_mark_handled.c49e015.diff` |
| 2 | **Mini traders** (2× TR-001/002, 1 ship each via `_boot_traders_mini`) | Params lock `SHIP_MIX`/`TIER_MIX` length=48; SimEngine 48×30d hung CI ~3h44m (#499/#500). Keep formal seed+sail contract under GUT budget | `51cc942` then rewrite `e19c853` | `diffs/mitigation_mini_traders.51cc942.diff`, `diffs/mitigation_mini_roster_rewrite.e19c853.diff` |
| 3 | **Modest stock** `MARKET_STOCK=500` + `TRADER_CASH_CAP_LI=20000` | Replaced 10M×ports×goods genesis that burned ~15m of GUT; keeps afford probes short | `c49e015` (after deep-stock `b29e297`) | `diffs/mitigation_modest_stock_and_mark_handled.c49e015.diff` |

## Product fix that allows removing (1)

`CashLedger.max_affordable_qty` exclusive hi = `stock+1` when quote provider is `MarketPricer` — tip `7276658` (evidence `diffs/product_stock_cap.7276658.diff`). **L4 did not edit `cash_ledger.gd`** (L2 ownership). Tip already carries this hang-worker fix; Lane2 pack not required for removal on #83.

## Removal

- Dropped `_mark_afford_probe_errors_handled` and both call sites (K2, K4).
- **Commit SHA of removal:** `ddc2447484468670aca114e62bd6e84555510b65`
- Diff: `diffs/remove_mark_errors_handled.ddc2447.diff`

Mini traders + modest stock **remain** (GUT ≤50m / schema length=48). Full 48×M1b 30d stays z-matrix / H4.

## C-06 / N-05 (Owner 4.1)

Mark-handled briefly set GUT `handled=true` on expected `buy qty>` push_errors — **silent swallow risk** (C-06 / N-05). Owner: remove after Lane2 product fix; keep only with FRM/ERR gap for Owner. **Removed** (not retained); no FRM claim to keep. See `gaps.md` G-L4-03 if L2-only provenance required.

## FRM note

No FRM gap for retaining (1): product stock-cap is on tip. Removal SHA above.
