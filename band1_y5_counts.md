# BAND-1 — Y5 band0 / mid / band4 counts (z-1758-2)

Source: Actions run [45356709933](https://github.com/wayung0217/Project-Patrician/actions/runs/45356709933) per-group `m1b-z-*` artifacts → `season_cells.csv`.
Filter: `season_index == 19` (Y5). **mid** = band ∈ {1,2,3}. No `season_cells.csv` bodies on orphan.

## Band labels (W8 / 補正三)

| Band | Meaning |
| --- | --- |
| **band0** | 價格**天花板**（缺貨，weeks `w < 1`） |
| **mid** | 中間帶（band 1–3） |
| **band4** | 價格**地板**（過剩，weeks `w ≥ 10`） |

**Dominance (Y5):** **地板為主（87.3%）** — band4 cells ≈ 391/448 across groups (not 天花板為主). band0 is the thin shortage edge (~42–44/448).

| Group | band0 (天花板) | mid | band4 (地板) | Y5 cells | band0+4% | band4% |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Za_G0_A0 | 42 | 15 | 391 | 448 | 96.7 | 87.3 |
| Za_G0_A250 | 44 | 13 | 391 | 448 | 97.1 | 87.3 |
| Za_G1_A0 | 44 | 12 | 392 | 448 | 97.3 | 87.5 |
| Za_G1_A250 | 43 | 13 | 392 | 448 | 97.1 | 87.5 |
| Za_G2_A0 | 42 | 15 | 391 | 448 | 96.7 | 87.3 |
| Za_G2_A250 | 44 | 13 | 391 | 448 | 97.1 | 87.3 |
| Zb_G0_notrader | 42 | 15 | 391 | 448 | 96.7 | 87.3 |
| Zc_G0H_A0 | 42 | 15 | 391 | 448 | 96.7 | 87.3 |
| Zd_G0_seed2 | 42 | 15 | 391 | 448 | 96.7 | 87.3 |

Machine-readable: `band1_y5_counts.csv`.
