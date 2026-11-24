# Interface changes — L4 / D-123 (on tip)

| Symbol | File | Kind | Notes |
|--------|------|------|-------|
| `IntelLedger.seed_opening_board() -> Array` | `autoload/intel_ledger.gd` | **new public** | FRM-SYS15-11; ErrorInfo array; empty = OK |
| `IntelLedger.OPENING_SHIP_ID` | `autoload/intel_ledger.gd` | const `&"OPENING"` | virtual ship key |
| `SimLoop.boot` call site | `autoload/sim_loop.gd` | call added | after opening stock, once |
| `TraderRegistry.season_sail_count(port_id, season_index) -> int` | `autoload/trader_registry.gd` | **new public** | D-123(c) |
| `TraderRegistry.season_cargo_dan(port_id, season_index) -> Dictionary` | `autoload/trader_registry.gd` | **new public** | good→dan |
| `TraderRegistry.season_avg_daily_margin_li(...)` | `autoload/trader_registry.gd` | **new public** | sampler companion |
| explore empty-intel branch | `TraderRegistry._evaluate_and_maybe_sail` | behavior | FRM-SYS17-04; `base_price_li` stand-in |

No new Autoload registrations. `trade_evaluator.gd` unchanged API this lane (used by evaluate path).
