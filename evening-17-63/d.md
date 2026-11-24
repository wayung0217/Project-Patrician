# Z2 (d) Per-port board_for / ship-report counts — days 1, 7, 30

**Source:** `diag_z.json` → `d_board_for_days`  
Metric: `IntelLedger.diag_recorded_report_count(port)` = raw `_rec[port]` size (ship-report entries at present-port board).

## Days 1, 7, 30 — all ports

| Port | day 1 | day 7 | day 30 |
|------|------:|------:|-------:|
| PT-01 … PT-16 (each) | **0** | **0** | **0** |
| **Sum** | **0** | **0** | **0** |

No ship-reports ever recorded in 30 days (ships never sailed → no arrivals → boards stay empty → candidates stay empty). Circular cold-start.
