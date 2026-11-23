# Step M — merge #59 only

## Merge
- Method: `PUT .../pulls/59/merge-async` (stack blocks sync merge); `merge_method=merge`, `merge_action=direct_merge`
- UUID: `329b6112-017f-4c9b-ad23-5b729a1b8f59` → status=merged
- Merge SHA: `17de2051ff9df56c9a2b9ee9e4254a293cd4066c`
- #60 remains OPEN (not merged); branch `cursor/wp63-building-fix-c24c` deleted after

## Pre (main `f56de55`)
| Gate | Result | Notes |
|------|--------|-------|
| GUT unit+property | 497/497 SE=0 | RUN1 |
| GUT UI | FAIL then PASS 6/6 | RUN1 wiped data; RUN2 after `git checkout HEAD -- data/` |
| Golden 360 | FAIL then PASS ERROR=0 | RUN1 missing opening_population/demand; RUN2 OK md5 `0ca3bf45…` |

## Post (main `17de205`)
| Gate | Result |
|------|--------|
| GUT unit+property | 510/510 SE=0 (+WP-63 tests) |
| GUT UI | 6/6 (after data restore) |
| Golden 360 | ERROR=0 SCRIPT_ERROR=0 md5 `995f4f37…` |

## Compare pre→post
Same columns as E3 I1 vs base (WP-63 F3 garrison): city_balance_li / goods_stock_weeks_json / goods_window_qty_json / buildings_json from day 104. See `post/compare.txt`.
