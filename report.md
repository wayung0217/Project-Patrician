report.md
# 17-88 Lane Q QA-READONLY-2 report

ASOF_HKT=2026-11-28 09:15:48 Asia/Hong_Kong  
main tip claimed `dcea87f338f3bea4b49197ce3cbb1c407a28a250` — **actual** `dcea87f338f3bea4b49197ce3cbb1c407a28a250` (match=yes)  
ONELINE=`dcea87f Merge pull request #104 from wayung0217/progress-day-1785`  
docs/spec B9=v6.99.293 tree `cb4e2c04da3db42696644474f6c0d27c6b862c22`  
Bounds: no code change / no PR / no merge / facts only (L-甲). Readonly ASAP lane.

## Tip check

```
CLAIMED=dcea87f338f3bea4b49197ce3cbb1c407a28a250
ACTUAL=dcea87f338f3bea4b49197ce3cbb1c407a28a250
ONELINE=dcea87f Merge pull request #104 from wayung0217/progress-day-1785
MATCH=yes
```

## Delivered

- `q1-source.txt` — Q1(a)–(e) full untruncated sources + greps
- `q2-spec.txt` — FRM-SYS15-06／D-37c／FRM-SYS16-04／FRM-SYS15-11／FRM-SYS15-03／TST-SYS15-10 + B9
- `q3-d28.txt` — seed_opening_board／daily_step／d28／WINDOW／DECAY
- `q4-runner.txt` — Za_G0_A0 years／--days／progress formats
- `lane.txt`
- `report.md` — this file
- `orphan_push.log`／`orphan_sha.txt`（S9d）

## S9a A 基線

- Lane: Q QA-READONLY-2（orphan only）
- Product HEAD: `dcea87f338f3bea4b49197ce3cbb1c407a28a250`（read-only；no product branch）
- Base: origin/main same SHA
- docs/spec: B9 v6.99.293；tree SHA `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- 本線未跑 CI／未改碼

## S9a B 變更清單

無產品碼變更。

## S9a C 規格對照

| 項 | 規格／題 | 本線產出 |
|----|----------|----------|
| Q1 | IntelLedger／DemandModel／MarketPricer／PopulationModel 原文＋grep | `q1-source.txt` |
| Q2 | 03_Systems FRM／D-37c／TST 原文＋B9 | `q2-spec.txt` |
| Q3 | d28 開局船報／修剪／WINDOW／DECAY | `q3-d28.txt` |
| Q4 | Za_G0_A0 years／--days／progress | `q4-runner.txt` |
| Q5 | 答案＋原文 | 本報告＋上列四檔 |

## S9a D–G

無產品碼／無測試／無信號變更。

## S9a H 偏離與缺口

- `score_loop`：main tip 無獨立函數；對應 `_place_one_in` 內 for 迴圈（PERF 名 `pop.op.place.score_loop`）。已貼該迴圈原文。
- `D-37c`：03_Systems 無以 `D-37c,` 起首之列；已貼 L2756＋05_TechSpec L570。
- Q 線不下「為什麼慢／該怎麼改」。

## S9a I 失敗執行

無。

---

## Q1–Q4

見 `q1-source.txt`／`q2-spec.txt`／`q3-d28.txt`／`q4-runner.txt`（答案＋原文；Q5 格式）。

### Q3 摘要

- (a) 開局 16×15＝240；day_taken／tick_taken／tick_arrived＝0
- (b) age≥WINDOW_DAYS 修剪；d28＋WINDOW＝28 → 移除開局船報
- (c) 是（240＝開局筆數）
- (d) WINDOW_DAYS＝28、DECAY_DAYS＝28（scenario_M1b_G0.json）

### Q4 摘要

- (a) years＝5；warmup_years＝1
- (b) `--days N` 設 days_override；N>years×360 仍跑 N 日
- (c) `DAY_PROGRESS day=<n> total=<N>`；`PROGRESS pct=… pop=… sails_cum=…`

## Orphan (S9d)

- Branch: `review/overnight-17-88-Q`
- Full SHA: 見 orphan_sha.txt（`7865afd8e789104e14fc5a53d88cdd0ee07b1095`）
- URL: https://github.com/wayung0217/Project-Patrician/tree/review/overnight-17-88-Q

### git ls-tree -r -l

```
100644 blob 7e8b173496548a2b7837912c0b5442d2947d3bce     382	lane.txt
100644 blob 9303edb13391475004bd5ddf1ced82b370b9e0c9     244	orphan_push.log
100644 blob 782fd2c3c41860029672296245f34ff75c754270      56	orphan_sha.txt
100644 blob d8209cb2cfeba6f0162eb3522885fe01e9d83455  482996	q1-source.txt
100644 blob 67cb4f431861c076a7337a654b1c90deaed1ab11    5190	q2-spec.txt
100644 blob 479c4d20b270e95ebdcefa6fbd71e55e8321df1b    6139	q3-d28.txt
100644 blob 1d93903a83c7ea2a0a7b57a8965a2571a10e2c35    7413	q4-runner.txt
100644 blob 145bfab777b29d8d20f75cc297d6e8515f20e186    4320	report.md
```

## B-10 ls + FILES_TOTAL

```
total 497
drwxrwxrwx 2 ubuntu ubuntu      0 Nov 28 01:03 .
drwxrwxrwx 2 ubuntu ubuntu      0 Nov 28 01:03 ..
-rw-rw-rw- 1 ubuntu ubuntu    382 Nov 28 01:10 lane.txt
-rw-rw-rw- 1 ubuntu ubuntu    244 Nov 28 01:15 orphan_push.log
-rw-rw-rw- 1 ubuntu ubuntu     56 Nov 28 01:14 orphan_sha.txt
-rw-rw-rw- 1 ubuntu ubuntu 482996 Nov 28 01:10 q1-source.txt
-rw-rw-rw- 1 ubuntu ubuntu   5190 Nov 28 01:10 q2-spec.txt
-rw-rw-rw- 1 ubuntu ubuntu   6139 Nov 28 01:10 q3-d28.txt
-rw-rw-rw- 1 ubuntu ubuntu   7413 Nov 28 01:11 q4-runner.txt
-rw-rw-rw- 1 ubuntu ubuntu   4320 Nov 28 01:15 report.md

```

FILES_TOTAL=8
