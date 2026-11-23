---
cursor:
  subagentId: "bc-2a47e999-cdfe-5aea-88d6-72e57b40ff98"
---

# Step U gaps (C-05)

1. **City auto-housing count (port panel)**  
   Dispatch asks for「城市自建住宅數」. BuildingEconomy exposes `is_city_housing_on()` / `set_city_housing_layer()` (WP-68 layer switch) and builds via private `_season_city_auto_housing`, but **no public read-only counter** (e.g. `city_auto_housing_count(port)`) appears in 03_Systems H / TechSpec §3. Counting CITY-owned residences via `residences` / `buildings_for_port` would conflate opening stock with auto-housing. **Stopped that field only**; UI shows explicit C-05 gap text. No product-code change (autoload/core/sim).

2. **G-INT-01 (context, not a Step U stop)**  
   Formal L1 debug boot does not call `TraderRegistry.set_layers(TRADERS, QUAL_OPEN)`. Roster may be empty／unloaded in M0 play; panel still binds 17.1 H public APIs.
