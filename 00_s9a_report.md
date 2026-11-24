# evening-17-69-lane4 — S9a (L4 / #83)

## 結論
L4 items **4.1–4.5** done on tip `4d05f0d`; no merge/tag; no `ci.yml`/`cash_ledger` edits. Delivered orphan **`review/evening-17-69-lane4`** (H5; no SharePoint).

## S9a A 基線
- Gate B9 = docs/spec **v6.99.210**
- Product tip: `ddc2447484468670aca114e62bd6e84555510b65` on `cursor/m1b-fix-1766-3fe3`
- PR #83 → `int-1758`
- mark-handled removal SHA: same as tip (`mark_handled_removal_sha.txt`)

## S9a B 變更
L4-owned: `diffs/l4_owned_full.patch` (intel_ledger, trader_registry, sim_loop, sim/, test_d123…).  
Evidence-only cash_ledger stock-cap: `diffs/product_stock_cap.7276658.diff` (not L4-authored).

## S9a C 規格
See `item_4_4.md` — FRM-SYS15-11 / FRM-SYS17-04 → files/fns → tests.

## S9a D 介面
`IntelLedger.seed_opening_board() -> Array` (D-123); `TraderRegistry.season_sail_count` / `season_cargo_dan`.

## S9a E 掃描
Ownership respected; no ci.yml / cash_ledger edits this lane.

## S9a F 測試
K1a–e, K2, K4 formal, K4 F1 note in `test_d123_opening_board_1766.gd`. CI: `ci_links.md` (H3 all fails listed). Tip `ddc2447` CI pending at pack; prior `863c936` gut-unit0 in progress / other shards green.

## S9a G 排程
`SimLoop.boot` one call to `seed_opening_board` after opening stock — unchanged this lane beyond prior ba1e644.

## S9a H 偏離／缺口
- **W3 D-126 甲:** status「D-126 核准（試驗值）」；代碼加註、邏輯不變。
- **W7 N-09:** `w7_n09_docs_spec_commits.md`（Cursor Agent cb84393；C-14 gate B9）。
- **W8:** band0=價格天花板、band4=價格地板；BAND-1「地板為主（87.3%）」見 `w8_band_terminology.md`。
- **D-126 (R9-73 L4-1):** FRM-SYS17-04 mid-missing rank undefined → `gaps.md` + `trace.csv` = gap/pending; `base_price_li` code kept.
- **N-04 (R9-73 L4-2):** #83 dropped `make_market` stock-cap on tip `3816c239f27cf430fa7fac5f6fc1927c379b49dd`; #84 Dictionary sole.
- Full z-1758-3 matrix totals deferred (H1 no tag).
- Pre-fix z-1758-2 trader_summary Σ sails = 0 (item_4_3).
- H7: product remotes still >8 (see `git_branch_r.txt`); `review/*` orphans exempt from cap per H5.
- No SharePoint (H5 amend: orphan only).

## S9a I Pack
Store: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-69-lane4/`  
Orphan: `review/evening-17-69-lane4` @ `9be3f287896a01fabacad800418375068fc10d44` (no PR) — `orphan_sha.txt` / `orphan_push.log` / `ls_tree.txt`.
