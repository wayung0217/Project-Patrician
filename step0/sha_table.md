---
cursor:
  subagentId: "bc-2419abc2-0a01-5e31-8287-50adc7830638"
---

# Step0 SHA table

| Ref | Full SHA |
|-----|----------|
| pre-step0 main (0-0 B9 gate) | `8149f4e1cc5f3ccb2b616edf0bbe25224cd322db` |
| #60 merge | `cd0cadd86f9a302987cf6bcdc5e66695d152c696` |
| #64 merge (= post-0-A main) | `ade2dc8ca9b04faad03eedea26eb6754ac0607ab` |
| step0_head (product 0-1…0-4) | `8057f9f563411c51c60be1c275d91667e78468b7` |
| step0_head (CI data-restore) | `ef70d4214274d90cc6bb1150eb3d64c14e898523` |

B9=`v6.99.170`  
Draft PR: https://github.com/wayung0217/Project-Patrician/pull/71  
Branch: `cursor/step0-m1b-params-data-0638`

CI note: first tip failed `gut-unit-property` because unit wipe cleared `res://data` before UI in the same job (isolated `gut-ui` was green). Fix: restore `data/` before UI (`ef70d42`).
