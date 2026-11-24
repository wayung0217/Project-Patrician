# 4.2 K4 traders = 2

Source: `tests/unit/test_d123_opening_board_1766.gd` → `test_K4_formal_boot_30d_sail_buy_sell_no_manual_board` + `_boot_traders_mini`.

## (a) Why traders = 2

- Product M1b genesis uses **48** merchants (`PRM-SYS17-SHIP_MIX` / `TIER_MIX` schema **length=48**).
- Early K4 tried `SimEngine` + shrink overrides → LENGTH fail, then full 48×30d hung gut-unit ~**3h44m** (CI #499/#500 on `ba1e644`).
- GUT budget target ≤50m (17-67). Mini roster keeps the **formal product path** (seed → evaluate → buy/sail) without burning the unit shard.

## (b) Full initial conditions

| Item | Value |
|------|-------|
| Traders | `TR-001`, `TR-002` (loop `range(1, 3)`) |
| Ships | 1× `SH-03` each, docked at `PT-01`, crew from `PRM-SYS13-CREW` |
| Layers | `TraderRegistry.set_layers(true, true)`; `_qual_open=true`; rng seed `1` |
| Quote | `CashLedger.set_quote_provider(MarketPricer)` |
| TradeDesk | `SimQualificationOpenFixture` + `FixtureTradeObserver` |
| Market stock | `MARKET_STOCK=500` every port×good (genesis) |
| Dest asymmetry | Drain **400** of `GD-001` from `PT-02` market before seed (opening mid B ≫ A) |
| Opening board | `IntelLedger.seed_opening_board()` once; **no** `set_intel_override` |
| Demand | `PotentialDemandAll` weekly=100 (pass D-110(g)) |
| Cash | Genesis then cap ≤ `TRADER_CASH_CAP_LI=20000` |
| HOLD | `GoodsLedger.register_capacity_provider(KIND_HOLD, ShipRegistry…)` |
| Days | Loop up to 30; **early-exit** when `sail_sum≥1` and `cargo_total≥1` |
| Asserts | sail≥1, cargo≥1, saw OUTBOUND, sell-clear **or** cargo departed |

## (c) Why 2 proves cold-start fixed

Cold-start bug was **empty ST-BOARD → profit candidates empty → explore/formal sail=0**, independent of roster size.

K4 uses the **real K1 seed** (`seed_opening_board`) and formal `_process_ship_day(..., explore=false)` — not `set_intel_override`. With only 2 traders:

1. Opening reports give `board_for` n≥1 / consensus mid at dest.
2. Dest stock drain creates a mid spread so the profit gate can fire.
3. Asserts require **sail + outbound cargo** without fixture board inject.

If cold-start were still broken, these 2 traders would also idle (same empty-candidate path as 48). Passing K4 proves the seed→board→candidate path works; scale-48 remains a matrix/H4 concern, not the cold-start proof.
