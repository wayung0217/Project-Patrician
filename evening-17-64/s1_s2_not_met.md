# S1 / S2 — NOT MET (17-64 / Owner note for #82)

Despite `ci.yml` on merge-commit `9d293ff` containing S1 branch filters and an S2 `concurrency` block, **acceptance is NOT MET**.

## Pasted `on:` / `concurrency` at #82 merge (`9d293ff`)

```yaml
on:
  pull_request:
  push:
    branches:
      - main
      - tools-1758
      - int-1758
  workflow_dispatch:
    inputs:
      job: ...

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Full workflow diff: `workflow.diff` (610 lines; sha256 matches `git diff 1252ab1 93ddd62 -- .github/workflows/ci.yml`).

## Why S1 not met

S1 = one full CI per commit: `pull_request` = full CI; `push` only `main` + `tools-1758` + `int-1758`.

Open product branch `cursor/m1b-fix-1766-3fe3` still carried pre-#82 `on: push:` (unrestricted) on the commits that dual-ran, so **the same SHA started both `push` and `pull_request` CI**:

| SHA | push run | pull_request run |
|-----|----------|------------------|
| `51cc942` | [45369380896](https://github.com/wayung0217/Project-Patrician/actions/runs/45369380896) | [45369394669](https://github.com/wayung0217/Project-Patrician/actions/runs/45369394669) |
| `e19c853` | [45375438321](https://github.com/wayung0217/Project-Patrician/actions/runs/45375438321) | [45375453944](https://github.com/wayung0217/Project-Patrician/actions/runs/45375453944) |
| `b29e297` | [45387138225](https://github.com/wayung0217/Project-Patrician/actions/runs/45387138225) | [45387149310](https://github.com/wayung0217/Project-Patrician/actions/runs/45387149310) |
| `c49e015` | [45396039558](https://github.com/wayung0217/Project-Patrician/actions/runs/45396039558) | [45396053042](https://github.com/wayung0217/Project-Patrician/actions/runs/45396053042) |

`git show <sha>:.github/workflows/ci.yml` on those SHAs begins with unrestricted `on: push:` + `pull_request:` (old pre-ci-speed workflow). S1 on main does not rewrite open PR heads.

## Why S2 not met

S2 = `concurrency` group = workflow+ref, cancel-in-progress.

At #82, `group: ${{ github.workflow }}-${{ github.ref }}` uses **different refs** for the same head branch:

- push → `refs/heads/cursor/...`
- pull_request → `refs/pull/N/merge`

So push+PR runs do **not** share a concurrency group and do **not** cancel each other — matching the dual-run table above. (17-67 later moves the group to `github.head_ref || github.ref_name` on the fix branch; that is **out of this pack** / not claimed here.)

## Wall target (related acceptance)

Target ≤**15m** critical path: **NOT MET**. Green same-commit after tip `93ddd62` wall ≈**21m** (shard 0). See `after_timing.md` / `s0_timing.md`.
