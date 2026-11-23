---
cursor:
  subagentId: "bc-2419abc2-0a01-5e31-8287-50adc7830638"
---

# Step 0 report — pack 17-55

## Verdict: PASS

| Gate | Result |
|------|--------|
| 0-0 B9 | `v6.99.170` |
| 0-0 rows | 28, 82, 16, 353, 116, 37 |
| 0-A #60 | merged `cd0cadd86f9a302987cf6bcdc5e66695d152c696` |
| 0-A #64 + D-114(b) | merged `ade2dc8ca9b04faad03eedea26eb6754ac0607ab` |
| 0-1…0-4 branch | `cursor/step0-m1b-params-data-0638` |
| `step0_head` | `ef70d4214274d90cc6bb1150eb3d64c14e898523` |
| Boot stock | 136088; conservation 0 |
| Golden gated | ERROR=0 SCRIPT_ERROR=0 |

## SHA table

| Ref | Full SHA |
|-----|----------|
| pre-step0 main (0-0) | `8149f4e1cc5f3ccb2b616edf0bbe25224cd322db` |
| #60 merge | `cd0cadd86f9a302987cf6bcdc5e66695d152c696` |
| #64 merge (post 0-A main) | `ade2dc8ca9b04faad03eedea26eb6754ac0607ab` |
| step0_head | `ef70d4214274d90cc6bb1150eb3d64c14e898523` |

## 0-A notes
- #60 required async `merge-async` (stack); #64 marked ready then sync merge-commit.
- D-114(b): removed upgrade-path `_note_city_spend` in `_try_start_city_public`; kept `order_upgrade` SPEND_CAT_BUILD; test `test_D114b_city_upgrade_spend_counted_once` green.
- Remote branches `cursor/wp65-city-queue-c24c` and `cursor/wp67-f9ec` deleted after success.
- Post-#60/#64 GUT unit+property+UI + golden gated all green. Column diffs: WP-65 queue effects (#60); OBS-05 land_rent/vacancy/city_spend (#64).

## 0-1 / 0-2
- Schema (+fixture + L1/L2/M1b scenarios): SYS17×9, SYS07 ABUND×4 + SCARCE×1, QUEUE_MAT_DEMAND_WEEKS. Not in formal `params.json`.
- Layers: validator allows `TRADERS` / `QUAL_OPEN` bools.
- M1b: years=5; G1/G2 overrides per D-109/D-110; ABUND grid `[0, 250000]`.

## 0-3 csv_import (all batches ok, 0 errors)

| Batch | written |
|-------|---------|
| D-08i | 45 |
| WP-17 | 544 |
| WP-18 | 132 |
| opening_population | 16 |
| WP-29 | 91 |
| WP-34 | 63 |

EX-08-21-01/02 expects → 1051 / 499 (D-107). Probe: total_dan=136088, conservation=0, boot_errors=0.

## 0-4 golden
- Gated PASS.
- vs pre-step0 (`pre60`): population/goods/buildings/OBS columns differ — data reimport + 0-A product.
- vs post64: same economic columns from D-107 reimport; OBS columns mostly stable.

## Artifacts
- `cmd_log.txt`, `00_version_gate.txt`
- `0A/` pre/post gates, `diff.patch`, `d114b_test.log`
- `0-3/` import + probe logs
- `0-4/` golden + compares
- `step0_head.txt`, `pre_step0_main_sha.txt`, `post_0A_main_sha.txt`

## Blockers
None. Ready for parallel lanes A/B/C/E from `step0_head`.


## CI follow-up
- Failure on `8057f9f`: gut-unit-property UI after unit data wipe (isolated gut-ui green).
- Fix `ef70d42`: restore `data/` before UI in gut-unit-property.
- **CI green** on tip `ef70d4214274d90cc6bb1150eb3d64c14e898523` (all 4 checks).
