# 4.5 K2 root cause — function + condition + before/after

## Function + condition

**Site:** `TraderRegistry._evaluate_and_maybe_sail` (`autoload/trader_registry.gd`)

**Failing condition (before):** For every `(dest, good)` candidate, `_dest_intel` / `board_for` must return non-empty with `mid_li`. When ST-BOARD empty (M1b cold start, no seed):

```
if intel.is_empty() or intel.get("mid_li", null) == null:
    continue   # always — even when explore==true
```

Explore traders still set `decision.sail=true` only if a best candidate exists; `pick_best_candidate([])` is empty → idle, **sail=0** (17-63: explore_hit=2, sails=0).

## After (D-123(b) / FRM-SYS17-04)

Same site; when intel empty **and** `explore`:

- Use `GoodCatalog.get_good(good).base_price_li` as ranking mid stand-in only.
- Profit gate already skipped for explore; dests still filtered by enter/draft/voyage/afford/qty/`EXPLORE_QTY` / D-110(g) weekly demand.
- Non-explore path unchanged (`continue` on empty intel).

Diff: `diffs/k2_explore_base_price.ba1e644.diff` (product commit `ba1e644`). Prior writeup: `k2_cause_prior.md`.

## Test

`test_K2_explore_sails_without_opening_board`: no `seed_opening_board`; assert empty board; forced `_process_ship_day(..., explore=true)`; `sailed ≥ 1`.

## R9-73 / D-126
Spec does not define ranking when mid is missing; `base_price_li` stand-in remains **code kept**, status **gap/pending** (see `gaps.md`, `trace.csv`).
