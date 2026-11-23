---
cursor:
  subagentId: "bc-c106bd70-66a6-5345-982a-068f355ff3ea"
---

# Lane E report — WP-69 test hygiene (17-55)

## Verdict: PASS

| Gate | Result |
|------|--------|
| Files only tests/ | yes — 4 unit scripts |
| Test names before/after | IDENTICAL (531) |
| In-test `git` removed | yes (d6bb0a6 restore deleted) |
| `res://data` writes/wipes | removed (no-ops + formal read-only boot) |
| GUT unit+property ×2 | RUN1 525/525; RUN2 525/525 |
| GUT UI | 6/6 |
| porcelain `data/` after each | empty |
| Draft PR | [#77](https://github.com/wayung0217/Project-Patrician/pull/77); no merge |

## Approach

`SimLoop.boot` hard-wires `BuildingEconomy` / opening paths to committed `res://data`. Without product edits, hygiene = **stop wiping/importing into formal dirs** and boot against committed trees (read-only).

- Removed `OS.execute("git", …)` restore from `test_sys08_wp65_d97a.gd` (d6bb0a6).
- `test_sim_loop.gd` / `test_trade_desk_wp33.gd` / `test_sys23_wp26.gd`: deleted formal wipe + csv_import-into-formal; `_install_opening*` / `_install_formal_from_fixtures` are no-ops with WP-69 notes.
- CLI evidence test uses committed formal data (no fixture copy-in).
- Fixture good builders now `maxi(GOOD_COUNT_MIN, formal_goods_count)` so opening workshops resolve.
- `test_WP59_boot_requires_consumption_provider_2_3_03`: pass missing demand dir so DemandModel cannot auto-wire (formal demand stays).

Git-needed restore that lived in-test → deleted; step0 tip already has CI `git checkout HEAD -- data/` before UI (ef70d42) as belt-and-suspenders. After this lane, unit suites leave `data/` clean so that step is redundant but harmless.

## Evidence files

- `test_names_before.txt` / `test_names_after.txt` / `test_names_diff.txt` (IDENTICAL)
- `grep_git.txt` — only comments / substring false positives (`digits`) / fixture `.gitignore`
- `gut_unit_property_run1.log` + `porcelain_data_run1.txt`
- `gut_unit_property_run2.log` + `porcelain_data_run2.txt`
- `gut_ui.log`
- `diff.patch`
- `cmd_log.txt`

## SHAs

| Ref | SHA |
|-----|-----|
| product base | `8057f9f563411c51c60be1c275d91667e78468b7` |
| step0 tip / PR base tip | `ef70d4214274d90cc6bb1150eb3d64c14e898523` |
| lane E tip | `fbdaa8126154f566d915fa462e7d507f67ce54ca` |
| Draft PR | https://github.com/wayung0217/Project-Patrician/pull/77 |
