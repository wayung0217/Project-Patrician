# Test name lists + counts — evening-17-64

Source: `git` tree at pre `1252ab1` (#77 main) and after tip `93ddd62` (PR #82 green gate).
CI Passing proof: run 45306894306 (pre) and 45363142979 (after) — unit+property 555, UI 6.
Shard after: 133+156+141+125 = 555 (`gut-unit-gate` GUT_UNIT_PROPERTY_COUNT_OK=555).

| Set | Pre count | After count | Set-equal | only_pre | only_after |
|-----|----------:|------------:|:---------:|---------:|-----------:|
| unit+property | 555 | 555 | True | 0 | 0 |
| UI | 6 | 6 | True | 0 | 0 |

Files:
- `test_names_unit_pre.txt` / `test_names_unit_after.txt` (555 lines each)
- `test_names_ui_pre.txt` / `test_names_ui_after.txt` (6 lines each)

CI Passing (not merely tree defs):
- Pre main run https://github.com/wayung0217/Project-Patrician/actions/runs/45306894306 — Passing unit+property 555, UI 6
- After PR run https://github.com/wayung0217/Project-Patrician/actions/runs/45363142979 — Passing 555 (shards) + UI 6
