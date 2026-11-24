# CI links — #83 `cursor/m1b-fix-1766-3fe3`

PR: https://github.com/wayung0217/Project-Patrician/pull/83  
Tip at pack close: `ddc2447484468670aca114e62bd6e84555510b65` (mark-handled removal; CI pending)  
Prior tip watched: `863c936fddedc74732567f31589454b7cbf7ef4d`

## Tip runs (newest first)

| Run | SHA | Conclusion | URL |
|-----|-----|------------|-----|
| 45407048913 | 863c936 | in_progress@pack (gut-unit0; others green) | https://github.com/wayung0217/Project-Patrician/actions/runs/45407048913 |
| 45406994812 | 04f4891 | cancelled | https://github.com/wayung0217/Project-Patrician/actions/runs/45406994812 |
| 45401838188 | 7276658 | cancelled | https://github.com/wayung0217/Project-Patrician/actions/runs/45401838188 |
| 45397235504 | cca43ed | **failure** gut-unit(1) | https://github.com/wayung0217/Project-Patrician/actions/runs/45397235504 |
| 45397077360 | 704c7db | cancelled | https://github.com/wayung0217/Project-Patrician/actions/runs/45397077360 |
| 45396766904 | d55526f | **failure** import-clean missing `.uid` | https://github.com/wayung0217/Project-Patrician/actions/runs/45396766904 |
| 45396053042 | c49e015 | success | https://github.com/wayung0217/Project-Patrician/actions/runs/45396053042 |
| 45387149310 | b29e297 | success | https://github.com/wayung0217/Project-Patrician/actions/runs/45387149310 |
| 45375453944 | e19c853 | **failure** ERR-SYS04-06 buy qty>stock storm | https://github.com/wayung0217/Project-Patrician/actions/runs/45375453944 |
| 45375438321 | e19c853 | **failure** | https://github.com/wayung0217/Project-Patrician/actions/runs/45375438321 |
| 45369394669 | 51cc942 | **failure** ERR-SYS05-04 quote_provider null | https://github.com/wayung0217/Project-Patrician/actions/runs/45369394669 |
| 45369380896 | 51cc942 | **failure** | https://github.com/wayung0217/Project-Patrician/actions/runs/45369380896 |
| 45359729469 | ba1e644 | cancelled (hung ~3h44m K4) | https://github.com/wayung0217/Project-Patrician/actions/runs/45359729469 |

Fail excerpts: `ci/fail_*_excerpt.txt`.

## Fail summary (H3)

1. **ba1e644** — K4 SimEngine 48×30d hang; cancelled.
2. **51cc942** — K2 missing `CashLedger.set_quote_provider` → ERR-SYS05-04 spam.
3. **e19c853** — max_affordable probes qty>stock → ERR-SYS04-06 Unexpected Errors.
4. **d55526f** — import-clean: uncommitted `test_d123_opening_board_1766.gd.uid`.
5. **cca43ed** — gut-unit(1) fail (DemoQuote / stock-cap gate; fixed `7276658`).
