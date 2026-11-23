# Lane A gaps (C-05)

1. **MarketPricer public batch_area (D-110(g)／N-04)**  
   Spec requires calling MarketPricer’s same batch-area pure fn. `_batch_area` is private; Lane A may not edit `market_pricer.gd`. Implemented shared pure copy in `core/trade_evaluator.gd` (`estimate_sell_revenue_li`／`batch_area_li`) matching FRM-SYS04 trapezoid. EX-17-02-02／03 green against frm_examples. **Follow-up:** expose `MarketPricer.batch_area(...)` and delete the duplicate.

2. **Destination board without presence (IntelLedger.board_for)**  
   `board_for` requires actor present at destination; traders evaluate remote ports while docked elsewhere. Product API for “known mid／weeks” without presence is outside Lane A files. Workaround: `TraderRegistry.set_intel_override` (tests／fixture) + presence path when available.

3. **sim_engine layers.TRADERS／QUAL_OPEN wiring**  
   `sim_engine.gd` is not in Lane A file list. `TraderRegistry.set_layers(traders, qual_open)` + `SimLoop` hooks are ready; sim CLI must call `set_layers` before boot (gap for int lane). Deny-all `SimQualificationFixture` still blocks TradeDesk unless QUAL_OPEN path／allow fixture is injected by sim.

4. **CashLedger.is_frozen (WP-44)**  
   M1b freeze uses TraderRegistry-local `mark_frozen`／arrears threshold; will prefer `CashLedger.is_frozen` when WP-44 lands (`has_method` already checked).
