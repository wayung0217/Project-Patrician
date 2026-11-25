# CI — tools-1769 / #86 (17-69 L5)

Tip: `9b333c704c62fe00fe59ce1b67684de9b7e88948`

## Runs (H3 — every run)

| Run | Event | Conclusion | URL |
|-----|-------|------------|-----|
| 45411941948 | pull_request | **cancelled** (shard timeout) | https://github.com/wayung0217/Project-Patrician/actions/runs/45411941948 |

## Jobs (run 45411941948)

| Job | Conclusion | Note |
|-----|------------|------|
| gut-ui | success | 2m48s |
| gut-unit (1) | success | 31s |
| gut-unit (2) | success | 22s |
| gut-unit (3) | success | 10m8s |
| golden-30d | success | 1m47s |
| **gut-unit (0)** | **cancelled** | exceeded 35m timeout → run cancelled |
| m1b-h4-smoke | skipped | push-branch gate (PR event) |
| m1b-w4-inline-cmp | skipped | push-branch gate (PR event) |
| gut-unit-gate | skipped | after shard fail/cancel |

## Fail excerpt (H2)

Annotation on gut-unit (0):

```
The job has exceeded the maximum execution time of 35m0s
The operation was canceled.
```

Job: https://github.com/wayung0217/Project-Patrician/actions/runs/45411941948/job/138507801828

## Lane 5 note

- Diff is **tools/ only** (`run_m1b_report.gd`, `run_m1b_README.md`) — cannot touch `ci.yml` / hang fix (Lane 2 ownership).
- Pre-existing gut-unit hang / shard imbalance (17-67 / 17-69 L2). Not introduced by SEED_NO_EFFECT report changes.
- Cursor subscription reported commit-wide “success / no failures” because cancelled ≠ failed in check aggregation; Owner authority = this table + run URL.
