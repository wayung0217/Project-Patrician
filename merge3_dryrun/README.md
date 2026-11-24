# merge³ dry-run (NO push to int-1758, NO PR merge)

- main: `e07bb3c` (CI green)
- int-1758 pre: `71b094d`
- dry int+main tip (= refreshed #85 tip): `0b0e22044b126559e3d5d54173358f81e44a304d`
- Conflict resolution (prefer main): ci.yml, run_m1b.ps1, run_m1b_README.md, run_m1b_report.gd
- CI files BYTE_MATCH vs main
- Diff vs origin/int-1758: product + CI from main (WP27 included)
- Diff vs main: see diff_stat_vs_main (expect empty or int-only leftovers)
- **Await Owner approve merge³** — do not self-merge
