---
cursor:
  subagentId: "bc-aea1f570-cf76-5f46-96c6-7de671190a6e"
---

# step_int int-1755 (pack 17-55)

## A
Branch `cursor/int-1755-merge-0a6e` @ `c13249e65181bb0bb38a6005a4aed9b84abaa7a2`.  
Draft PR **#76** base=`cursor/step0-m1b-params-data-0638` (`ef70d42…`).  
Merge order C → D → B → A; **E skipped** (D-115). Merge commits only.

## B — Conflicts
All four merges: clean `ort`, **no conflicts** (`git show --cc` = ordinary merge stats; parents listed in `merges/`).

| Merge | Tip merged | Int SHA after | Conflicts |
|-------|------------|---------------|-----------|
| C #74 | `7101e9c…` | `8a02133…` | none |
| D #75 | `8603d8c…` | `5d5d31f…` | none |
| B #73 | `6b38ae0…` | `494a696…` | none |
| A #72 | `14b22ee…` | `c13249e…` | none |
| E | — | — | skipped (agent RUNNING; no tip/PR) |

## C — Gates
| After | GUT | SCRIPT ERROR | Golden gate | golden_compare vs prev |
|-------|-----|--------------|-------------|------------------------|
| C | 532/532 | 0 | PASS | ≡ step0 / laneC |
| D | 544/544 | 0 | PASS | ≡ C (CITY_HOUSING=0) |
| B | 555/555 | 0 | PASS | diffs — **lane B** |
| A | 576/576 | 0 | PASS | ≡ post-B |

### Lane B golden diffs (owning lane = B)
| Column | first_diff_day | diff_cells |
|--------|----------------|------------|
| poor | 96 | 740 |
| citizen | 89 | 671 |
| rich | 89 | 272 |
| beggar | 93 | 610 |
| city_balance_li | 90 | 1175 |
| goods_mid_json | 1 | 3143 |
| goods_stock_weeks_json | 1 | 5509 |
| goods_window_qty_json | 9 | 1111 |
| buildings_json | 1 | 360 |
| residences_json | 89 | 796 |

Lane A golden identical to post-B (golden harness does not enable traders).

## D–I
See `merges/`, `golden/`, `gaps.md`, `cmd_log.txt`, `commits.txt`, `int_tip.txt`. No merge to main.
