# After — same-commit timing on tip `93ddd62` (run 45363142979)

Times Asia/Hong_Kong (UTC+8). Source: Actions jobs API.

**Same commit as merge parent of #82** (`93ddd62`); merge-commit `9d293ff` post-push run [45368037707](https://github.com/wayung0217/Project-Patrician/actions/runs/45368037707) was **cancelled** — use this green PR run for after timing.

**Run:** https://github.com/wayung0217/Project-Patrician/actions/runs/45363142979  
**Wall (critical path):** ~**21 min** (gut-unit shard 0 / 20.7–20.9) — run start 17:13 → gate end 17:34 HKT  
**Target ≤15m:** **NOT MET** (~21m vs 15m); vs S0 outlier **38.5 min** and typical **7–8 min** sequential unit+UI job.

| Job | Conclusion | Duration | Notes |
|-----|------------|----------|-------|
| gut-unit (0) | success | **20.7 min** | size-balanced; includes property |
| gut-unit (1) | success | 0.5 min | |
| gut-unit (2) | success | 0.4 min | |
| gut-unit (3) | success | 7.8 min | |
| gut-unit-gate | success | 6 s | Passing sum **555** |
| gut-ui | success | 2.7 min | Passing **6** |
| golden-30d | success | 1.6 min | sha identical to pre |
| m1b-h4-smoke | skipped | — | S6: not tools/int push |
| m1b-w4-inline-cmp | skipped | — | S6: not tools/int push |

## Test / golden gates

| Metric | Pre (main #77 / tools-1758 golden) | After (PR tip) | Match |
|--------|-------------------------------------|----------------|-------|
| unit+property Passing | 555 | 555 (133+156+141+125) | yes |
| UI Passing | 6 | 6 | yes |
| golden sha256 | `8b25c951…` | `8b25c951…` | IDENTICAL=1 |
| golden rows/cols/bytes | 527 / 19 / 2270766 | same | yes |

## Top steps (after)

1. gut-unit (0) full job — 20.7 min  
2. gut-unit (3) — 7.8 min  
3. gut-ui Run GUT UI — ~2.5 min inside 2.7 min job  
4. golden 30d gated — ~1 min inside 1.6 min job  
5. Import (cached) — ~7–10 s per job  
