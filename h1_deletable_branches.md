# H-1 — Deletable remote branch list (R9-73)

Snapshot: `git_branch_r.txt` (refresh pack time).  
**`review/*` orphans are exempt** from the ≤8-branch cap (H5) — listed for inventory only, **not** deletion targets here.

## Cap math (non-`review/*`)

| Keep / delete | Branch | Why |
|---------------|--------|-----|
| **KEEP** | `main` | trunk |
| **KEEP** | `int-1758` | open #81; M1b int base |
| **KEEP** | `cursor/ci-hang-1767-866d` | open #84 L2 |
| **KEEP** | `cursor/int-ci-1767-866d` | open #85 L3 |
| **KEEP** | `cursor/m1b-fix-1766-3fe3` | open #83 L4 |
| **KEEP** | `tools-1769` | open #86 L5 |
| **KEEP** | `housing-1758` | open #79; in int-1758 stack |
| **KEEP** | `tools-1758` | open #80; in int-1758 stack |
| **CANDIDATE DELETE** | `cursor/int-1755-merge-0a6e` | PR #76 **CLOSED**; superseded |
| **CANDIDATE DELETE** | `cursor/int-1756-295f` | PR #69 draft “do not merge”; superseded by int-1758 |
| **CANDIDATE DELETE** | `cursor/int-1757-5ae9` | PR #70 draft “do not merge”; superseded by int-1758 |
| **ASK Owner** | `cursor/lane-a-wp36-traders-26f5` | open #72 Lane F — still open; delete only if Owner closes |
| **ASK Owner** | `cursor/ui-1755-debug-panels-ff98` | open #78 Step U — still open |
| **ASK Owner** | `diag-z-1758` | no open PR; diag scratch — delete if Owner done with Z diag |

## Proposed delete set (Owner-approve before `git push --delete`)

Minimum to cut clutter (no open product work assumed done):

1. `cursor/int-1755-merge-0a6e`
2. `cursor/int-1756-295f` (close #69 first or with delete)
3. `cursor/int-1757-5ae9` (close #70 first or with delete)
4. `diag-z-1758` (if Owner confirms)

**This agent did not delete any branch.** H-1 = list only.

## Exempt (do not count / do not delete for H-1)

```
review/evening-17-55
review/evening-17-57
review/evening-17-69-int
review/evening-17-69-lane1
review/evening-17-69-lane2
review/evening-17-69-lane3
review/evening-17-69-lane4
review/evening-17-69-lane5
```
