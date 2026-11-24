# Evening 17-67 — Hang + S1/S2 + timeouts (blocks 17-66)

**Status:** PRs open; **no merge** until Owner-accepted evening pack (17-68). Packs owned by Evening pack backfill.

## Hung test

| Field | Value |
| --- | --- |
| Test | `test_K4_formal_boot_30d_sail_buy_sell_no_manual_board` |
| Script | `tests/unit/test_d123_opening_board_1766.gd` |
| Also stressed | `test_K2_explore_sails_without_opening_board` (same `max_affordable_qty` path) |
| Runs | #499 push + #500 PR @ `ba1e644` — gut-unit-property canceled ~3h44m; gut-ui + golden OK |

Evidence: job log stack at cancel → `_evaluate_and_maybe_sail` → `CashLedger.max_affordable_qty` → `MarketPricer.quote` → ERR-SYS04-06. Artifact `gut-unit-property-logs` on #499: **~1.2M** `ERR-SYS04-06`, ~1.38GB log.

## Root cause

Not a wait/deadlock. `max_affordable_qty` binary-search **probes `qty > stock`**. Each probe calls `MarketPricer.quote`, which `_record_error` / `push_error` for every overstock probe. K2 explore + K4 formal (ba1e644 used full SimEngine 48×30d) × goods × ports × days → error I/O storm that hung CI.

Tip mitigations (Opening board / #83): mini traders, modest stock, early-exit, mark errors handled — **not** a product root fix.

**Product fix:** Cap search exclusive upper by `GoodsLedger` market stock **only when `_quote_provider == MarketPricer`** (DemoQuoteProvider / WP56 q=124 unchanged). First gate on `PortRegistry.is_loaded()` broke TST-SYS05-08 because PortRegistry stays loaded across GUT scripts with empty stock. See `cash_ledger_stock_cap.diff` (follow-up `76d8a93` / `7276658` / `933cd3d`).

## S1 / S2 — why feature dual-ran

### Before (feature tip / int-1758 @ hang)

```yaml
on:
  push:
  pull_request:
# (no concurrency)
```

Push events use the **branch’s** workflow file. `cursor/m1b-fix-1766-3fe3` and `int-1758` still had unrestricted `on: push:`, so every feature push dual-ran with the PR. Main’s ci-speed S1 never applied to that tree.

Main already had S1, but S2 was:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

`github.ref` is `refs/heads/X` on push vs `refs/pull/N/merge` on PR → **different groups** → cancel-in-progress cannot kill the sibling.

### After

```yaml
on:
  pull_request:
  push:
    branches:
      - main
      - tools-1758
      - int-1758

concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.ref_name }}
  cancel-in-progress: true
```

Files: `s1s2_feature_before.txt`, `s1s2_main_before_s2fix.txt`, `s1s2_after.txt`, `workflow.diff`.

## Timeouts

| Job | Before (main ci-speed) | After (17-67) |
| --- | --- | --- |
| gut-unit (per shard) | 35 | **30** |
| gut-ui | 15 | **30** |
| golden-30d | 15 | **30** |
| m1b-h4 / m1b-w4 | 15 | 15 (unchanged) |

See `timeout.diff.txt`. Goal: whole CI wall ≤50m.

## Node 24 actions — version truth (17-69 Lane1 correction)

**Contradiction fixed:** an earlier draft of this section listed tip pins `checkout@v7` / `cache@v6` / `upload-artifact@v7` / `download-artifact@v8` as if they were the `8456c57` change. That was wrong.

| Commit | Actions pins (unique) | Note |
| --- | --- | --- |
| `8456c57` (first 17-67 CI commit on #84) | `checkout@v5`, `cache@v5`, `upload-artifact@v5`, `download-artifact@v5` | Matches `workflow.diff` / `s1s2_after.txt` / `timeout.diff.txt` “after (8456c57)” |
| `e38aea5` (#84 follow-up) / `4cdb91a` (#85 twin) | `checkout@v7`, `cache@v6`, `upload-artifact@v7`, `download-artifact@v8` | Separate bump: `@v5` still warned Node 20 forced→24 |
| Tip `#84` `1a3e5f1` / tip `#85` `0b279d5` | same as e38aea5/4cdb91a majors | + MarketPricer-only stock-cap + WP27 unload |

Truth: **8456c57 = all `@v5`**. Tip majors came later in `e38aea5` / `4cdb91a`. #85 PR body already said `@v5` for the int port; #84 PR body still echoes the tip majors — do not read that as 8456c57 content.

## PRs (do not merge — 17-68 / 17-69)

| PR | Base | Branch | Tip (HKT 2026-11-24 ~22:09) |
| --- | --- | --- | --- |
| [#84](https://github.com/wayung0217/Project-Patrician/pull/84) | `main` | `cursor/ci-hang-1767-866d` | `1a3e5f1` |
| [#83](https://github.com/wayung0217/Project-Patrician/pull/83) | `int-1758` | `cursor/m1b-fix-1766-3fe3` | `51cc942` |
| [#85](https://github.com/wayung0217/Project-Patrician/pull/85) | `int-1758` | `cursor/int-ci-1767-866d` | `0b279d5` |

## Coordination

After hang fixed on m1b-fix: resume #83 green → int → `z-1758-3` (Opening board / 17-66). Evening pack backfill owns pack assembly; this folder is evidence for 17-67.

## Follow-up CI fixes
- MarketPricer-only stock-cap (DemoQuoteProvider).
- WP27 unload BuildingEconomy (shard co-locate with WP-18/19).
- Gates: main #84 = 555; int #85 = 600; #83 = 608 (+8 D-123).
