report.md
# 17-91 Lane P DIAG-INFO report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
Bounds: no merge / no PR / no force-push / facts only (B-7).  
Product pin `25a398492fa568a223fb4802adbb4f15bc40bcbb`. Probe branch `diag-info-1791` (deleted after pack).

## Delivered

- p0-baseline.txt … p11-skip-and-routes.txt, failed-runs.txt, lane.txt, report.md
- p1-probe-diff.txt (+ split parts if present)
- artifacts/d360_s1|s2|s3 (+ probe raw)
- orphan_sha.txt / orphan_push.log / verify-branch-deleted.txt (S9d)

## Actions

| what | id | status |
|------|-----|--------|
| M1b-Diag-Info-1791 | [46116345696](https://github.com/wayung0217/Project-Patrician/actions/runs/46116345696) | completed success (3/3) |

## Probe branch

- Created `diag-info-1791` from `25a398492fa568a223fb4802adbb4f15bc40bcbb`
- SHA Actions `2e5e7ecbbe51f988be04a879238bd5c29bbe51b4`
- Workflow `.github/workflows/diag-info-1791.yml` (paths filter + seeds 1/2/3 matrix)
- No PR opened
- Deleted after pack assembly (authorized B-5)

## CPU (B-8)

| job | cpu_model | duration_s |
|-----|-----------|------------|
| seed1 | INTEL(R) XEON(R) PLATINUM 8573C | 988 |
| seed2 | AMD EPYC 7763 64-Core Processor | 1158 |
| seed3 | AMD EPYC 9V74 80-Core Processor | 893 |

## P0 baseline

```
PRODUCT_BASE=25a398492fa568a223fb4802adbb4f15bc40bcbb
PRODUCT_TREE=adc21ebce033a02bd00f5225dca1d5a717fe0dc9
TRADER=bdb1601f212a2f286033596cddc2d0fbd5a1819c
INTEL=bf057cf9551c155b6117425e30fb572a3e0d28d8
GOODS=c41cd983db11cf280a6939cd14a0dcfdbadc6bb1
BLOB_MATCH=yes (all three)
```

## P2 determinism vs overnight-17-90-P d360 seed1

```
PROGRESS: 34451/1024, 34429/1960, 34092/3109, 33717/4054 — equal
season_ports.csv / trader_summary.csv — byte_identical=True
P2_DETERMINISM=PASS
PROBE_CHANGED_OUTPUT=no
```

## Seed1 five-port OUT / IN

```
OUT PT-04/05/08/09/11 = 89/52/94/37/4
IN  PT-04/05/08/09/11 = 84/42/91/35/0
```

## skip.* job totals (seed1)

```
skip.market_qty=5868735
skip.no_intel=3369603
skip.weekly_demand=168924
skip.decide_idle=22183
skip.afford=3299
skip.other=47
skip.no_intel.n0=3369603
skip.no_intel.n_ge1=0
```

## S9a A 基線

```
BRANCH=diag-info-1791 (temp; deleted)
HEAD_SHA=2e5e7ecbbe51f988be04a879238bd5c29bbe51b4
BASE_SHA=25a398492fa568a223fb4802adbb4f15bc40bcbb
NO_PR=yes
NO_FORCE_PUSH=yes
```
