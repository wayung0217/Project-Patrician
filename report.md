---
cursor:
  subagentId: "bc-5fbf00f4-2349-5889-a2a9-91f68700c107"
---

# 17-70 T3 report — #86 gut-unit(0) timeout

| Field | Value |
|-------|--------|
| Product tip | `9b333c704c62fe00fe59ce1b67684de9b7e88948` (**unchanged**) |
| Branch / PR | `tools-1769` / #86 |
| Diff | **empty** |
| Root cause | Byte-size shard packing + `test_sys23_wp26.gd` multi-year/cli sims on shard 0 → wall >35m cancel (fix ∈ `ci.yml`/`tests`, not `tools/`) |
| Corrected CI | **none** (H4 gap) |
| Orphan | `review/1770-t3` — tip `0060bb1fe48461e148582f7b8423b5b2fa729dea` — `orphan_sha.txt` |

Details: `root_cause.md`, `job_timings.md`, `00_s9a_report.md`.
