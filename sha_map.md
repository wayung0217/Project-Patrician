# SHA map — 8456c57 vs #84 / #83 / #85 tips

Assembled HKT 2026-11-24 ~22:12 (Asia/Hong_Kong). Full SHAs.

## Anchor

| Label | Full SHA | Role |
| --- | --- | --- |
| `8456c57` | `8456c57f8f0a331ce4224741e433839a619321cb` | First 17-67 commit on #84: stock-cap + S1/S2 + timeouts + **actions all `@v5`** |
| `origin/main` | `9d293ff8e67f7b224ac33147f802a53492ffbd5b` | #84 base (ci-speed merge #82) |
| `origin/int-1758` | `71b094d773125cc96ee66ff65691d5219a22eedf` | #85 / #83 base |

## #84 `cursor/ci-hang-1767-866d` (base `main`)

| Short | Full SHA | Subject |
| --- | --- | --- |
| `8456c57` | `8456c57f8f0a331ce4224741e433839a619321cb` | cap max_affordable by stock; S2+timeouts+Node24 CI (**@v5**) |
| `e38aea5` | `e38aea52f50963172fb0debfe04893360f4ffa69` | bump actions to Node-24 majors (**@v7/@v6/@v7/@v8**) |
| `76d8a93` | `76d8a9360e613a40be4b72feb5c64453b2572c10` | stock-cap only when quote provider is MarketPricer |
| **tip `1a3e5f1`** | `1a3e5f144a99fbcb157c14e7766d6da42c121714` | WP27 unload BuildingEconomy between tests |

## #85 `cursor/int-ci-1767-866d` (base `int-1758`)

| Short | Full SHA | Subject |
| --- | --- | --- |
| `5f024d7` | `5f024d7408f3e20a8fa21682757c105eab1cd133` | int tree CI S1/S2/timeouts + max_affordable stock cap (**@v5** port) |
| `4cdb91a` | `4cdb91a9f6c42d3c42e84d8416cbcb22655c6b6e` | bump actions to Node-24 majors (**@v7/@v6/@v7/@v8**) |
| `933cd3d` | `933cd3d7c700a6c56075822af538067c6adc8d3f` | stock-cap only when quote provider is MarketPricer |
| **tip `0b279d5`** | `0b279d553124f7056ff265bbeccbd80045cdeb78` | WP27 unload BuildingEconomy; int GUT gate 600 |

## #83 `cursor/m1b-fix-1766-3fe3` (base `int-1758`, sibling)

| Short | Full SHA | Note |
| --- | --- | --- |
| **tip `51cc942`** | `51cc942bbb23cfc0f51f8b0e1fa0e79fb3c9424c` | D-123 opening-board tip (K4 shrink); not Lane1 product work |

## Cross-walk

```
main 9d293ff ──► 8456c57 ──► e38aea5 ──► 76d8a93 ──► 1a3e5f1  (#84 tip)
                     │            │
                     │            └── tip majors (not 8456c57)
                     └── actions = all @v5  ← report truth

int-1758 71b094d ──► 5f024d7 ──► 4cdb91a ──► 933cd3d ──► 0b279d5  (#85 tip)
                         │
                         └── @v5 then tip majors via 4cdb91a
```
