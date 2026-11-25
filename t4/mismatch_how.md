# T4 samples (D-130 甲(3))

## Pass
`t4/compared_pass.out` — identical bootstrap CSV vs itself.
`COMPARED_ROWS=527` `COMPARED_COLS=19` `COMPARED_CELLS=10013` `IDENTICAL=1` exit 0.

## Intentional content mismatch
`t4/compared_mismatch.out` — mutate one `note` cell.
`IDENTICAL=0` `diff_cells=1` on COL=note; grid still 527×19=10013; exit 1.

## Intentional dims mismatch (D-130 甲(2))
`t4/compared_dims_mismatch.out` — drop one data row.
`DIMS_MISMATCH rows_a=527 rows_b=526` → `COMPARED_*=0` exit 1.
