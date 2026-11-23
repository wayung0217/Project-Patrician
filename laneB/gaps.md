# Lane B gaps — pack 17-55

1. **D-110(b) `BuildingEconomy.city_queue_material_shortfall`** — missing on step0 head (lane C owns `building_economy.gd`). FRM-SYS08-25 queue-mat term is wired in `DemandModel` and calls the query when present; EX-08-25 tests inject a shortfall provider. Product path returns addon 0 until lane C lands.

2. **EXCESS_CONSUME schedule vs FRM-SYS07-16** — spec wants CONSUME → excess → satisfaction. Lane B cannot edit `sim_loop.gd` (lane A). Excess + A/S run at start of `PopulationModel.daily_step` (before sat; after same-day produce; before same-day CONSUME).

3. **FRM-SYS07-18** — out of scope (D-110(j)).
