# evening-17-69-integration — I1–I4 order report

**Mode:** order report only. **No merge. No tag. No `z-1758-3`.**  
**Orphan deliverable (H5):** `review/evening-17-69-int`  
**Pack body / tip:** see `orphan_sha.txt` / `tip_sha.txt`  
**Tree:** see `ls-tree.txt` (name+size)  
**Store pack:** `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-69-integration/` (store alone ≠ delivered)

## L2 tip bump `b28012c` (ci.yml unchanged)

| Ref | SHA |
|-----|-----|
| L2 | `b28012ca49407433e229e8cfc698e083e7680e8f` |
| L3 `<L3 tip>` | `da3d911a9a6882d85a4d1bee523b78e9af0ad365` |
| L4 | `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70` |
| I1 | clean (`w4_conflicts_b28012c.txt`) |

---

## L2 tip bump `1baa133` (ci.yml unchanged)

| Ref | SHA |
|-----|-----|
| L2 | `1baa133c50c671da0d7111f8e157d5c58cf30697` |
| L3 `<L3 tip>` | `da3d911a9a6882d85a4d1bee523b78e9af0ad365` (no retransplant) |
| L4 | `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70` |
| I1 | clean (`w4_conflicts_1baa133.txt`) |

---

## Tip refresh — L3 `da3d911` / L2 `19d1a4e`

| Ref | SHA |
|-----|-----|
| L2 | `19d1a4e862e0dbe5ef15f9deb36721cc3690df48` |
| L3 `<L3 tip>` | `da3d911a9a6882d85a4d1bee523b78e9af0ad365` |
| L4 | `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70` |
| I1/I2 | clean |
| I3 | 3× ci.yml + `git checkout da3d911… -- .github/workflows/ci.yml` |
| Evidence | `w4_refresh_da3d911.md` · `i3_l4_rebase/onto_da3d911/` |

---

## 補正三 W4+W5 (N-06 / N-07)

| Item | Value |
|------|-------|
| L2 tip | `6a731ff051874c767be52c1904df898e294c180f` |
| L3 tip `<L3 tip>` | `7fa076588979635a8f5d58a35430d7c8af457f8e` |
| L4 tip | `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70` |
| I1/I2 | clean (W4 re-run) |
| I3 | 3× `ci.yml`; then `git checkout 7fa0765… -- .github/workflows/ci.yml` |
| L2 adds | **3× EX-05-09** (see `i4_gate_baseline/l2_tests_added.txt`) |
| C-01 | pending docs stamped **已被 Owner 追認取代** |
| Detail | `w4_w5_note.md` · `i3_mandatory.md` · `tips.txt` |

If Lane2 W1/W2 changes `ci.yml`, wait for Lane3 retransplant then re-refresh `<L3 tip>`.

---

## Refresh — R9-73 INT-1 (+ current L2/L3 tips)

| Ref | SHA |
|-----|-----|
| L2 tip | `bb1b50d3bd91ba33df3393babc7c0e5de3147edf` (ANSI name parse; was `b998cea`) |
| L3 tip | `1182da0cb0867e235d1b2ddf73abf6ed14cb01d6` (re-transplant; was `e1dd426`) |
| L4 tip | `ddc2447484468670aca114e62bd6e84555510b65` |
| **paths.txt** | **DELETED — no revive** |
| INT-1 | `i3_mandatory.md` — mandatory `git checkout <L3 tip> -- .github/workflows/ci.yml`; no `==608` |
| H-1 | `h1_deletable_branches.md` |

See also `resync_b998cea.md` / `resync_c13c5bd.md`.

### paths.txt deleted

`gut_unit_property_baseline_paths.txt` removed on L2 (`b998cea`); L3 transplant has **no** paths file (`PATHS_ABSENT_OK`). Was unused by `ci.yml`. Remaining under `.github/ci/`: `gut_unit_property_baseline_names.txt` + `README.md`.

### Ownership (甲) — not C-01

Owner 追認: `.github/ci/` **is** Lane2 item 2.4 ownership. Gate prints `ADDED_NAMES`/`REMOVED_NAMES`; REMOVED non-empty fails. See `c01_github_ci_ownership_ratified.md`.

## Order (authoritative)

| Step | Action | Base | Tip | Dry-run result |
|------|--------|------|-----|----------------|
| **I1** | L2 #84 → **main** | `main` | **`bb1b50d`** | clean expected (CI-only delta from `b998cea`) |
| **I2** | L3 #85 → **int** | `int-1758` | **`1182da0`** | clean expected |
| **I3** | L4 #83 **rebase** onto int-with-new-workflow | I2 (`<L3 tip>`) | `ddc2447` | **3× `ci.yml`**; then **mandatory** `git checkout <L3 tip> -- .github/workflows/ci.yml` |
| **I4** | Gate baseline ↔ L4 tests | — | names-only; L2 adds **3**; **no `==608`** | `gate_vs_l4.md` |

`int-with-new-workflow` = `int-1758` + current L3 tip (`ci.yml` + names + README; **no paths.txt**).

## Tips used

```
L2 bb1b50d3bd91ba33df3393babc7c0e5de3147edf  #84
L3 1182da0cb0867e235d1b2ddf73abf6ed14cb01d6  #85  ← <L3 tip> for I3 checkout
L4 ddc2447484468670aca114e62bd6e84555510b65  #83
```

**paths.txt gone.** See `tips.txt` for blobs / orphans.

## I1 — L2 #84 → main

- Prior cleans: `2e845b9` / `c13c5bd` / `b998cea`.
- Tip now `bb1b50d` (ANSI strip in gate name extract). **paths.txt** still deleted.

## I2 — L3 #85 → int

- Tip now `1182da0` (re-transplant of `bb1b50d` `ci.yml`). **No paths.txt.**
- Use current **`<L3 tip>`** as `int-with-new-workflow`.

## I3 — L4 #83 rebase onto int-with-new-workflow (INT-1)

Replay: `git rebase --onto <I2> origin/int-1758` from `ddc2447` (13 commits).  
**Authoritative rules:** `i3_mandatory.md`.

### Conflicts (dry-run pattern)

| # | Commit | File | Hunks | Theme |
|---|--------|------|-------|-------|
| 1 | `d55526f` | `ci.yml` | 12 | L3 set-diff vs L4 `== 555` |
| 2 | `04f4891` | `ci.yml` | 3 | L3 set-diff vs L4 `== 600` |
| 3 | `863c936` | `ci.yml` | 3 | L3 set-diff vs L4 `== 608` |

No content conflicts on L4 product paths during replay.

### Mandatory resolution (R9-73 INT-1)

1. At each conflict: **ours = onto (L3 workflow)**.
2. **After rebase finishes (mandatory):**
   ```bash
   git checkout <L3 tip> -- .github/workflows/ci.yml
   ```
   Placeholder `<L3 tip>` = current `#85` SHA in `tips.txt`. Conflict “ours” alone is insufficient (later L4 commits can still drift the file).
3. **No `==608`** (and no `==600` / `==555`) on the rebased tip.
4. **No `paths.txt` revive.**
5. Keep L4 product + D-123 tests only.

Full markers/sides: `i3_l4_rebase/onto_d88abb3/step{1,2,3}_*`.

## I4 — Gate baseline vs L4 tests

| Item | Value |
|------|-------|
| L2/L3 gate | Passing ≥ **555** AND REMOVED_NAMES empty; print ADDED/REMOVED (Owner 追認乙) |
| Baseline source | `.github/ci/gut_unit_property_baseline_names.txt` only (**paths.txt deleted — no revive**) |
| L2 adds | **3× EX-05-09**; expected ≥558 on main |
| L4 adds | 8× D-123 (`test_K1a`…`test_K4_f1_note_…`) |
| L4 old gate | hard `==608` — **must not survive I3** |

### Interaction

- Source scan: all **555** baseline names exist on `main`, `int-1758`, `ddc2447`, `19280e7` (`baseline_missing=0`).
- Int already has ~606 `test_*` funcs; L4 tip ~614. Extra int/L4 tests are fine under ≥+set-diff (they raise count; they need not be listed in the 555 file).
- After I3 with L3 `ci.yml`: D-123 tests **must still pass**, but gate no longer pins exactly 608.
- **Do not** re-apply L4 `==608` after rebase (INT-1).
- **Do not** restore `paths.txt` (INT-1).
- After I3: **`git checkout <L3 tip> -- .github/workflows/ci.yml`** (INT-1 mandatory).

### Cross-track overlap (not in I1–I3 path, future risk)

| File | L2 (→main) | L4 (→int) | Note |
|------|------------|-----------|------|
| `cash_ledger.gd` | D-124 stock bound (Dictionary/`container_id`) @ `c13c5bd` | stock-cap via `make_market` | same feature, different form; future main↔int merge conflict |
| `test_sys23_wp27.gd` | BuildingEconomy unload | **identical** hunk | clean if both land |
| `ci.yml` | L2/L3 `@v5` set-diff | L4 `@v7` + hard counts | resolved by keeping L3 |

## CI status (H2/H3 — not claimed green)

See lane packs for tip runs (`b998cea` / `e1dd426`). **Do not merge** until Owner accepts packs.

## H-1 deletable branches

See `h1_deletable_branches.md` (list only; **no deletes performed**).

## Hard constraints observed

- H1: no merge / no tag / no z-1758-3
- H5: orphan `review/evening-17-69-int` (not SharePoint / not store-only)
- H7: `git_branch_r.txt` (review/* orphans exempt from 8-cap per H5)
- INT-1: checkout L3 `ci.yml`; no `==608`; no paths.txt revive
- H-1: deletable list only

## Local dry-run SHAs (never pushed to main/int)

| Label | SHA |
|-------|-----|
| I1 main+L2 | `ba68eed479f2dceb95284ae38d0bc362231327a3` |
| I2a int+d88abb3 | `1d6676e7112f1a7b1889338924a29875fb9bf78c` |
| I2b int+19280e7 | `c7e2d7c7ef6f5dc41230bdc1f6bc8b5383d59e5f` |
| I3a L4 rebased (ours-ci) | `2e1986b8420674f4ef2fa5a48352349d00481312` |
| I3b L4 rebased onto 19280e7 | `193d18a2287b2935251e2c485058c000b0eec856` |
