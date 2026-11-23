# Step I2 — merge #64
- merge SHA: `6885abaeeccde9550cd49983e0889fcbd8dacc27` (parents I1 + 6228d20)
- Conflicts resolved per E2 + D-113 F1/F2 kept; D102e test uses CB-09 (from I3)
- GUT RUN1: 523/524 FAIL (CB-10 invent leftover); RUN2: 524/524 SE=0 after merge recommit
- Golden: ERROR=0 SCRIPT_ERROR=0 md5 `52c1ef2b80d2d94f967d47928568e5f2` (matches prior int-1756 I3)
- Compare vs I1: land_rent/vacancy_tax/city_spend/note/buildings — see compare.txt
