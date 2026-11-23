# E3 — golden_compare I1/I2/I3 vs prior tip (per-column)

## Artifacts
| Tip | SHA | CSV md5 | Source |
|-----|-----|---------|--------|
| base (post-M 17-56 main) | `ce835f0` | `0ca3bf45e904f380d7f50677c68a685d` | evening-17-56 M2 pre_merge (= I1 prior) |
| I1 (#59) | `508da9d` | `995f4f37a8a43ff9dd4a3415277563bb` | evening-17-56 I1 golden_old_file (= post) |
| I2 (#60) | `40b13ad` | `b3af45cde1e10c6e0cdc0efc091bc51a` | regenerated @ tip (matches 17-56 md5) |
| I3 (#64) | `7d7ee47` | `52c1ef2b80d2d94f967d47928568e5f2` | regenerated @ tip (matches 17-56 md5) |

## I1 vs base (`I1/compare_vs_prior.txt`)
IDENTICAL=0; first diffs day=104:
| Column | first_diff_day | diff_cells | Which fix |
|--------|----------------|------------|-----------|
| city_balance_li | 104 | 54 | #59 WP-63 F3 garrison market-first buy (D-111(d)) — CITY cash when arms/powder buy succeeds |
| goods_stock_weeks_json | 104 | 66 | same F3 garrison buys alter MARKET stock weeks |
| goods_window_qty_json | 104 | 30 | same |
| buildings_json | 104 | 22 | WP-63 garrison/economy side-effects on building state encoding |

## I2 vs I1 (`I2/compare_vs_prior.txt`)
IDENTICAL=0; first wave day=90 (season city queue):
| Column | first_diff_day | diff_cells | Which fix |
|--------|----------------|------------|-----------|
| buildings_json | 90 | 2697 | #60 WP-65 city queue via order_build/order_upgrade (real BUILDING/WAITING + levels) |
| city_balance_li | 90 | 1176 | PUBLIC cash + upgrade fees consumed on start |
| goods_stock_weeks_json | 90 | 932 | CONSTRUCT_USE materials from MARKET |
| goods_window_qty_json | 90 | 225 | same |
| goods_mid_json | 90 | 16 | price response to stock draws |
| poor / citizen / residences_json | 180 | 243/237/245 | pop/housing drift after building/stock changes |
| beggar | 191 | 64 | same secondary |

## I3 vs I2 (`I3/compare_vs_prior.txt`)
IDENTICAL=0:
| Column | first_diff_day | diff_cells | Which fix |
|--------|----------------|------------|-----------|
| city_spend_json | 0 | 5776 | #64 WP-67 OBS-05 spend categories wired into golden |
| note | 0 | 5776 | harness OBS-05 settle gate / gap notes cleared or rewritten |
| buildings_json | 0 | 361 | spend-note / garrison F3 interaction on encoding |
| land_rent_li | 90 | 4336 | #64 OBS-05 land_rent_li column filled (was blank/gap) |
| vacancy_tax_li | 90 | 4336 | #64 OBS-05 vacancy_tax_li column filled |

I3 conflict resolution (E2) kept F3 market-first garrison while adding WP-67 spend taxonomy — column set expands without reverting I2 city-queue buildings path.
