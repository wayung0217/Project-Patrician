# CI outcome — tip `9f3effd` (transplant of Lane2 `9f228f0`)

Run: https://github.com/wayung0217/Project-Patrician/actions/runs/45569611882

## golden-30d — SUCCESS (T4 fix confirmed)
- IDENTICAL=1
- COMPARED_ROWS=527 COMPARED_COLS=19 COMPARED_CELLS=10013 DIFF_CELLS=0
- GOLDEN_BOOTSTRAP=0 (main artifact)
- Prior tip `d57631b` had COMPARED_CELLS_INVALID cells=0 — fixed by Lane2 T4 tip `9f228f0`

## gut-unit (3) — FAILURE (D-120(e) / WP27 — out of Lane3)
- `test_sys23_wp27.gd`: Unexpected Errors ERR-SYS08-08 season not settled (OBS-05)
- No Lane3 product fix; wait #84→main→int (WP27)

## Other
- gut-unit (0)(1)(2), gut-ui: SUCCESS
- No merge

## Prior tips
See prior excerpts for `d57631b` / `da3d911`.
