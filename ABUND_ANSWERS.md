# ABUND_BONUS_MAX_PPM — Owner record (a)(b)

## (a) Authorization for move overrides→grid
**R9-71 中-4 / F5** in `05_TechSpec` (17-58 Lane F), echoed in `internal/dispatch-17-58.md`:
> F5 scenarios (中-4): remove ABUND_BONUS_MAX_PPM from overrides in G0/G1/G2/G0H; keep in grid only
TechSpec fragment: 「把 ABUND_BONUS_MAX_PPM 從 overrides 移除，只留在 grid（0 與 250000）」.
Commit `5fc9853` message: 「F5 ABUND_BONUS only in M1b grid」.

## (b) Was override `0` Owner-approved trial or boot placeholder?
**Owner-approved trial value** under **D-108(c)**（富足升階加速暫停：M1b 情境設 ABUND_BONUS_MAX_PPM＝0）；grid 另跑 0 與 250000（dispatch-17-55 / TechSpec 0-2）— not a boot-validation placeholder.
