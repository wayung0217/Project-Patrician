# S0 — last 3 successful main CI runs (pre ci-speed)

Times in Asia/Hong_Kong (UTC+8). Source: GitHub Actions jobs API.

| Run | SHA | Link | Wall (job max) | Event |
|-----|-----|------|----------------|-------|
| 466 | `1252ab1` (#77 merge) | https://github.com/wayung0217/Project-Patrician/actions/runs/45306894306 | **38.5 min** | push main |
| 465 | `39ee136` (#73) | https://github.com/wayung0217/Project-Patrician/actions/runs/45305770663 | **8.1 min** | push main |
| 464 | `c83e4df` (#75) | https://github.com/wayung0217/Project-Patrician/actions/runs/45304769673 | **7.0 min** | push main |

## Run 466 (`1252ab1`) — job/step timings

| Job | Duration | Steps (slowest first) |
|-----|----------|------------------------|
| gut-unit-property | 38.4 min | Run GUT unit+property **35.4 min**; Run GUT UI **2.8 min**; Import 9s; Download Godot 2s |
| gut-ui | 3.1 min | Run GUT UI **2.9 min**; Import 9s |

## Run 465 (`39ee136`)

| Job | Duration | Steps |
|-----|----------|-------|
| gut-unit-property | 8.1 min | unit+property **4.1 min**; UI in-job **3.7 min**; Import 7s |
| gut-ui | 4.2 min | UI **3.9 min**; Import 11s |

## Run 464 (`c83e4df`)

| Job | Duration | Steps |
|-----|----------|-------|
| gut-unit-property | 7.0 min | unit+property **3.0 min**; UI in-job **3.7 min**; Import 8s |
| gut-ui | 3.9 min | UI **3.6 min**; Import 9s |

## Top 5 slowest steps (across the 3 runs)

1. Run GUT unit + property — **35.4 min** (run 466 outlier)
2. Run GUT unit + property — **4.1 min** (run 465)
3. Run GUT UI (in unit job / isolated) — **~2.8–3.9 min**
4. Run GUT unit + property — **3.0 min** (run 464)
5. Import project — **~7–11 s** (repeated per job; no cache)

## Pre-change test counts (run 466)

- unit+property: **555** Passing
- UI: **6** Passing
- Unique total: **561**

## Pre-change golden (tools-1758 run 45321456614 @ main-base product)

- `golden_pre_30d.csv`: rows=527 cols=19 bytes=2270766
- sha256=`8b25c951a90e36bd38269089b9d21e51b260914f8768624ac0efd0dab29be55c`
- Note: main CI had **no** golden-30d job before 17-64; baseline taken from tools-1758 artifact on same product tip family.
