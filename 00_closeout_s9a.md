# 17-69 補正三 — S9a A–I 收尾報告（W10）

> **狀態：等 Owner 一次批准；未批准不合併。**  
> 本檔為 orphan 交接總結，非產品碼。規格閘門：docs/spec **v6.99.222**。

## 結論

W1–W9 證據與 orphan 已齊；W10 本包交付。**#83／#84／#85 未獲 Owner 一次批准前不合併。** 禁 tag／`z-1758-3`。Cursor 暫停。

關鍵 tip：

| 線 | PR | tip | 狀態 |
|----|-----|-----|------|
| L2 | #84 | `b28012ca49407433e229e8cfc698e083e7680e8f` | CI **9/9 success** run [45528301812](https://github.com/wayung0217/Project-Patrician/actions/runs/45528301812)；缺口＝等批准合併 |
| L3 | #85 | `da3d911a9a6882d85a4d1bee523b78e9af0ad365` | golden OK；gut-unit(3) WP27 int gap |
| L4 | #83 | `4d05f0d6c4ab465ac5f6d8f5250ac28c1de7dc70` | tip run cancelled；父 tip 曾全綠；待 INT-1 |
| L5 | #86 | `9b333c704c62fe00fe59ce1b67684de9b7e88948` | tools-only；tip run cancelled |
| int | #81 | `71b094d773125cc96ee66ff65691d5219a22eedf` | 整合幹；vs main CONFLICTING |

---

## S9a A — 基線

- Gate B9／派工：v6.99.222（補正三）。
- main `@191a7ee`（查詢時）；int-1758 `@71b094d`。
- 硬規則 H1／H2／H5／H6 遵守：驗證＝GitHub CI；交付＝`review/evening-17-69-*` orphans。
- 本 orphan：`review/evening-17-69-handoff`（僅交接檔；無產品 diff）。

## S9a B — 變更清單（彙總）

| 線 | 擁有／變更 |
|----|------------|
| L2 #84 | `cash_ledger` 庫存上界（D-125／D-124）；WP27 unload 測；`ci.yml`；`.github/ci/*`；三 EX-05-09 |
| L3 #85 | 僅移植 `.github/workflows/ci.yml` + `.github/ci/`（無產品） |
| L4 #83 | D-123 opening board／explore／season outs；W3 D-126 註；W7／W8 文件；drop make_market stock-cap |
| L5 #86 | `tools/run_m1b_report.gd`：SEED_NO_EFFECT、season／trader totals |
| int #81 | G→F→H 合併＋CI／Z 修復（既有） |
| W9 | 關 #69/#70；刪三 int-1755/6/7 遠端分支 |

## S9a C — 規格對照

- D-124／D-125／FRM-SYS05-09／EX-05-09 → #84。
- D-123／FRM-SYS15-11／FRM-SYS17-04 → #83。
- D-126 甲：試驗值核准（註解＋gaps／trace；邏輯不變）。
- W8：band0＝天花板、band4＝地板；BAND-1＝**地板為主（87.3%）**。

## S9a D — 介面

- #83：`IntelLedger.seed_opening_board()`；`TraderRegistry.season_sail_count`／`season_cargo_dan`。
- #84：`max_affordable_qty` 庫存上界（Dictionary／container_id；MarketPricer 路徑）。
- #86：report 警告／欄位（不改 PASS/FAIL）。

## S9a E — 自查

- 各線 H6 擁有檔；L3 無產品；L4 未改 `ci.yml`／`cash_ledger`（N-04 後）。
- INT-1：rebase 後強制 L3 `ci.yml`；禁 `==608`／paths.txt。

## S9a F — 測試／CI

- #84：558 passing；REMOVED＝無；ADDED＝三 EX；golden DIFF_CELLS=0／BOOTSTRAP=0。
- #85：golden success；gut-unit(3) 3 fail（WP27）。
- #83：tip cancelled；父 `3816c23` 全綠。
- #86：tip cancelled（shard0）；其餘 jobs success。

## S9a G — 排程與信號

- #83：`SimLoop.boot` → `seed_opening_board`（opening stock 後）。
- 無新 SimLoop 排程於 W10。

## S9a H — 偏離與缺口

- **等 Owner 一次批准；未批准不合併。**
- D-127 指標對商人不敏感。
- band4 87.3%（地板為主）；M1b ≤30% 閘仍未達。
- #85 WP27 int gap（待 #84→main 路徑）。
- #80/#81 vs main CONFLICTING。
- tip cancelled（#83/#86）≠產品紅；需 Owner 解讀／可選重跑。
- 未跑 `z-1758-3`（H1）。

## S9a I — Pack

| 交付 | 路徑／ref |
|------|-----------|
| Handoff orphan | `review/evening-17-69-handoff`（本包） |
| HANDOFF | `HANDOFF.md` |
| lane | `lane.txt`（lane=handoff） |
| Store 派工 | `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/internal/dispatch-17-69-w1w10.md` |
| 各線 orphan | 見 `HANDOFF.md` §5 |

**未批准不合併。Cursor 可暫停。**
