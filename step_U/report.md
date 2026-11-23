---
cursor:
  subagentId: "bc-2a47e999-cdfe-5aea-88d6-72e57b40ff98"
---

# Step U — ui-1755 debug panels (D-115(e))

| Field | Value |
| --- | --- |
| Status | **partial pass** (traders + open zones + built-ratio OK; auto-housing count C-05 gap) |
| Base | int-1755 `c13249e65181bb0bb38a6005a4aed9b84abaa7a2` (`cursor/int-1755-merge-0a6e`, draft #76) |
| Branch | `cursor/ui-1755-debug-panels-ff98` |
| Tip | `1fd181acf5012a49494b3084e4045202987e4507` |
| PR | https://github.com/wayung0217/Project-Patrician/pull/78 (draft; **not** merged to int/main) |
| Scope | `ui/debug_main.gd` only |

## Delivered

1. **Traders panel** — columns: id, ship count, each ship port／in-transit (`ShipRegistry.ship_info`), cash (`CashLedger.balance`), status active／idle／frozen (`TraderRegistry.is_frozen` + ST-TRADER mode; retired labeled).
2. **Port zones** — open zone count (distinct open CIVIL zones from `slots_for_port`); cumulative built-ratio `zone_built_ratio_ppm(port, next_zone)`; CITY_HOUSING layer flag.

## Gaps

See `gaps.md` — city auto-housing **count** missing public query.

## Tests

`tests/ui` GUT via Godot 4.7.2: **6/6 passed** (log `gut_ui.log`).
