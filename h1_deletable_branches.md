# H-1 — remote branches deletable (merge-base proof)

Fetched HKT 2026-11-24 23:34 HKT. `review/*` **exempt from 8-cap** (H5).

- `origin/main` = `191a7ee6aaa0f03c0cb32d6a803105fca7f95ee9`
- `origin/int-1758` = `71b094d773125cc96ee66ff65691d5219a22eedf`
- Product remotes (excl. review): **14** (8-cap target ≤8).

## Strictly deletable (tip is ancestor of main)

None among non-default remotes: no stale tip is `git merge-base --is-ancestor tip main`.

## Full inventory

| Branch | Tip | mb(main) | ⊂ main? | ⊂ int-1758? | Ahead(main) | Verdict |
| --- | --- | --- | --- | --- | ---: | --- |
| `cursor/ci-hang-1767-866d` | `bb1b50d3bd91` | `9d293ff8e67f` | no | no | 8 | **keep** · active 17-69 / tools |
| `cursor/int-1755-merge-0a6e` | `c13249e65181` | `8603d8ca6a57` | no | no | 5 | **candidate stale** · not ⊂ main; ahead=5; mb=8603d8ca6a57 — Owner confirm before delete |
| `cursor/int-1756-295f` | `7d7ee479e4ce` | `ce835f035d01` | no | no | 21 | **candidate stale** · not ⊂ main; ahead=21; mb=ce835f035d01 — Owner confirm before delete |
| `cursor/int-1757-5ae9` | `6885abaeeccd` | `0614c3109a24` | no | no | 2 | **candidate stale** · not ⊂ main; ahead=2; mb=0614c3109a24 — Owner confirm before delete |
| `cursor/int-ci-1767-866d` | `1182da0cb086` | `1252ab1a75ca` | no | no | 20 | **keep** · active 17-69 / tools |
| `cursor/lane-a-wp36-traders-26f5` | `114885290a64` | `1252ab1a75ca` | no | yes | 5 | **candidate** · ⊂ int-1758 but not main — Owner may delete after int lands / confirm |
| `cursor/m1b-fix-1766-3fe3` | `3816c239f27c` | `1252ab1a75ca` | no | no | 30 | **keep** · active 17-69 / tools |
| `cursor/ui-1755-debug-panels-ff98` | `1fd181acf501` | `8603d8ca6a57` | no | no | 6 | **candidate stale** · not ⊂ main; ahead=6; mb=8603d8ca6a57 — Owner confirm before delete |
| `diag-z-1758` | `71b094d77312` | `1252ab1a75ca` | no | yes | 16 | **candidate** · ⊂ int-1758 but not main — Owner may delete after int lands / confirm |
| `housing-1758` | `e484548e00ef` | `1252ab1a75ca` | no | yes | 1 | **candidate** · ⊂ int-1758 but not main — Owner may delete after int lands / confirm |
| `int-1758` | `71b094d77312` | `1252ab1a75ca` | no | yes | 16 | **keep** · active 17-69 / tools |
| `main` | `191a7ee6aaa0` | `191a7ee6aaa0` | yes | — | 0 | **keep** · default branch |
| `review/evening-17-55` | `add25848677b` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `review/evening-17-57` | `85627c4576e1` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `review/evening-17-69-int` | `05dfb80aa02c` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `review/evening-17-69-lane1` | `3fcfb79a5e43` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `review/evening-17-69-lane2` | `bb7d38a3e8ca` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `review/evening-17-69-lane3` | `d1af7ae214d1` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `review/evening-17-69-lane4` | `9be3f287896a` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `review/evening-17-69-lane5` | `830dac0af333` | — | — | — | — | **keep** · review orphan · 8-cap exempt |
| `tools-1758` | `bbd4975768a7` | `1252ab1a75ca` | no | yes | 6 | **keep** · active 17-69 / tools |
| `tools-1769` | `9b333c704c62` | `9d293ff8e67f` | no | no | 1 | **keep** · active 17-69 / tools |

## 8-cap note

Product heads currently >8. Stale candidates (not active 17-69): `cursor/int-1755-merge-0a6e`, `cursor/int-1756-295f`, `cursor/int-1757-5ae9`, `cursor/lane-a-wp36-traders-26f5`, `cursor/ui-1755-debug-panels-ff98`, `diag-z-1758`, `housing-1758`.
Lane1 does **not** delete remotes (no merge / no force cleanup without Owner).

Proof commands used: `git merge-base origin/main <ref>`, `git merge-base --is-ancestor <ref> origin/main`, same vs `origin/int-1758`.
