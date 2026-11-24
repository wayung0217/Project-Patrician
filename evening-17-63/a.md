# Z2 (a) Boot — Za_G0_A0 30d (M1b-Diag-Z)

**CI:** https://github.com/wayung0217/Project-Patrician/actions/runs/45352996264  
**SHA:** `71b094d773125cc96ee66ff65691d5219a22eedf`  
**Entry:** `sim_runner --inline` + `m1b_prepare_scenario.py --group Za_G0_A0` + `--days 30`  
**Source:** `diag_z.json` → `a_boot` / `DIAG_Z_A`

| Field | Value |
|-------|-------|
| `set_layers(traders_on, …)` | **true** |
| `set_layers(…, qual_open)` | **true** |
| Injected qualification fixture | **`SimQualificationOpenFixture`** |

Matches F1 wiring: TRADERS on + QUAL_OPEN → OpenFixture before `SimLoop.boot`.
