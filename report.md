report.md
# 17-87 Lane P DIAG-PERF-4 report

ASOF_HKT=2026-11-28 01:33:43 Asia/Hong_Kong  
main tip `dcea87f338f3bea4b49197ce3cbb1c407a28a250`  
probe `perf-probe-1787` @ `7d0c4ad049859db17ec29bf584f8677c707eadd1`  
Bounds: no merge / no PR / no optimize / facts only.

## Delivered

- `p1-granularity.txt`
- `p2-afford-inner.txt`
- `p3-board-for.txt`
- `p4-opening-place.txt`
- `p5-no-intel.txt`
- `p6-overhead-determinism.txt`
- `lane.txt`
- `report.md` — this file
- `artifacts/` — Actions extracts

## Actions

| what | id | status |
|------|-----|--------|
| M1b-Perf-Probe-1787 | [46033150459](https://github.com/wayung0217/Project-Patrician/actions/runs/46033150459) | completed success (3/3 jobs) |

## Probe branch

- Created `perf-probe-1787` from `dcea87f338f3bea4b49197ce3cbb1c407a28a250` (cherry-pick 17-86 `2d028c3` then extend)
- SHA Actions `7d0c4ad049859db17ec29bf584f8677c707eadd1`
- No PR opened
- Deleted after pack assembly (authorized B-5)

## CPU by job (B-11)

| job | cpu_model | notes |
|-----|-----------|-------|
| probe-za-d60 | Intel(R) Xeon(R) 6975P-C | P1–P5; summary elapsed_ms=1237918 |
| probe-overhead-d10 | Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz | P6a 6× ELAPSED_MS |
| probe-determinism-d90 | AMD EPYC 9V74 80-Core Processor | P6b; do not cross-compare timings |

## P1 pointers (raw in p1-granularity.txt)

- job_afford_calls=1069350; job_board_calls=1066080
- afford_mismatch_total=0; board_mismatch_total=0
- board_dest_same=25567; board_dest_diff=1040070
- d10/d30/d60 per-eval distributions + d1–d60 PERF_P1_DAY lines in file

## P2 pointers (raw in p2-afford-inner.txt)

- job: s0=0 all_s=705180 cant1=3270 search=360900
- search quote_n median=19; quote_usec median=1055; rest_usec median=41

## P3 pointers (raw in p3-board-for.txt)

- board_for usec_inc=135870647 usec_exc=11628655 calls=1066080
- residual exclusive ≤ 10% inclusive; children: visible_samples / vs.loop / actor_present.ships / summarize_board
- PERF_P3_ALLOC dict=3789338 array=2132160 duplicate=0

## P4 pointers (raw in p4-opening-place.txt)

- 16 PERF_P4_PORT lines (usec, residents, residences, work_buckets=0)
- score_loop dominates opening_place

## P5 pointers (raw in p5-no-intel.txt)

- skip.no_intel code + PRM values + FRM refs + PERF_P5_CELLS d1–d60

## P6 pointers (raw in p6-overhead-determinism.txt)

- 6 ELAPSED_MS (甲/乙/丙 × 2) on 8370C
- d90 season_ports/cells/trader_summary + stripped summary: all identical=True

## Orphan delivery (S9d)

- branch: `review/overnight-17-87-P`
- full SHA: `c6e206643a71fb703098d2a4f8d0be8b845ecb88`
- `orphan_sha.txt` / `orphan_push.log` at pack root
- ls-tree: `artifacts/orphan-ls-tree.txt`

## Failed runs

None (workflow conclusion=success; all jobs exit 0).

## B-10 FILES_TOTAL

```
total 73
drwxrwxrwx 2 ubuntu ubuntu     0 Nov 27 16:14 .
drwxrwxrwx 2 ubuntu ubuntu     0 Nov 27 16:14 ..
drwxrwxrwx 2 ubuntu ubuntu     0 Nov 27 16:14 artifacts
-rw-rw-rw- 1 ubuntu ubuntu   426 Nov 27 17:36 lane.txt
-rw-rw-rw- 1 ubuntu ubuntu  6352 Nov 27 17:36 orphan_push.log
-rw-rw-rw- 1 ubuntu ubuntu    41 Nov 27 17:36 orphan_sha.txt
-rw-rw-rw- 1 ubuntu ubuntu 20685 Nov 27 17:33 p1-granularity.txt
-rw-rw-rw- 1 ubuntu ubuntu  2046 Nov 27 17:33 p2-afford-inner.txt
-rw-rw-rw- 1 ubuntu ubuntu 14614 Nov 27 17:33 p3-board-for.txt
-rw-rw-rw- 1 ubuntu ubuntu  3413 Nov 27 17:33 p4-opening-place.txt
-rw-rw-rw- 1 ubuntu ubuntu 12885 Nov 27 17:33 p5-no-intel.txt
-rw-rw-rw- 1 ubuntu ubuntu  5095 Nov 27 17:33 p6-overhead-determinism.txt
-rw-rw-rw- 1 ubuntu ubuntu  6595 Nov 27 17:36 report.md

artifacts/orphan-ls-tree.txt
artifacts/probe-determinism-d90/det_clean/commit_sha.txt
artifacts/probe-determinism-d90/det_clean/runner_specs.txt
artifacts/probe-determinism-d90/det_clean/season_cells.csv
artifacts/probe-determinism-d90/det_clean/season_ports.csv
artifacts/probe-determinism-d90/det_clean/summary.csv
artifacts/probe-determinism-d90/det_clean/timing.txt
artifacts/probe-determinism-d90/det_clean/trader_summary.csv
artifacts/probe-determinism-d90/determinism_compare.txt
artifacts/probe-determinism-d90/det_probe/commit_sha.txt
artifacts/probe-determinism-d90/det_probe/runner_specs.txt
artifacts/probe-determinism-d90/det_probe/season_cells.csv
artifacts/probe-determinism-d90/det_probe/season_ports.csv
artifacts/probe-determinism-d90/det_probe/summary.csv
artifacts/probe-determinism-d90/det_probe/timing.txt
artifacts/probe-determinism-d90/det_probe/trader_summary.csv
artifacts/probe-overhead-d10/overhead_r1_bing_full/label.txt
artifacts/probe-overhead-d10/overhead_r1_bing_full/runner_specs.txt
artifacts/probe-overhead-d10/overhead_r1_bing_full/summary.csv
artifacts/probe-overhead-d10/overhead_r1_bing_full/timing.txt
artifacts/probe-overhead-d10/overhead_r1_jia_clean/label.txt
artifacts/probe-overhead-d10/overhead_r1_jia_clean/runner_specs.txt
artifacts/probe-overhead-d10/overhead_r1_jia_clean/summary.csv
artifacts/probe-overhead-d10/overhead_r1_jia_clean/timing.txt
artifacts/probe-overhead-d10/overhead_r1_yi_outer/label.txt
artifacts/probe-overhead-d10/overhead_r1_yi_outer/runner_specs.txt
artifacts/probe-overhead-d10/overhead_r1_yi_outer/summary.csv
artifacts/probe-overhead-d10/overhead_r1_yi_outer/timing.txt
artifacts/probe-overhead-d10/overhead_r2_bing_full/label.txt
artifacts/probe-overhead-d10/overhead_r2_bing_full/runner_specs.txt
artifacts/probe-overhead-d10/overhead_r2_bing_full/summary.csv
artifacts/probe-overhead-d10/overhead_r2_bing_full/timing.txt
artifacts/probe-overhead-d10/overhead_r2_jia_clean/label.txt
artifacts/probe-overhead-d10/overhead_r2_jia_clean/runner_specs.txt
artifacts/probe-overhead-d10/overhead_r2_jia_clean/summary.csv
artifacts/probe-overhead-d10/overhead_r2_jia_clean/timing.txt
artifacts/probe-overhead-d10/overhead_r2_yi_outer/label.txt
artifacts/probe-overhead-d10/overhead_r2_yi_outer/runner_specs.txt
artifacts/probe-overhead-d10/overhead_r2_yi_outer/summary.csv
artifacts/probe-overhead-d10/overhead_r2_yi_outer/timing.txt
artifacts/probe-overhead-d10/overhead_summary.txt
artifacts/probe-za-d60/commit_sha.txt
artifacts/probe-za-d60/perf_p1.log
artifacts/probe-za-d60/perf_p2.log
artifacts/probe-za-d60/perf_p3.log
artifacts/probe-za-d60/perf_p4.log
artifacts/probe-za-d60/perf_p5.log
artifacts/probe-za-d60/runner_specs.txt
artifacts/probe-za-d60/summary.csv
artifacts/probe-za-d60/timing.txt
artifacts/remote-heads-at-start.txt
lane.txt
orphan_push.log
orphan_sha.txt
p1-granularity.txt
p2-afford-inner.txt
p3-board-for.txt
p4-opening-place.txt
p5-no-intel.txt
p6-overhead-determinism.txt
report.md

FILES_TOTAL=61
```

FILES_TOTAL=61
