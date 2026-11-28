report.md
# 17-89 Lane Q QA-READONLY-3 report

ASOF_HKT=2026-11-28 13:07:24 Asia/Hong_Kong  
main tip claimed `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6` — **actual** `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6` (match=yes)  
ONELINE=`aa098a8 Merge pull request #105 from wayung0217/perf-afford-1787`  
docs/spec B9=v6.99.293 tree `cb4e2c04da3db42696644474f6c0d27c6b862c22`  
Bounds: no code change / no PR / no merge / no sim run / facts only (L-甲). Readonly ASAP lane.

## Tip check

```
CLAIMED=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
ACTUAL=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
ONELINE=aa098a8 Merge pull request #105 from wayung0217/perf-afford-1787
MATCH=yes
```

## Delivered

- `q1-source.txt` — Q1(a)–(d) full sources + greps
- `q2-answers.txt` — Q2(a)–(d) 答案＋原文
- `q3-recompute.txt` — MET-01／MET-04 Python 重算 vs L artifacts
- `lane.txt`
- `report.md` — this file
- `orphan_push.log`／`orphan_sha.txt`（S9d；見推送後更新）

## S9a A 基線

- Lane: Q QA-READONLY-3（orphan only）
- Product HEAD: `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6`（read-only；no product branch）
- Base: origin/main same SHA（local tip；claimed aa098a8）
- docs/spec: B9 v6.99.293；tree SHA `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- 本線未跑 CI／未改碼／未跑模擬

## S9a B 變更清單

無產品碼變更。

## S9a C 規格對照

| 項 | 規格／題 | 本線產出 |
|----|----------|----------|
| Q1 | MET-01..06 原文＋評估季／days_override 行號＋grep | `q1-source.txt` |
| Q2 | 評估季窗口／Za 代入／逐指標取季／years 使用否 | `q2-answers.txt` |
| Q3 | L 線 d1800／d3600 重算 MET-01／MET-04 | `q3-recompute.txt` |
| Q4 | 答案＋原文格式 | 上列三檔 |

## S9a D–G

無產品碼／無測試／無信號變更。

## S9a H 偏離與缺口

- `compute(..., years, ...)` 參數存在但 `sim/metrics.gd` 本體未讀取 years（git grep 僅參數宣告 L16）。
- `sim_engine.gd` L237 註解「metrics still use years」與現碼不一致（只陳述）。
- Q3 MET-01：Python raw float 與 summary CSV 字面量差約 1e-15；`fmt14` 與 summary／brief 字面相同。MET-04 完全一致。已列於 MISMATCH_VS_SUMMARY，不下判斷。
- L artifacts 來自 product SHA `107c17f`；`metrics.gd` 相對本線讀取 SHA 無 diff。

## S9a I 失敗執行

無。

---

## Q2 摘要（答案；細節見 q2-answers.txt）

- (a) 評估季＝實際取樣季，下限 warmup_years×SEASONS_PER_YEAR；上界不受 scenario.years 裁切。
- (b) d1800：評估 4..19，最後一年 16..19；d3600：評估 4..39，最後一年 36..39。
- (c) MET-01／05a＝全部評估季；MET-02＝第一評估年＋最後一年；MET-03／04／05b＝最後一年；MET-06＝無季（conservation_hits）。
- (d) MET-01..06 皆未用 scenario.years 做分母／取樣。

## Q3 摘要

- 指標：MET-01、MET-04（可用 CSV 重算）。
- d1800：MET-01 fmt14＝0.06144306651635（eq/total＝436/7096）；MET-04＝235。
- d3600：MET-01 fmt14＝0.05948653725736（950/15970）；MET-04＝202。
- raw float ≠ float(summary) 約 1e-15 → 已列入 MISMATCH_VS_SUMMARY。

## Orphan (S9d)

- Branch: `review/overnight-17-89-Q`
- Full SHA: 見 orphan_sha.txt
- URL: https://github.com/wayung0217/Project-Patrician/tree/review/overnight-17-89-Q

