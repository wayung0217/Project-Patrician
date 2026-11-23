# E5 — 17-56 M1 `csv_import` demand abort

## Symptom (logged)
`evening-17-56/stepM/M1/csv_import.log`:
```
ERROR: demand batch: rate_scale／ppm_scale／weight_sum must be > 0 (PRM-SYS06-*)
  at: _abort_batch (csv_import.gd:2163)
  from: run_batch_demand (csv_import.gd:1177)
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.  (/tmp/run_csv_import.gd:19)
```

## Cause
`tools/csv_import.gd` `run_batch_demand` (≈1173–1177) aborts when any of `rate_scale` / `ppm_scale` / `weight_sum` is `<= 0`. Defaults on the static func are all `0`. The CLI wrapper `_go` path reads scales via `_read_demand_scales_from_params()` from `res://data/params/params.json` (`PRM-SYS06-RATE_SCALE` / `PPM_SCALE` / `WEIGHT_SUM`).  

In the M1 one-shot `/tmp/run_csv_import.gd` run, scales arrived as 0 (params not loaded / read failed / wrapper passed defaults), so demand batch aborted before writing demand tres. The follow-on SCRIPT ERROR is wrapper noise (`int(...)` on a bad return), not product.

Formal `data/params/params.json` on main today has RATE_SCALE=100, PPM_SCALE=1000000, WEIGHT_SUM=100 — a correct call succeeds.

## What later 17-56 tests used
- **GUT unit+property / UI / golden** did **not** depend on re-running that aborting CLI import. They boot against **already-committed formal `res://data/**` tres** (and per-test fixtures under `tests/`), including pre-existing demand_rates / satisfaction_weights / substitutions trees.
- M1 report: GUT 493/493 SE=0; UI 4/4 SE=0 (after retry); golden ERROR=0 — all on committed formal+fixture data, not on a freshly imported demand batch from that failed CLI.
- WP-65 formal asserts additionally `git checkout HEAD --` data trees mid-suite (d6bb0a6) when other tests wipe them.

## Gap note (C-05)
None for product: abort is correct guard when scales are 0. M1 wrapper must pass `_read_demand_scales_from_params()` results (or fail loudly before `run_batch_demand`). Not a docs/spec gap.
