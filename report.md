# review/1770-evidence2 — 17-70 補證一（E1/E2/E4/E5）

## Scope
- **Done here:** E1, E2, E4, E5 + orphan assemble (`review/1770-evidence2`).
- **E3/E6:** produced by D-130 agent `bc-660b892c-4e14-554e-9eb0-5de2ce68aeb7`; partial files present under `e3/` `e6/` and listed in `manifest.txt`. Remaining E3(b)(c)(e-post-rebalance) / E6 success-run golden excerpt **待補** (see below).
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

## E3/E6 — 待補 / partial
Present now (from D-130 sibling):
- `e3/a_name_status.txt`, `e3/a_full.diff` (vs tip `80d3d68…`)
- `e3/d_golden_compare.py.txt`
- `e3/e_baseline_14b4363_walls.txt` (pre-rebalance walls; max_wall_s=2233 on gut-unit(0))
- `e6/e6_ci_yml.diff.txt` (bootstrap removal + E3e shard weight)

Still **待補** when sibling finishes:
- E3(b) success-run gate+golden 原文段（post-`80d3d68` green run）
- E3(c) intentional mismatch CI run + golden fail 原文
- E3(e) post-rebalance shard file lists + started_at/completed_at proving wall drop + wp26 not alone
- E6 success-run golden 原文段 showing baseline from main artifact run id (no BOOTSTRAP)

#87 tip at pack time: `80d3d68faaf9498b917e57d77be332c1d073e0a5` (CI in flight / see sibling). Append-only to this orphan when those land (N-12).

## Paths
- Store: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/1770-evidence2/`
- Orphan: `review/1770-evidence2`
- Manifest: `manifest.txt`


## Orphan tip
- Pack: `83e2f19d260c15c2b8416d44debac50629212c6d`
- Tip (current): `3babae64d4e88ab51f01e8679f14e6f469f8e08a` (stamp of `5fecbcf…`; pack root `83e2f19…`)
- True orphan (root has no parent). Initial remote tip was mistakenly `e07bb3c` (empty product tip); one-time force replace with this orphan pack so N-12 append history starts clean. Subsequent updates must append only.
