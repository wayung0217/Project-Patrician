# review/1770-d130 — D-130 甲 FINAL

## Product
- PR: https://github.com/wayung0217/Project-Patrician/pull/87
- Tip: `14b436342849d8d6a4dc32eb63703a2133bddfd0`
- CI: https://github.com/wayung0217/Project-Patrician/actions/runs/45581664915 — **9/9 success**
- **不合併**（等 Owner 批；須在合併⑤ #86 前）

## Gate
```
REMOVED_NAMES: 無
ADDED_NAMES: 三 EX
TOTAL_PASSING=558
shard_passing: 140/140/139/139
```

## COMPARED_*
`GOLDEN_BOOTSTRAP=0` · `COMPARED_ROWS=527` · `COMPARED_COLS=19` · `COMPARED_CELLS=10013` · `DIFF_CELLS=0` · `DIMS_EQUAL=1`

## T4
- 通過：`ci_evidence/golden_ci_excerpt.txt` + `t4/compared_pass.out`
- 故意不符：`t4/compared_mismatch.out`（note 一格；exit 1）
