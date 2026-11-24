# 17-70 T2 — D-129 甲（#83 docs/spec 清空）S9a

## 結論
自 `cursor/m1b-fix-1766-3fe3` 以**新 commit**（不改寫歷史）還原 `cb84393` 對四個 `docs/spec` 檔的改動，使 `origin/int-1758...HEAD -- docs/spec` **diff 為空**。未 rebase int（留第三節 ④）。未合併、未打 tag。

## S9a A 基線
- Branch: `cursor/m1b-fix-1766-3fe3`（#83 → `int-1758`）
- Tip（T2 後）: `39d199de43b7cb059cc9ac5c64e77b04834015cf`
- Prior tip: `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70`
- Gate: Owner 匯出 **v6.99.222** 為準；#83 不再攜帶 agent gate v6.99.210 workbook 改動
- Drop commit: `39d199d` — `chore(17-70): D-129 drop cb84393 docs/spec from #83 (T2)`

## S9a B 變更
僅還原：
1. `docs/spec/03_Systems.csv`
2. `docs/spec/05_TechSpec.csv`
3. `docs/spec/AI_README.csv`
4. `docs/spec/Project Patrician.xlsx`

方法：`git checkout origin/int-1758 -- <四檔>` + 正向 commit（H6 不改寫歷史）。

## S9a C 規格
D-129 甲：自 #83 移除 cb84393 四檔；以 v6.99.222 為準。本步不改產品邏輯。

## S9a D 介面
無公開 API 變更。

## S9a E 掃描
`git diff --name-only origin/int-1758...HEAD -- docs/spec` → **空**（見 `docs_spec_paths_after.txt`）。

## S9a F 測試／CI
- Tip CI run: https://github.com/wayung0217/Project-Patrician/actions/runs/45565408733 （head `39d199d`；pack 寫入時 in_progress，結論見 `ci_run.json`／後續更新）
- 產品碼本 commit 未改；預期與 `4d05f0d` 綠相同（僅 workbook 還原）

## S9a G 排程
無 SimLoop／信號變更。

## S9a H 偏離／缺口
- 不在本步把 int／#83 tip 升級到完整 v6.99.222 內容；只保證 **PR 相對 int-1758 的 docs/spec 為空**，權威 workbook 由 Owner 匯出路徑維護。
- Rebase 到最新 int：留合併序 ④。

## S9a I 交付
- Orphan: `review/1770-t2`（本包）
- Store: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/1770-t2/`
- 證據：`docs_spec_diff_stat_before.txt`／`_after.txt`、`four_paths.txt`、`drop_commit_*`、`ci_run.json`

## docs/spec diff 證明

### Before (`int-1758...4d05f0d`)
```
 docs/spec/03_Systems.csv         |   8 +-
 docs/spec/05_TechSpec.csv        | 168 +++++++++++++++++++++++++++++++++++++--
 docs/spec/AI_README.csv          |  32 +++++++-
 docs/spec/Project Patrician.xlsx | Bin 1824768 -> 1849856 bytes
 4 files changed, 198 insertions(+), 10 deletions(-)
```

### After (`int-1758...39d199d`)
```
(empty)
```

`DOCS_SPEC_DIFF_EMPTY=1`
