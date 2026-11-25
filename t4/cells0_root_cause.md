# COMPARED_CELLS=0 root cause (#85 run 45566106076)

- GOLDEN_BOOTSTRAP=0, both CSVs same bytes, IDENTICAL=1
- Old golden_compare early-returns on IDENTICAL without printing COMPARED_*
- #85 transplanted only ci.yml; gate parsed COMPARED_* solely from compare.out → cells=0

# Fix tip 9f228f0
ci.yml Compare step derives COMPARED_ROWS/COLS/CELLS from CSV DictReaders
(min rows × min cols); still requires CELLS == ROWS×COLS and >0.
