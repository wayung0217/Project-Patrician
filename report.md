report.md
# 17-91 Lane Q QA-READONLY-5 report

ASOF_HKT=2026-11-28 14:19:47 Asia/Hong_Kong  
main tip claimed `25a398492fa568a223fb4802adbb4f15bc40bcbb` — **actual** `25a398492fa568a223fb4802adbb4f15bc40bcbb` (match=yes)  
ONELINE=`25a3984 Merge pull request #106 from wayung0217/perf-afford-1788`  
docs/spec B9=v6.99.293 tree `cb4e2c04da3db42696644474f6c0d27c6b862c22`  
Bounds: no code change / no PR / no merge / no sim run / facts only (L-甲). Readonly ASAP lane.

## Tip check

```
CLAIMED=25a398492fa568a223fb4802adbb4f15bc40bcbb
ACTUAL=25a398492fa568a223fb4802adbb4f15bc40bcbb
ONELINE=25a3984 Merge pull request #106 from wayung0217/perf-afford-1788
MATCH=yes
```

## Delivered

- q1-source-a/b/c/d-*.txt — Q1 原文分檔（≤40KB）
- q2-answers.txt — Q2(a)–(f)
- q3-offtake.txt — Q3 去化
- q4-spec-vs-code.txt — Q4 FRM-SYS17-04 對碼
- q5-draft.txt — Q5 吃水
- q6-recheck.txt — Q6 17-90-P 重算
- lane.txt / report.md / orphan_* / ls-tree.txt

## S9a A 基線

- Lane: Q QA-READONLY-5（orphan only）
- Product HEAD read: `25a398492fa568a223fb4802adbb4f15bc40bcbb`（read-only；no product branch）
- Base: pinned 25a3984（不得用最新 main）
- docs/spec: B9 v6.99.293；tree SHA `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- 本線未跑 CI／未改碼／未跑模擬
- Q6 來源：orphan `review/overnight-17-90-P` SHA `8a3bc6812a7facee167d9e77106a5a2c62da72bb`；檔 artifacts/d360/trader_summary.csv 與 p4-route-matrix.txt

## S9a B 變更清單

無產品碼變更。

## S9a C 規格對照

| 項 | 題 | 本線產出 |
|----|----|----------|
| Q1 | explore／intel／offtake 原文＋grep | q1-source-*.txt |
| Q2 | 快照路徑／公開路徑／零貨／賣後／滯留／抽籤 | q2-answers.txt |
| Q3 | offtake window_qty 組成 | q3-offtake.txt |
| Q4 | FRM-SYS17-04 對碼＋tests | q4-spec-vs-code.txt |
| Q5 | 吃水 draft_limit_class | q5-draft.txt |
| Q6 | 17-90-P 五港數字重算 | q6-recheck.txt |
| Q7 | 答案＋原文；不下判斷 | 上列 |

## S9a D–G

無產品碼／無測試／無信號變更。

## S9a H 偏離與缺口

- brief 稱 FRM-SYS17-04「r2148」；本 commit L2148＝TST-SYS17-03 草案；現行 FRM-SYS17-04 在 L2206–2209（已並貼）。
- 本 commit 無獨立 04_Content.csv；Q5 以 docs/spec/ports.csv 為準（brief 指定）。
- Q3 寧波／松江 window_qty 是否實際非 0＝需執行。

## S9a I 失敗執行

無。

---

## Q2–Q6 摘要（細節見分檔）

- Q2(a) 探索與一般船同 on_departed 快照；ERR-SYS15-05＝mid 失敗／mid_li<1（及 opening 路徑）。
- Q2(b) 別港得知 D：僅 seed_opening_board 與 on_arrivals 寫 _rec。
- Q2(c) 須 BUY seq≥1 才 sail；q<1 不出航。
- Q2(d) 賣完清 plan→IDLE；探索旗標當日有效、每日重抽。
- Q2(e) 賣失敗維持 OUTBOUND、不評估離港；無天數上限。
- Q2(f) n_pick=floor(n×rate)，下限 1；不限有閒置船；旗標及該散商所有船。
- Q3 window_qty＝local＋net(export−sellin)；CONSUME 自 MARKET 計入；視窗試驗值 28；寧波／松江實值需執行。
- Q4 見 q4；cold 判（港,貨）且無 cold 時不限縮＝用語不同／碼更寬。
- Q5 ports.csv／tres：2/1/3/2/2；csv_import int 直寫；UNIT-DRAFT 碼 0/1/2 與 csv 暫定 1/2/3 並陳。
- Q6 五港出航與開往與已知事實 1 全部 MATCH=yes。

## Orphan (S9d)

- Branch: `review/overnight-17-91-Q`
- Full SHA (orphan_sha.txt): `8bc13c44431f64fef741fe3e32f7d4436469f810`
- Branch tip: see `orphan_push.log` / `git ls-remote`
- URL: https://github.com/wayung0217/Project-Patrician/tree/review/overnight-17-91-Q

## FILES_TOTAL

```
lane.txt
ls-tree.txt
orphan_push.log
orphan_sha.txt
q1-source-a-1.txt
q1-source-b-1.txt
q1-source-c-1.txt
q1-source-d-1.txt
q1-source-d-2.txt
q1-source-d-3.txt
q2-answers.txt
q3-offtake.txt
q4-spec-vs-code.txt
q5-draft.txt
q6-recheck.txt
report.md
FILES_TOTAL=16
```
