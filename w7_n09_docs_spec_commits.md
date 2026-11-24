# W7 N-09 — docs/spec commits on #83 (`origin/int-1758...HEAD`)

Gate asked: list each of `03_Systems.csv` / `05_TechSpec.csv` / `AI_README.csv` / `Project Patrician.xlsx` with commit hash, author, message; non-Owner → C-14 reason.

| File | Commit | Author | Message |
|------|--------|--------|---------|
| `docs/spec/03_Systems.csv` | `cb843931fd4bcdf7fd9dc86f0d91151847071986` | Cursor Agent `<cursoragent@cursor.com>` | `docs(spec): gate B9 v6.99.210 for 17-66 / D-123` |
| `docs/spec/05_TechSpec.csv` | `cb843931fd4bcdf7fd9dc86f0d91151847071986` | Cursor Agent `<cursoragent@cursor.com>` | same |
| `docs/spec/AI_README.csv` | `cb843931fd4bcdf7fd9dc86f0d91151847071986` | Cursor Agent `<cursoragent@cursor.com>` | same |
| `docs/spec/Project Patrician.xlsx` | `cb843931fd4bcdf7fd9dc86f0d91151847071986` | Cursor Agent `<cursoragent@cursor.com>` | same |

Trailer on that commit: `Co-authored-by: wayung0217 <wayung0217@users.noreply.github.com>`.

## C-14（非 Owner 提交）

- **Author is Cursor Agent, not Owner.** Reason: 17-66／D-123 dispatch required **gate B9 = docs/spec v6.99.210** before product work; agent synced workbook CSVs + xlsx onto `m1b-fix-1766` so AI_README B9 matched Owner-published D-123 text (FRM-SYS15-11 / FRM-SYS17-04 notes).
- **Not** a new Autoload／SimLoop public API invented for UI (C-14 core). Spec files are the gate artifact, not product interface surface.
- No later #83 tip commits touch these four paths (only `cb84393` in `int-1758...HEAD`).
- Current Owner gate for 補正三 is **v6.99.222**; this branch still carries the v6.99.210 gate commit until Owner directs a retag／resync (L4 does not invent newer workbook content).

Evidence command:

```bash
git log --format='%H|%an|%ae|%s' origin/int-1758..HEAD -- \
  'docs/spec/03_Systems.csv' 'docs/spec/05_TechSpec.csv' \
  'docs/spec/AI_README.csv' 'docs/spec/Project Patrician.xlsx'
```
