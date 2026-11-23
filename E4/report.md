# E4 — `tools/wp65_newbuild_360_probe.gd` (formal 360d new-builds)

## Runs (D-113(e))
1. **FAIL** `2026-11-23T09:45:30Z` on `/tmp/wt-pr60` (@ `d6bb0a6`): no `.godot` global class cache → autoload parse errors (`GoodDef` etc.) → probe boot null. Log: first `probe.log` attempt (see runs.log).
2. **PASS** `2026-11-23T09:56:26Z` after `godot --import` on main + copy `.godot` into worktree. `probe_rc=0`. Full output: `probe.log`.

## Output (port_id / cb_id / start-day)
```
WP65_NEWBUILD_PROBE days=360
WP65_NEWBUILD port=PT-02 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-02:0063
WP65_NEWBUILD port=PT-06 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-06:0023
WP65_NEWBUILD port=PT-06 cb=CB-04 day=90 def_class=PUBLIC building_id=BLD:PT-06:0024
WP65_NEWBUILD port=PT-07 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-07:0034
WP65_NEWBUILD port=PT-07 cb=CB-05 day=90 def_class=PUBLIC building_id=BLD:PT-07:0035
WP65_NEWBUILD port=PT-07 cb=CB-16 day=90 def_class=PUBLIC building_id=BLD:PT-07:0036
WP65_NEWBUILD port=PT-08 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-08:0025
WP65_NEWBUILD port=PT-09 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-09:0024
WP65_NEWBUILD port=PT-10 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-10:0027
WP65_NEWBUILD port=PT-10 cb=CB-16 day=90 def_class=PUBLIC building_id=BLD:PT-10:0028
WP65_NEWBUILD port=PT-11 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-11:0043
WP65_NEWBUILD port=PT-11 cb=CB-05 day=90 def_class=PUBLIC building_id=BLD:PT-11:0044
WP65_NEWBUILD port=PT-13 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-13:0041
WP65_NEWBUILD port=PT-13 cb=CB-05 day=90 def_class=PUBLIC building_id=BLD:PT-13:0042
WP65_NEWBUILD port=PT-15 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-15:0060
WP65_NEWBUILD port=PT-16 cb=CB-10 day=90 def_class=PUBLIC building_id=BLD:PT-16:0036
WP65_NEWBUILD port=PT-16 cb=CB-16 day=90 def_class=PUBLIC building_id=BLD:PT-16:0037
WP65_NEWBUILD port=PT-08 cb=CB-16 day=180 def_class=PUBLIC building_id=BLD:PT-08:0026
WP65_NEWBUILD port=PT-16 cb=CB-04 day=180 def_class=PUBLIC building_id=BLD:PT-16:0038
WP65_NEWBUILD_TOTAL 19
WP65_NEWBUILD_OK
```

All 19 starts used loaded `BuildingDef` (`def_class=PUBLIC`); no missing-def errors. First wave day=90 (season), second day=180.
