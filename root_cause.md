---
cursor:
  subagentId: "bc-5fbf00f4-2349-5889-a2a9-91f68700c107"
---

# 17-70 T3 — gut-unit(0) 35m cancel root cause

**Run:** https://github.com/wayung0217/Project-Patrician/actions/runs/45411941948  
**Tip:** `9b333c704c62fe00fe59ce1b67684de9b7e88948` (`tools-1769` / #86)  
**Product tip change:** **none** (H4 gap — fix not in `tools/`)

## Root cause (one line)

Byte-size 4-way shard packing parks the largest unit file `test_sys23_wp26.gd` (~49KB of multi-year/cli sims) on shard 0 (plus property after units); wall time >>35m and cancel mid `test_WP26_layer1_two_years_headers_and_counts` — runtime ≠ file bytes; fix needs `ci.yml` and/or `tests/unit` (L2), not `tools/`.

## Job wall times (run 45411941948)

| Job | Conclusion | Wall | GUT `Time` line |
|-----|------------|------|-----------------|
| gut-unit (0) | **cancelled** | **2117s (~35.3m)** | none (killed mid-run) |
| gut-unit (1) | success | 31s | 10.546s |
| gut-unit (2) | success | 22s | 5.245s |
| gut-unit (3) | success | 608s (~10.1m) | 580.999s |
| gut-ui | success | 168s | (ui) |
| golden-30d | success | 107s | — |
| gut-unit-gate | skipped | — | after cancel |

Annotation: `The job has exceeded the maximum execution time of 35m0s`.

## Shard packing (CI python; same as tip)

Size-greedy 4-way on `tests/unit/test_*.gd` by **file bytes**; shard 0 also appends all `tests/property/test_*.gd`.

| Shard | Unit scripts | Unit bytes | Property | Notable |
|-------|--------------|------------|----------|---------|
| 0 | 10 | 194744 | **5** | **`test_sys23_wp26.gd` 49063 B** (largest) |
| 1 | 10 | 195147 | 0 | — |
| 2 | 10 | 194484 | 0 | — |
| 3 | 11 | 194986 | 0 | `test_sim_loop.gd` + `test_market_pricer.gd` (~581s GUT) |

Shard 0 log: **0** `tests/property` mentions — property never started; cancel happened still inside `test_sys23_wp26.gd`.

## Slowest / heaviest evidence (shard 0)

GUT did not emit per-test wall times. Ranked from log + embedded sim `elapsed_ms` + cancel point:

| Rank | Test | Evidence |
|------|------|----------|
| 1 | `test_WP26_layer1_two_years_headers_and_counts` | **Started; no completion** — cancel at log EOF |
| 2 | `test_WP26_evidence_cli_twice_cmp` | Two full `sim_runner` CLI Godot subprocesses completed |
| 3 | `test_WP26_evidence_years10_player_arrears` | 10-year sim evidence (no elapsed row in window) |
| 4 | `test_TST_SYS23_09_print_summary_csv` | embedded elapsed **151977ms** + **70921ms** |
| 5 | `test_WP26_abort_summary_mets_blank` | embedded **117295ms** |
| 6 | `test_WP26_csv_integer_columns_no_dot` | same summary sample **117295ms** |
| 7–10 | other `test_WP26_evidence_*` / WP58 A3x in same script | multi-boot / write-fail paths before years10 |

Shard 1/2 finish in seconds; shard 3’s ~581s is dominated by large unit scripts (`sim_loop` / `market_pricer` / trade_desk) but **under** 35m.

## Why not a tools/ fix

- L5 ownership: **`tools/` only**. Timeout logic and shard selection live in **`.github/workflows/ci.yml`** (L2 / #84). Heavy cases live in **`tests/unit/test_sys23_wp26.gd`** (not L5).
- Lengthening `timeout-minutes` or skipping tests is **forbidden** by T3.
- #84 already tried 30→35→45m timeout bumps — that is not an allowed T3 fix path for L5.

## Gap (H4) — hand to L2

1. **Runtime-aware sharding** (or isolate `test_sys23_wp26.gd` / multi-year cases) in `ci.yml` — L2 owns.
2. Optionally split/move long SYS-23 evidence sims out of the default unit matrix — test owners / L2; not tools.
3. After L2 fix: re-run CI on #86 (or rebase #86 onto fixed main) for green evidence.

## Diff / corrected CI

| Item | Status |
|------|--------|
| Product diff | **empty** (no commit) |
| New tip | **same** `9b333c7` |
| Corrected CI run | **blocked** pending L2 ci.yml/test fix |
