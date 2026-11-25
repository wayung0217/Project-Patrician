# review/1770-evidence2 — 17-70 補證一（E1/E2/E4/E5）

## Scope
- **Done here:** E1, E2, E4, E5 + orphan assemble (`review/1770-evidence2`).
- **E3/E6:** completed by D-130 agent `bc-660b892c-4e14-554e-9eb0-5de2ce68aeb7` — see E3/E6 section below.
- **No PR merges.** H1/S9b hold on 合併③ and #87→main.

## E1 — main 合併① `e07bb3c`
- Merge commit: `e07bb3c16347b30d68c3869203fc19d8ae345e1a` (parents in `e1/git_log_and_diff.txt`)
- CI run: `45581115843` — `e1/run_45581115843.json`
- Artifact `15005963963` (`golden-30d`) — `e1/artifacts_45581115843.json` (id/name/size/expires_at)
- Gate step log: `e1/gate_step_log.txt` (TOTAL_PASSING=558, ADDED 3× EX-05-09, REMOVED empty)
- Golden step log: `e1/golden_step_log.txt` (GOLDEN_GATE PASS; sha256 `8b25c951…`; rows=527 cols=19; wc -l=528)

## E2 — #85 tip `0b0e220`
- Tip: `0b0e22044b126559e3d5d54173358f81e44a304d`
- Git cmds+out: `e2/git_cmds.txt` (merge-base ancestor exit 0; ci.yml + baseline blob match e07bb3c)
- CI run: `45585429371` — `e2/run_45585429371.json` (conclusion=success)
- Gate: `e2/gate_step_log.txt`
- Golden: `e2/golden_step_log.txt` (GOLDEN_BASE_RUN_ID=45581115843; BOOTSTRAP=0; COMPARED_ROWS/COLS/CELLS=527/19/10013; DIFF_CELLS=0)
- WP27 三測試（MET01 / MET05b / OBS02）: `e2/gut_unit_wp27_three_tests.txt` — on this run size-balanced to **gut-unit (2)** (not (3)); all three `ok`. gut-unit(3) summary: `e2/gut_unit_3_summary.txt` (Passing Tests 154).

## E4 — orphan compare status (N-12)
All `status=ahead` (see `e4/status_summary.txt` + full API dumps):
- `b99d61d...a45dc73` → ahead
- `a45dc73...cf4d81c` → ahead
- `3d90e23...32f0a43` → ahead
- `bb830fa...76bacbf` → ahead（merge1 至 tip）

## E5 — expired annotations
Annotated copies under `e5/` (originals not deleted). In-place stamps on store `evening-17-69-lane3/lane.txt` and `evening-17-69-integration/{lane.txt,tips.txt}` pointing at e2/e1. Index: `e5/index.md`.

## E3/E6 — complete (D-130 agent bc-660b892c-4e14-554e-9eb0-5de2ce68aeb7)

### E3(a) diffs vs tip `80d3d68`
- `e3/a_name_status.txt`, `e3/a_full.diff`

### E3(b) success run `45620046075` tip `80d3d68`
- Run JSON: `e3/b_run_45620046075.json` (conclusion=success, 9/9)
- Gate: `e3/b_gate_excerpt.txt` — TOTAL_PASSING=558; BASELINE_NAMES_OK
- Golden: `e3/b_golden_excerpt.txt` — GOLDEN_BASE_RUN_ID=45581115843; BOOTSTRAP=0; COMPARED 527×19=10013; DIMS_EQUAL=1; IDENTICAL=1

### E3(c) intentional mismatch (real CI)
- Method: `e3/c_method.txt` — mutate first data-row last cell → `E3C_INTENTIONAL_MISMATCH` after golden write (commit `0ec5feb`); restore via `git revert` → tip `f86681e` (append-only, no force)
- Fail run: `45626300410` — `e3/c_run_45626300410.json`
- Fail golden: `e3/c_golden_fail_excerpt.txt` — E3C_MUTATED=1; IDENTICAL=0; DIFF_CELLS=1; exit 1; still BOOTSTRAP=0 / base run 45581115843

### E3(d) golden_compare.py
- `e3/d_golden_compare.py.txt` (no `min()`; DIMS_MISMATCH path)

### E3(e) shard rebalance walls
- Baseline tip `14b4363` run 45581664915: `e3/e_baseline_14b4363_walls.txt` — max_wall_s=2233 (gut-unit 0)
- After tip `80d3d68` run 45620046075: `e3/e_walls_80d3d68.txt` / `e3/e_walls_compare.txt` — max_wall_s=2078 (gut-unit 3); drop 155s
- Shard lists (CI): `e3/e_shard_lists_ci.txt` — wp26 only on shard3 with 1 property; shard0 has 2 property (no wp26 monopoly of all props)

### E6 no-bootstrap (N-15)
- Diff: `e6/e6_ci_yml.diff.txt`
- Success golden: `e6/e6_success_golden_excerpt.txt` — GOLDEN_BASE_RUN_ID=45581115843; GOLDEN_BOOTSTRAP=0; no bootstrap path taken
- Run JSON: `e6/e6_run_45620046075.json`

#87 tip after E3(c) restore: `f86681e672c030298c4660e3ca9a7b229c11661c` (revert of e3c; ci.yml tree == `80d3d68`). Success evidence tip remains `80d3d68`. No merge.

## Paths
- Store: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/1770-evidence2/`
- Orphan: `review/1770-evidence2`
