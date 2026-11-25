# I4 — Gate baseline vs L4 D-123 tests

## L3/L2 gate (keep after I3)

Use L3 tip workflow after mandatory:

```bash
git checkout <L3 tip> -- .github/workflows/ci.yml
```

1. Sum shard Passing counts → `total`
2. `BASELINE_COUNT` = lines in `.github/ci/gut_unit_property_baseline_names.txt` (**555**)
3. Fail if `total < BASELINE_COUNT`
4. Print `ADDED_NAMES` / `REMOVED_NAMES` (or `無`); fail if REMOVED non-empty (Owner 追認乙)
5. New tests (R972, D-123, int-only) appear under ADDED; need not be in the 555 file
6. **`gut_unit_property_baseline_paths.txt` deleted** — **do not revive**

## L4 gate — drop on rebase (**no `==608`**)

| Commit | Hard expect | After I3 |
|--------|-------------|----------|
| early L4 CI | `== 555` | **drop** |
| `04f4891` | `== 600` | **drop** |
| `863c936` | `== 608` | **drop** — never keep |

Hard equality fights the set-diff gate. **No `==608` on the rebased tip.**

## L2 adds (corrected)

L2 tip adds **3** R972 / EX-05-09 tests (not 4).  
`tests_added: 3` → expected Passing ≥ **558** on main (555 + 3); baseline file stays 555 names.

## L4 tests (8)

```
test_K1a_seed_opening_board_n1_mid_matches_origin
test_K1b_opening_trimmed_at_window_days
test_K1c_real_arrival_coexists_with_opening
test_K1d_seed_does_not_write_own_contact_ship_snap
test_K1e_pricing_failure_collects_all_refuses
test_K2_explore_sails_without_opening_board
test_K4_formal_boot_30d_sail_buy_sell_no_manual_board
test_K4_f1_note_prior_green_used_intel_override
```

None are in the 555 baseline (correct). Under L3 gate they only need to **pass** and increase `total` / show under ADDED.

## Coverage check (source funcs; historical scan)

| Ref | test_* funcs | baseline names missing in source |
|-----|--------------|----------------------------------|
| main | 561 | 0 |
| int-1758 | 606 | 0 |
| L4 ddc2447 | 614 | 0 |

## Prerequisite

I2 must land **names** baseline (+ README). **No paths.txt.** After I3, mandatory `git checkout <L3 tip> -- .github/workflows/ci.yml`.
