# T4 samples (D-130 甲(3))

## CI pass (run 45581664915 golden-30d)
See `ci_evidence/golden_ci_excerpt.txt`:
`GOLDEN_BOOTSTRAP=0` · `COMPARED_ROWS=527` · `COMPARED_COLS=19` · `COMPARED_CELLS=10013` · `DIFF_CELLS=0` · `DIMS_EQUAL=1` · `IDENTICAL=1`

## Local pass sample
`t4/compared_pass.out` — bootstrap CSV vs itself → IDENTICAL=1, COMPARED_CELLS=10013, exit 0.

## Local intentional content mismatch
`t4/compared_mismatch.out` — mutate one `note` cell → IDENTICAL=0, COL=note diff_cells=1, grid still 527×19=10013, exit 1.
