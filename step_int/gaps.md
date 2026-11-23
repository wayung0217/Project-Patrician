---
cursor:
  subagentId: "bc-aea1f570-cf76-5f46-96c6-7de671190a6e"
---

# int-1755 gaps (C-05)

## G-INT-01 — `sim_engine` does not wire `layers.TRADERS` / `QUAL_OPEN`

**Source:** Lane A `gaps.md` item 3; confirmed on int tip `c13249e…`.

`TraderRegistry.set_layers(traders, qual_open)` exists and SimLoop boots traders only when `TraderRegistry.is_enabled()`. `sim_engine.gd` applies `RELOCATE` and `CITY_HOUSING` from scenario layers but **never** calls `set_layers` for TRADERS/QUAL_OPEN. Default `_enabled=false` → Step Z M1b scenarios with `TRADERS=1` still run with traders off.

Additionally, sim still injects deny-all `SimQualificationFixture` (D-63b). Even after set_layers, QUAL_OPEN path needs a non-deny fixture or TierRegistry for TradeDesk enter/trade.

**Constraint:** int-1755 allows merge commits only — no product fix commit on this branch.

**Impact:** Z “traders on” vs “G0 traders off” will not differ in trader activity; trader_summary sail/cargo metrics stay near zeros; D-104(c)⑤ perf delta understates trader cost. Population/demand/housing/queue outputs remain valid.

**Follow-up:** one-line (or small) int/product PR: before `SimLoop.boot`, read layers and `TraderRegistry.set_layers(...)`; QUAL_OPEN allow fixture when layer on.

## G-INT-02 — Lane E skipped

Agent `bc-c106bd70-66a6-5345-982a-068f355ff3ea` still RUNNING at merge time; `evening-17-55/laneE/` incomplete (no tip/PR/report). Skipped per D-115.

## G-INT-03 — M1b_G0/G1/G2 ABUND in both overrides and grid

`ERR-SYS23-04: key 'PRM-SYS07-ABUND_BONUS_MAX_PPM' appears in both overrides and grid`. Lane D stripped this only on G0H. Step Z/Z2 used `user://scenarios_z/` copies with override key removed (grid kept) — **no product commit**. Follow-up: fix committed scenario JSONs on step0/int.
