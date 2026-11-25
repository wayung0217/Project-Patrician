# review/1770-evidence3 — #87→main 合併前補證（B1–B5）

## Scope
- Tip accepted: `f86681e` (tree == `80d3d68`)
- CI run accepted: `45626685721` — **7 success + 2 skipped** (not 「9/9」)
- After this pack: merge-commit #87→main
- D-132: shard layout frozen; no further shard changes here

## B1 — tree equality
`b1/trees_and_log.txt` — `f86681e^{tree}` == `80d3d68^{tree}` = `539c8b18839136f9e7f08854548d5eadf8b8a2e3`

## B2 — run JSON
`b2/run_45626685721.json` (+ `.txt` with command wrapper) — headSha=`f86681e…`; conclusion=success
`b2/jobs_summary.txt` — 7 success + 2 skipped

## B3 — name-status vs main
`b3/name_status.txt` — only `.github/workflows/ci.yml` + `tools/golden_compare.py`

## B4 — golden + gate excerpts
`b4/golden_excerpt.txt` — GOLDEN_BASE_RUN_ID / BOOTSTRAP / ROWS×COLS / DIFF_CELLS
`b4/gate_excerpt.txt` — TOTAL_PASSING / BASELINE / REMOVED_NAMES

## B5 — intentional mismatch actual patch
`b5/0ec5feb_ci.yml.patch` + `b5/intentional_mismatch_patch.txt` — real `git show` patch of mutate-cell commit `0ec5feb`, then revert → `f86681e`

## Paths
- Store: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/1770-evidence3/`
- Orphan: `review/1770-evidence3`
