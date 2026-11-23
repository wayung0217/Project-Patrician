---
cursor:
  subagentId: "bc-aea1f570-cf76-5f46-96c6-7de671190a6e"
---

# Step Z2 — G0H × ABUND 0/250000 × 5y

**Status:** 完成 (wall 373.6s, SCRIPT ERROR 0).  
**Tip:** same int `c13249e…`.

## Cross-table vs Z G0 (CITY_HOUSING=0)

| Metric | Z G0 (run0/1) | Z2 G0H (run0/1) |
|--------|---------------|-----------------|
| season_ports.md5 (both runs) | `2a5a05ef…` | **identical** `2a5a05ef…` |
| Y5 total beds | 34200 | 34200 |
| Y5 pop / shares | same as Z G0 | same |
| class / 3bars | FAIL | FAIL (same) |

**Interpretation:** `layers.CITY_HOUSING=1` produced **no** difference in season_ports vs G0 over 5y (no auto-housing builds; beds flat). Zone-open / built-ratio fields not separate CSV columns — OBS-01 queue strings match G0. WP-68 path either never armed (beggar/beds/cash gates) or output not distinguishing.

Artifacts: `M1b_G0H/` (+ `cmd_log.txt`).
