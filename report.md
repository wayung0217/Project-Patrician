# review/1770-d130 — D-130 甲

## Product
- PR: https://github.com/wayung0217/Project-Patrician/pull/87
- Branch: `cursor/d130-shard-golden-aeb7`
- Tip: `14b436342849d8d6a4dc32eb63703a2133bddfd0`
- **不合併**（等 Owner 批；須在合併⑤ #86 前）

## (1) Shard balance
unit+property 依 `func test_` 個數 greedy 4-way；wp26 不與全部 property 同片；timeout=45 不變。

## (2) Strict golden dims
兩邊列／欄必須相等；COMPARED_CELLS＝列×欄且＞0。

## (3) T4 dual CI-style outputs
見 `t4/compared_pass.out`、`t4/compared_mismatch.out`（＋ dims 樣品）。
