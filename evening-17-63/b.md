# Z2 (b) Roster — trader / ship / port

**Source:** `diag_z.json` → `b_roster` / `DIAG_Z_B`  
Full ship list: `b_roster_by_port.txt` + `diag_z.json`.

| Metric | Value |
|--------|-------|
| Trader count | **48** (`TR-001`…`TR-048`) |
| Ship count | **83** (`SHIP:0002`…`SHIP:0084`) |
| State at boot | **all DOCKED** |
| Ports occupied | **all 16** (`PT-01`…`PT-16`) |

## Ships per port

| Port | Ships |
|------|------:|
| PT-01 | 5 |
| PT-02 | 4 |
| PT-03 | 8 |
| PT-04 | 9 |
| PT-05 | 10 |
| PT-06 | 3 |
| PT-07 | 4 |
| PT-08 | 3 |
| PT-09 | 2 |
| PT-10 | 3 |
| PT-11 | 4 |
| PT-12 | 8 |
| PT-13 | 5 |
| PT-14 | 7 |
| PT-15 | 5 |
| PT-16 | 3 |

Boot roster **succeeds** — ships exist and are docked. Step Z `ships_in_port=0` in `trader_summary` is a **sampler reporting gap** (`ships_in_port_count` missing on TraderRegistry), not a missing roster.
