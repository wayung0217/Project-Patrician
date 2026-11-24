# K2 cause — explore hit→0 sail (17-63 / D-123(b))

## Cause
In `TraderRegistry._evaluate_and_maybe_sail`, every `(dest, good)` candidate required
`IntelLedger.board_for` to return `n≥1` with non-null `consensus_mid_li`.
At M1b cold start ST-BOARD was empty, so the coarse pass produced **zero** candidates.
Explore traders still set `decision.sail=true` when a best candidate existed — but
`pick_best_candidate([])` was empty, so they incremented idle and never sailed
(17-63 DIAG: explore_hit=2, sails=0).

## Fix
When `explore` and board intel is empty, use catalog `base_price_li` as a ranking
stand-in only (profit gate already skipped for explore). Destinations are still
filtered by enter/draft/voyage/afford/qty/`EXPLORE_QTY` and D-110(g) weekly demand.
Non-explore path unchanged (still requires board).

## Diff site
`autoload/trader_registry.gd` — `_evaluate_and_maybe_sail` intel empty branch.
