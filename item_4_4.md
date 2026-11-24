# 4.4 S9a C — FRM → files/fns → tests

| FRM | Requirement (abbrev.) | File / function | Tests |
|-----|----------------------|-----------------|-------|
| **FRM-SYS15-11** | Opening board: one OPENING report per (P, O≠P) from O opening mid/band; day/tick=0; published; no own/ship_snap/contact; pricing fail → ERR-SYS15-05 collect-all refuse boot | `IntelLedger.seed_opening_board()` (`autoload/intel_ledger.gd`); boot call `SimLoop.boot()` after opening stock (`autoload/sim_loop.gd`) | `test_K1a_…` n=1 mid=origin; `test_K1b_…` WINDOW trim; `test_K1c_…` real arrival coexist; `test_K1d_…` no own/contact/ship_snap; `test_K1e_…` ERR-SYS15-05 + `assert_push_error_count` |
| **FRM-SYS17-04** | Explore: EXPLORE_RATE lottery; dests without offtake history; cap EXPLORE_QTY; **no profit gate**; rest of flow as §03 | `TraderRegistry._evaluate_and_maybe_sail` empty-intel + `explore` → `GoodDef.base_price_li` ranking stand-in; `_filter_explore_candidates`; `_pick_explore_traders` | `test_K2_explore_sails_without_opening_board` (no seed; empty ST-BOARD; forced explore day; sail≥1) |
| **FRM-SYS17-02** (cold-start handoff) | No dest mid → not a profit candidate; cold-start via 17-04 explore / D-123 opening board | same evaluate path; K1 seed supplies mid for non-explore | `test_K4_formal_boot_30d_…` seed then explore=false days; sail+cargo; `test_K4_f1_note_…` product paths lack `set_intel_override(` |

Related outs (D-123(c), not a FRM id): `season_sail_count` / `season_cargo_dan` → `SimSampler` → `trader_summary.csv` (see item_4_3).
