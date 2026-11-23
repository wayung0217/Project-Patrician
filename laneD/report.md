---
cursor:
  subagentId: "bc-802a2b32-8f57-5167-a2b7-a6ebea43a116"
---

# Lane D report — pack 17-55

## Verdict: DONE (draft PR)

| Item | Result |
|------|--------|
| Base | Lane C tip `7101e9c…` (includes step0 tip `ef70d42…`; product `8057f9f…`) |
| Branch | `cursor/laneD-city-housing-a116` |
| Tip SHA | `8603d8ca6a57eb799a03a51dc65f911fd3bfa9f3` |
| PR | https://github.com/wayung0217/Project-Patrician/pull/75 (draft; base = laneC) |
| GUT unit+property | 550/550; SCRIPT ERROR 0 |
| Golden gated | PASS ERROR=0 SCRIPT_ERROR=0; identical to Lane C |

## Delivered

### WP-68 / FRM-SYS08-24 CITY_HOUSING
- Scenario layer `CITY_HOUSING` (default off); SimEngine applies via `set_city_housing_layer`
- After zone open: beggars ≥ HOUSE_CAPACITY ∧ free beds＝0 ∧ balance ≥ reserve×build cash → `order_build` RESIDENCE on outermost city/unowned civil slot
- MAX_PER_SEASON＝1; CITY exempt from kontor prerequisite for residence

### D-100 built-ratio
- `zone_built_ratio_ppm` / `_zone_built_ratio_ok` gates zone open (not gated by CITY_HOUSING switch)
- BUILDING／PAUSED／WAITING count; empty purchased land does not

### Scenarios / PRMs
- `ZONE_USED_MIN_PPM=700000`, `CITY_HOUSING_RESERVE_MULT=2`, `CITY_HOUSING_MAX_PER_SEASON=1` in schema + fixtures + M1b/L scenarios
- `scenario_M1b_G0H.json` with `CITY_HOUSING: true`

## Gaps
- None blocking Lane D. Pre-existing M1b `ABUND_BONUS_MAX_PPM` override/grid overlap left on G0/G1/G2 (stripped only on G0H).

## Hygiene
- Tests: user:// / in-memory; no git; no res://data writes
- No `sim_loop` edits; no main commits

## Artifacts
- `diff.patch`, `lane.txt`, `tip_sha.txt`, `gut_full.log` / `gut_unit_property.log`, `gut_lane_d.log`, `golden/`, `cmd_log.txt`
