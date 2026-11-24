# evening-17-64 — CI speed S0–S6 + tools T1–T5 (S9a)

**Branch:** `ci-speed` → **merged** [#82](https://github.com/wayung0217/Project-Patrician/pull/82)  
**Merge-commit:** `9d293ff8e67f7b224ac33147f802a53492ffbd5b` (HKT 2026-11-24 17:44)  
**Tip merged:** `93ddd62be3d6d568351f46affc17ac218403b9c8`  
**Base at branch create:** `1252ab1` (main); merge parent also included intervening main `a352383` (docs)

**Owner review gate (C-15 / 17-68):** pack + CI links below; **S1/S2 NOT MET**; wall **~21m vs ≤15m NOT MET**. No further product merge from this pack.

## S9a A — 基線

- Dispatch: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/internal/dispatch-17-64.md`; prefs `preferences.md` 17-64 / 17-68
- Pre main CI tip: `1252ab1` / run [45306894306](https://github.com/wayung0217/Project-Patrician/actions/runs/45306894306)
- Pre tests: unit+property **555**, UI **6** (name lists below)
- Pre golden: tools-1758 artifact run [45321456614](https://github.com/wayung0217/Project-Patrician/actions/runs/45321456614) sha `8b25c951…` (main had no golden job yet)

## S9a B — 變更清單

Only `.github/workflows/ci.yml`, `tools/` (run_m1b*), and three `tests/unit/*.gd.uid` required for T1 clean-tree. No product/sim/test logic. Did not touch int-1758, #72/#79/#81, diag-z-1758.

Full diff: `diff.patch`. Workflow-only: `workflow.diff` (610 lines; full `ci.yml` diff vs `1252ab1`→`93ddd62`).

## S9a C — 規格對照（S1–S6 / T1–T5）

| Item | Status |
|------|--------|
| S0 last-3 timings + top5 | **MET** — `s0_timing.md` |
| S1 PR full; push main/tools/int only | **NOT MET** — `s1_s2_not_met.md` (dual push+PR on open heads) |
| S2 concurrency cancel same head | **NOT MET** — `github.ref` differs push vs PR; dual runs not cancelled |
| S3 Godot + `.godot/imported` cache | present in `workflow.diff` |
| S4 parallel unit/ui/golden; 4-way matrix | present; gate =555 |
| S5 main artifact; PR download/compare | present |
| S6 H4/W4 only tools/int push | present (skipped on #82) |
| T1–T5 tools | present in `diff.patch` |
| Wall ≤15m | **NOT MET** — after ~**21m** vs target 15m (`after_timing.md`) |

## S9a D — 介面

No Autoload / product API changes. Tools: `run_m1b.ps1`, `run_m1b_report.gd`, `run_m1b_README.md`, `m1b_prepare_scenario.py`.

## S9a E — 自查

- Scope respected aside from three missing `.uid` (explicit follow-up for T1).
- int-1758 / diag-z / #72/#79/#81 undisturbed.
- S1/S2 failure + 21m wall called out for Owner (#82 already merged; 17-68 = pack-first / no further self-merge).

## S9a F — 測試

| Gate | Pre (`1252ab1`) | After tip (`93ddd62`) |
|------|-----------------|------------------------|
| Passing unit+property | **555** | **555** (133+156+141+125) |
| Passing UI | **6** | **6** |
| Name lists set-equal | yes | yes — `test_names_counts.md` |
| Golden cells | sha `8b25c951…` | **IDENTICAL=1**, DIFF_CELLS=0 — `golden_compare.txt` |

Name list files: `test_names_unit_{pre,after}.txt` (555), `test_names_ui_{pre,after}.txt` (6).

Green PR CI (same tip as merge parent): [45363142979](https://github.com/wayung0217/Project-Patrician/actions/runs/45363142979)

## S9a G — 排程與信號

No SimLoop/product schedule changes.

## S9a H — 偏離與缺口

1. **S1 NOT MET** + **S2 NOT MET** — see `s1_s2_not_met.md` (dual-run evidence on `cursor/m1b-fix-1766-3fe3`).
2. **Wall ≤15m NOT MET:** green critical path **~21 min** (shard 0) vs target **15m**. Better than S0 outlier 38.5m; still over target.
3. T4 live pop in **sim** PROGRESS emit remains on tools-1758/int (out of ci-speed product scope); report-side prefers `pop=` from progress logs.
4. First PR golden vs main baseline skipped (no main artifact yet); compared to tools-1758 pre golden instead — identical cell-by-cell.
5. Post-merge main push CI on `9d293ff`: [45368037707](https://github.com/wayung0217/Project-Patrician/actions/runs/45368037707) — **cancelled** (gut-unit shard 0 cancelled; other shards/golden succeeded). No green post-merge main wall for the merge-commit itself.

## S9a I — 特別證據（paths）

- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/s0_timing.md`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/after_timing.md`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/ci_links.md`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/s1_s2_not_met.md`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/workflow.diff`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/diff.patch`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/test_names_counts.md`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/test_names_unit_pre.txt`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/test_names_unit_after.txt`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/test_names_ui_pre.txt`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/test_names_ui_after.txt`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/golden_pre_30d.csv`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/golden_after_30d.csv`
- `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-64/golden_compare.txt`
