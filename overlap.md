# File overlap across lanes (for I3 + future main↔int)

## L2 ∩ L4 (different bases today)

```
autoload/cash_ledger.gd
.github/workflows/ci.yml
tests/unit/test_sys23_wp27.gd
```

## L3 ∩ L4 (same int-1758 base → I3)

```
.github/workflows/ci.yml
```

Only path that content-conflicts on L4 rebase.

## cash_ledger divergence (L2 vs L4)

- Both add MarketPricer stock-cap exclusive upper bound.
- L2: Dictionary KIND+PORT → `get_qty` (D-08d / no `make_market` in H).
- L4: `GoodsLedger.make_market(port_s)`.
- L4/int also has `REQUESTER_TRADER_GENESIS_GRANT` (D-23c) absent from L2/main tip.
- I1–I3 keep tracks separate; document for later integration only.

# L4 ∩ L5 — `tools/run_m1b_report.gd`

## Shared path
`tools/run_m1b_report.gd` (also L5 touches `tools/run_m1b_README.md`).

| Lane | Branch / PR | Tip (W6 time) | Base |
|------|-------------|---------------|------|
| **L5** | `tools-1769` / #86 | `9b333c704c62fe00fe59ce1b67684de9b7e88948` | main |
| **L4** | `cursor/m1b-fix-1766-3fe3` / #83 | `3816c239f27cf430fa7fac5f6fc1927c379b49dd` | int-1758 |

## What each side changed

### L5 (#86, tools owner for 17-69)
- **5.1 SEED_NO_EFFECT:** compare seed-only pair `Za_G0_A0` vs `Zd_G0_seed2`; if ①②③④ metrics identical → `WARNING: SEED_NO_EFFECT` + identical column list; **does not** flip PASS/FAIL.
- **5.2:** table ⑥ `season_sail_count` / `season_cargo_dan` — exact column names only; missing → **N/A** (T3).
- **5.3:** table ⑦ `trader_sails_total` + `trader_cargo_dan_total` from `trader_summary`.
- Keeps main/17-64 T3 N/A defaults.

### L4 (#83, D-123 K3 report side)
- Extends ⑤ with `cargo_dan_sum`.
- Adds ⑥ **Trader sail / cargo (D-123):** `sail_sum`, `cargo_dan_sum`, per-season `season_sails` (from existing `sail_count` rows).
- Keeps **Z4** `duration_s` ISO start/end derive (`_duration_s_from_iso`).
- Lineage is **int-1758** (pre–ci-speed T3 N/A in places → empty strings).
- **No** SEED_NO_EFFECT.

## Merge order (who first)

1. **L5 first** onto main (`#86`). L5 owns `tools/` for 17-69; SEED_NO_EFFECT + T3 N/A are mainline report behavior.
2. **Then L4** when int→main (after INT-1 rebase): take **L5 file as ours** for `tools/run_m1b_report.gd`, then port L4-only bits if still missing:
   - `_duration_s_from_iso` / start–end derive (if not already on main via int merge path)
   - per-season `season_sails` breakdown (L5 has totals; L4 has comma-joined per-season)
   - Do **not** drop SEED_NO_EFFECT or revert T3 N/A to blank PASS/FAIL.
3. Do **not** merge L4 report onto main before L5 — would lose SEED_NO_EFFECT and fight T3.

Diffs in this pack: `l5_vs_main_*.diff`, `l4_vs_main_*.diff`, `l4_vs_l5_*.diff`.
