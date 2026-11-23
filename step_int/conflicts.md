---
cursor:
  subagentId: "bc-aea1f570-cf76-5f46-96c6-7de671190a6e"
---

# int-1755 merge conflicts

All merges used `git merge --no-ff` from step0 tip. **No conflict resolutions required.**

| Merge | Command tip | Parents | `git show --cc` |
|-------|-------------|---------|-----------------|
| C | `7101e9c…` | `ef70d42` + `7101e9c` | ordinary merge; 9 files |
| D | `8603d8c…` | `8a02133` + `8603d8c` | ordinary merge; 15 files |
| B | `6b38ae0…` | `5d5d31f` + `6b38ae0` | ordinary merge; 5 files |
| A | `14b22ee…` | `494a696` + `14b22ee` | ordinary merge; 10 files |
| E | — | — | skipped |

Artifacts: `merges/merge_{C,D,B,A}.txt`, `merges/merge_*_cc.txt`, `merges/conflicts_*.txt`.
