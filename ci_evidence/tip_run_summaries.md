# L2-4 CI tip-run summaries — FINAL — no merge

**Tip:** `6a731ff051874c767be52c1904df898e294c180f`  
**Run:** https://github.com/wayung0217/Project-Patrician/actions/runs/45440174473  
**Conclusion:** failure (only golden-30d — GOLDEN_BASE_MISSING / 2.5 intentional)

## Final job table
| Job | Conclusion | Link |
| --- | --- | --- |
| gut-ui | success | …/job/138608787265 |
| gut-unit (0) | **success** (~29m; 45m budget) | …/job/138608787159 |
| gut-unit (1) | success | …/job/138608786963 |
| gut-unit (2) | success | …/job/138608786979 |
| gut-unit (3) | success | …/job/138608786896 |
| gut-unit-gate | **success** | https://github.com/wayung0217/Project-Patrician/actions/runs/45440174473/job/138628815928 |
| golden-30d | failure GOLDEN_BASE_MISSING | https://github.com/wayung0217/Project-Patrician/actions/runs/45440174473/job/138608786507 |
| m1b-* | skipped | |

## Gate print (Owner 乙)
See `gate_tip_6a731ff.txt`: TOTAL=558 ≥555; REMOVED=無; ADDED=3 EX names.

## Why timeout 30→35→45 (resolved)
bb1b50d@30m and e99b495@35m cancelled shard0 → gate skipped. Tip 6a731ff@45m: shard0 **success**. Other shards ≪10m; CI wall ≤50m parallel.

## GOLDEN_BASE_MISSING
`golden_base_missing_excerpt_6a731ff.txt` — until main green golden.

## actions@v5
checkout/cache/upload: tip golden job; download-artifact: tip gate job (above). See `../actions_versions.txt`.
