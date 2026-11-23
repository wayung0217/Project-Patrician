---
cursor:
  subagentId: "bc-aea1f570-cf76-5f46-96c6-7de671190a6e"
---

# Step Z4 — G0 ABUND0 × CITY_HOUSING 0/1 × 10y

**Status:** 完成 (H0 297.0s, H1 318.9s). Season for Y10 criteria sample: **39**.

## 10y cross-table (WP-68 acceptance)

| | H0 (`M1b_G0_10y_H0`) | H1 (`M1b_G0H_10y`) |
|--|----------------------|---------------------|
| wall_s | 296.95 | 318.89 |
| season_ports row diffs | — | **0 / 640** (identical) |
| Y10 pop | 20073 | 20073 |
| rich/cit/poor/beg % | 5.77 / 23.15 / 63.66 / 7.43 | same |
| beds | (unchanged path) | same as H0 |
| class / 3bars @ s39 | FAIL | FAIL |

**Conclusion:** 10y CITY_HOUSING on/off **identical** outputs — no measured auto-housing or zone-sequence divergence in exported CSVs. Matches Z2 5y finding.
