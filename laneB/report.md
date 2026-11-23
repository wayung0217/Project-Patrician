# Lane B report — population & demand (17-55)

## Verdict: PASS (with gaps)

| Item | Result |
|------|--------|
| Branch | `cursor/lane-b-pop-demand-003b` |
| Base | `cursor/step0-m1b-params-data-0638` @ `ef70d4214274d90cc6bb1150eb3d64c14e898523` |
| Tip | `6b38ae03c1c816dafc17166a1a28dca06c6eb433` |
| Draft PR | https://github.com/wayung0217/Project-Patrician/pull/73 |
| Lane B GUT | 11/11 pass |
| Related suites | population 38, demand 24, goods 19, opening 3 — all pass |
| Full unit+property | **536/536** pass; SCRIPT ERROR 0 |

## Delivered

- `goods_ledger.gd`: `REASON_EXCESS_CONSUME`; conservation delta; excluded from offtake.
- `population_model.gd`: FRM-SYS07-16/17 A/S + excess; PF bonuses; `season_flow_counts` (D-110(i)); new PRMs required at load.
- `demand_model.gd`: FRM-SYS08-25 = `weekly_demand` + queue-mat addon via D-110(b) query / injectable provider.
- Tests: `tests/unit/test_lane_b_pop_demand_1755.gd` (EX-08-25-01…04, ≥3 abund, ≥3 scarce, season_flow).

## Gaps

See `gaps.md` (queue query missing until lane C; excess schedule vs CONSUME; FRM-SYS07-18 OOS).

## Artifacts

- `diff.patch`, `lane.txt`, `cmd_log.txt`, `gut_*.log`, `gaps.md`, `report.md`
