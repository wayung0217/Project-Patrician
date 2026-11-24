# S1: feature branches need their own workflow

## Rule (17-64 S1)
- `pull_request` → full CI
- `push` → only `main`, `tools-1758`, `int-1758`

## Why transplanting onto #85 / feature heads is required
GitHub Actions loads the workflow **from the commit that triggered the event**:
- For `push` on a feature branch → workflow YAML at that feature tip
- For `pull_request` → workflow YAML at the PR head SHA (not the base)

If `main` (or `int-1758`) already has S1 filters but an open feature head still carries pre-ci-speed unrestricted `on: push:` + `pull_request:`, **the same SHA dual-runs** push+PR CI. Filters on the base branch do not rewrite open heads.

Evidence from evening-17-64 (`s1_s2_not_met.md`): product branch `cursor/m1b-fix-1766-3fe3` dual-ran after #82 merged S1 onto main, because those tips still had unrestricted `on: push:`.

## Lane3 implication
#85 (`cursor/int-ci-1767-866d` → `int-1758`) must carry Lane2’s final `ci.yml` itself so int-tree PRs/pushes honor S1/S2/timeouts/gates without waiting for product merges. This PR is **workflow-only** — no product code.
