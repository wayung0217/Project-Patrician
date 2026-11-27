report.md
# 17-87 Lane Q QA-READONLY report

ASOF_HKT=2026-11-28 00:17 Asia/Hong_Kong  
main tip claimed `dcea87f` — **actual** `dcea87f338f3bea4b49197ce3cbb1c407a28a250` (match)  
docs/spec B9=v6.99.293 tree `cb4e2c04da3db42696644474f6c0d27c6b862c22`  
AI_README tip commit `7f75415675c38923233b5d54d29754822b6fd105`  
Bounds: no code change / no PR / no merge / facts only (L-甲).

## Tip check

```
CLAIMED=dcea87f338f3bea4b49197ce3cbb1c407a28a250
ACTUAL=dcea87f338f3bea4b49197ce3cbb1c407a28a250
ONELINE=dcea87f Merge pull request #104 from wayung0217/progress-day-1785
MATCH=yes
```

## Delivered

- `q1-source.txt` — Q1(a)(b)(c)(d) full untruncated sources + greps
- `q2-branches.txt` — non-review remote branch inventory (13)
- `q3-d104c.txt` — D-104(c) ①–⑥ vs tip code
- `lane.txt`
- `report.md` — this file
- (orphan root) `orphan_push.log` `orphan_sha.txt` after push

## S9a A 基線

- Lane: Q QA-READONLY (orphan only)
- Product HEAD: `dcea87f338f3bea4b49197ce3cbb1c407a28a250` (read-only; no product branch)
- Base: origin/main `dcea87f338f3bea4b49197ce3cbb1c407a28a250`
- docs/spec: B9 v6.99.293；tree SHA `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- main 基線測試：gate baseline names file 555 lines (`.github/ci/gut_unit_property_baseline_names.txt`); 17-86／R9-88 記 TOTAL_PASSING≥611 — 本線未跑 CI

## S9a B 變更清單

無產品碼變更。`git diff --stat origin/main...HEAD` on working tree for this lane = N/A（未開產品分支）。

## S9a C 規格對照

| 項 | 規格 | 本線產出 |
|----|------|----------|
| Q1 | 原文貼出 max_affordable_qty／board_for／grep／候選迴圈 | `q1-source.txt` |
| Q2 | 非 review 遠端分支盤點 | `q2-branches.txt` |
| Q3 | D-104(c) 六項對照 | `q3-d104c.txt` |
| Q4 | 答案＋原文 | 本報告＋上列三檔 |

## S9a D 介面清單

無（不改碼）。

## S9a E 自查掃描

N/A（無 .gd 變更）。未跑 E(1)–(6)。

## S9a F 測試

無新增／刪除／改測。未觸發 CI。

## S9a G 排程與信號

無。

## S9a H 偏離與缺口

- 派工寫 03_Systems **r2118**；tip `docs/spec/03_Systems.csv` 實體行 **2169** 含 D-104(c) 效能約束六項原文（已在 q3 標明）。
- 17-86 p0 EXCL_REVIEW=14（含已刪 `cursor/perf-probe-1786-c952`）；本線盤點 **13**＝main＋12。
- Q 線不下「為什麼慢／該怎麼改」。

## S9a I 格式／失敗執行

失敗執行：無（只讀＋orphan push）。

---

## Q1 答案＋原文

見 `q1-source.txt`（全文不截斷）。

**(a)** `CashLedger.max_affordable_qty` = `autoload/cash_ledger.gd:659-727`；同檔呼叫 `balance` 458-464、`_quote_buy_total` 842-857、`_record_error` 1010-1013、`_err` 1016-1018。

**(b)** `IntelLedger.board_for` = `autoload/intel_ledger.gd:413-426`。

**(c)** `git grep -n 'max_affordable_qty'` → 48 行；`git grep -n 'board_for'` → 57 行（全文在 q1）。

**(d)** 候選迴圈 `_evaluate_and_maybe_sail` `autoload/trader_registry.gd:721-937`（L780 呼叫 max_affordable_qty；L784→`_dest_intel` 972-997→L980 `board_for`）。

## Q2 答案＋原文

見 `q2-branches.txt`。NON_REVIEW_COUNT=13。每行含 tip_HKT／author／subject／ancestor／ahead／behind／PR。不刪分支、不關 PR。

## Q3 答案＋原文

見 `q3-d104c.txt`。摘要：①已落實 ②未落實 ③已落實 ④部分 ⑤已落實 ⑥未落實。

## Q4

上列 Q1–Q3 皆「答案＋原文」；無「無法取得」項。

## Orphan (S9d)

- Branch: `review/overnight-17-87-Q`
- SHA: see `orphan_sha.txt` after push
- `git ls-tree` embedded in report after push

## B-10 ls + FILES_TOTAL

(filled after final ls)
