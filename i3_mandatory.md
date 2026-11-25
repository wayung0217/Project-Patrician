# INT-1 — I3 mandatory rules (R9-73 / W4 refresh)

When rebasing L4 `#83` onto **int-with-new-workflow** (I2 = L3 tip):

## 1. After rebase finishes — mandatory

```bash
git checkout <L3 tip> -- .github/workflows/ci.yml
```

- **`<L3 tip>`** = current `#85` head = **`da3d911a9a6882d85a4d1bee523b78e9af0ad365`**
- Concrete:
  ```bash
  git checkout da3d911a9a6882d85a4d1bee523b78e9af0ad365 -- .github/workflows/ci.yml
  ```
- Blob must equal `e96d3a12386a4082d053a3ec80c39cda2144b03d` (BYTE_MATCH L2/L3).
- Conflict “ours” alone is insufficient.

## 2. No `==608` (or `==600` / `==555`)

## 3. No `paths.txt` revive

## 4. No merge

## Dry-run tips (this refresh)

| Lane | Tip |
|------|-----|
| L2 | `b28012ca49407433e229e8cfc698e083e7680e8f` |
| L3 | `da3d911a9a6882d85a4d1bee523b78e9af0ad365` |
| L4 | `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70` |

Evidence: `i3_l4_rebase/onto_da3d911/` (INT-1 blob match OK).

L2 tip `1baa133` is tests-only vs `19d1a4e` (`ci.yml` unchanged) — L3 not retransplanted.

L2 tip `b28012c` is tests-only (A21 push_error) vs prior — `ci.yml` unchanged; L3 not retransplanted.
