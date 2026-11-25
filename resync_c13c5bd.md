【已被 Owner 追認取代】C-01 pending 已廢止；見 c01_github_ci_ownership_ratified.md（甲：`.github/ci/` 屬 Lane2 2.4）。

# Integration refresh — after Lane3 resync from Lane2 `c13c5bd`

## Lane2
- Tip: `c13c5bd8a64d3b3172ee578cf3ba50904be7c970` (D-124 FRM-SYS05-09 stock bound)
- vs prior `2e845b9`: product/tests only — `cash_ledger.gd`, `test_r972_cash_stock_cap_1769.gd`
- `.github/` unchanged → L3 no new transplant commit
- Orphan: tip `7625360dffee03919a805211ab689e37d09e75f3` body `c426e153c8bc635ad078ea8b2707f7fc8e713140`

## Lane3
- Tip still: `19280e75a23930f31785b26528be7cafdd481739`
- Evidence: `evening-17-69-lane3/retransplant_c13c5bd.md` — BYTE_MATCH ci.yml + baselines
- Orphan refreshed: tip `ab9758e718cfab2f447181babc653c1365cb8490` body `4117a1914e2a0a221c565ccda419ae8771fee2ef`

## C-01 pending — 【已被 Owner 追認取代】
- `.github/ci/*` (baseline names/paths) **not** in stated L2 ownership list → **C-01 pending Owner**
- Until accepted: `.github/ci/*` is **NOT merge evidence** (see `c01_github_ci_pending.md`)
- Same files ride on #85 via L3 transplant → C-01 also blocks treating them as merge evidence on int

## I1 re-check
- `c13c5bd` → current `origin/main` (`191a7ee6aaa0f03c0cb32d6a803105fca7f95ee9`): see `i1_l2_to_main/conflicts_c13c5bd.txt`

## No merge
