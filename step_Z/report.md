---
cursor:
  subagentId: "bc-aea1f570-cf76-5f46-96c6-7de671190a6e"
---

# Step Z — M1b 6×5y + G0 traders-off

**Int tip:** `c13249e65181bb0bb38a6005a4aed9b84abaa7a2`  
**Scenarios:** `user://scenarios_z/` copies (stripped ABUND override∩grid; G-INT-03).  
**Status:** all **完成** (SCRIPT ERROR 0; aborted=0).

## Runs

| Group | wall_s | combos | notes |
|-------|--------|--------|-------|
| M1b_G0 | 399.1 | 2 (ABUND 0/250k) | |
| M1b_G1 | 377.8 | 2 | |
| M1b_G2 | 377.5 | 2 | |
| M1b_G0_traders_off | 186.0 | 1 (ABUND 0) | layer TRADERS=0; ≈½ of G0 wall |

Outputs per group: `summary.csv`, `season_ports.csv`, `season_cells.csv`, `obs_ext.csv`, `trader_summary.csv`, `timing.txt`, `commit_sha.txt`.

## draft_class_test C (Y5 = season 19) + M1b three bars

Opening total pop **34200**. Class bands: rich 3–8%, citizen 20–40%, poor ≥45%, beggar ≤10%, pop ≥90% open.

| Group | run | rich% | cit% | poor% | beg% | pop | class | floor+ceil% (band0\|4) | tier order | cash¬mono | 3bars |
|-------|-----|-------|------|-------|------|-----|-------|------------------------|------------|-----------|-------|
| G0 | 0 | 5.82 | 22.04 | 66.64 | 5.50 | 20365 | FAIL (pop) | 96.7 | OK | OK | FAIL |
| G0 | 1 | 6.02 | 22.71 | 65.34 | 5.93 | 19866 | FAIL | 97.1 | OK | OK | FAIL |
| G1 | 0 | 5.98 | 16.70 | 71.77 | 5.55 | 20277 | FAIL (cit+pop) | 97.3 | OK | OK | FAIL |
| G1 | 1 | 6.03 | 17.31 | 70.72 | 5.94 | 19931 | FAIL | 97.1 | OK | OK | FAIL |
| G2 | 0 | 5.85 | 22.05 | 66.61 | 5.49 | 20349 | FAIL (pop) | 96.7 | OK | OK | FAIL |
| G2 | 1 | 5.95 | 22.67 | 65.45 | 5.93 | 19901 | FAIL | 97.1 | OK | OK | FAIL |
| traders_off | 0 | 5.82 | 22.04 | 66.64 | 5.50 | 20365 | FAIL | 96.7 | OK | OK | FAIL |

**Verdict:** No group meets class pop floor (~60% of open) or floor/ceiling ≤30% (most cells band=4 過高). Tier order preserved; city cash not globally monotone. Full JSON: `analysis.json`.

## Traders / perf (D-104(c)⑤)

G-INT-01: `set_layers` never called → traders never enabled.  
`elapsed_ms` G0 ABUND0 **200594** vs traders_off **183413** (~9% wall; not a real trader delta). `trader_summary` sail/cargo near zeros.

## First attempt
Committed scenarios hit ERR-SYS23-04 (ABUND in overrides+grid); logged; rerun with user:// fix.
