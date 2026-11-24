# CI links — evening-17-64

Times Asia/Hong_Kong (UTC+8).

## PR / merge
- PR: https://github.com/wayung0217/Project-Patrician/pull/82 (**MERGED**)
- Merge-commit: `9d293ff8e67f7b224ac33147f802a53492ffbd5b` (HKT 2026-11-24 17:44)
- Head tip: `93ddd62be3d6d568351f46affc17ac218403b9c8`
- Remote `ci-speed` deleted on merge

## Before merge (pre / S0 baselines on main)
- https://github.com/wayung0217/Project-Patrician/actions/runs/45306894306 — success; tip `1252ab1` (#77); Passing 555+6; wall outlier **38.5m**
- https://github.com/wayung0217/Project-Patrician/actions/runs/45305770663 — success; `39ee136` (#73); **8.1m**
- https://github.com/wayung0217/Project-Patrician/actions/runs/45304769673 — success; `c83e4df` (#75); **7.0m**

## Green gate CI (same tip as merge parent — after timing)
- https://github.com/wayung0217/Project-Patrician/actions/runs/45363142979 — success; tip `93ddd62`; Passing **555+6**; golden IDENTICAL; wall ~**21m** (≤15m **not met**)

## After #82 merge (`9d293ff` push main)
- https://github.com/wayung0217/Project-Patrician/actions/runs/45368037707 — **cancelled** (gut-unit shard 0 cancelled; shards 1–3 + golden-30d succeeded; gate skipped). No green full-wall after-merge run on the merge-commit.

## Prior PR attempts (ci-speed)
- https://github.com/wayung0217/Project-Patrician/actions/runs/45359785698 — cancelled (shard2 20m timeout)
- https://github.com/wayung0217/Project-Patrician/actions/runs/45355753611 — cancelled (25m unit timeout); golden identical
- https://github.com/wayung0217/Project-Patrician/actions/runs/45354995680 — failed T1 clean-tree

## Pre golden source
- tools-1758: https://github.com/wayung0217/Project-Patrician/actions/runs/45321456614

## S1/S2 failure evidence (dual push+PR — see `s1_s2_not_met.md`)
- https://github.com/wayung0217/Project-Patrician/actions/runs/45387138225 (push) + https://github.com/wayung0217/Project-Patrician/actions/runs/45387149310 (pull_request) — same SHA `b29e297`
