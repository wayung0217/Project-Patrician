---
cursor:
  subagentId: "bc-467e42ab-b662-5641-b33b-2acce28ee0ee"
---

# 17-72 E1 — 30d 煙霧（PR #97 tip，先驗後併）

**Verdict:** **FAIL** — `m1b-h4-smoke`／`m1b-w4-inline-cmp` 失敗；輸出未齊。未調參；未開四年正式 E；未合併 #97。

| 項 | 值 |
|---|---|
| PR | [#97](https://github.com/wayung0217/Project-Patrician/pull/97) `cursor/1772-a-data-align-2905` |
| tip | `e45865b932ce5599cebada004b2bacaf29644a24` |
| 觸發 | push tip → `tools-1758`（workflow_dispatch 403；同 17-61 H4 push 路徑） |
| Run | [45836215006](https://github.com/wayung0217/Project-Patrician/actions/runs/45836215006) |
| 開始／結束 | 2026-11-26 22:09:50–22:26:18 HKT |
| conclusion | **failure** |

## Jobs

| Job | 結果 | 備註 |
|---|---|---|
| **m1b-h4-smoke** | **failure** | job [139965660606](https://github.com/wayung0217/Project-Patrician/actions/runs/45836215006/job/139965660606)；artifact [15126520482](https://github.com/wayung0217/Project-Patrician/actions/runs/45836215006/artifacts/15126520482) |
| **m1b-w4-inline-cmp** | **failure** | job [139965660950](https://github.com/wayung0217/Project-Patrician/actions/runs/45836215006/job/139965660950)；artifact [15127165226](https://github.com/wayung0217/Project-Patrician/actions/runs/45836215006/artifacts/15127165226) |
| golden-30d | success | push 路徑無 PR compare；gated PASS |
| gut-unit 0–3／gut-ui／gut-unit-gate | success | — |

## H4 煙霧數據（Za_G0_A0 + Zb_G0_notrader，30d inline）

| Group | 狀態 | PROGRESS | summary.csv | trader_summary.csv | season_cells | flow_counts (season_ports pf1–6) |
|---|---|---|---|---|---|---|
| Za_G0_A0 | **FAIL** | `pct=100` `pop=0` `sails_cum=0` | **缺** | **缺** | **缺**（artifact 無） | **缺** |
| Zb_G0_notrader | **未跑** | — | — | — | — | — |

H4 artifact 僅有：`_scenarios/Za_G0_A0.json`、`Za_G0_A0/sim_runner.log`。  
`test -f …/summary.csv` 前即 exit 1；Zb 未進入。

## W4 旁證（同 tip，Za_G0_A0 30d；失敗於寫 summary）

子行程 `exit=1` 後父行程 abort `write_all`：

```text
SCRIPT ERROR: Invalid access to property or key 'MET-01' on a base object of type 'Dictionary'.
at: _write_summary (res://sim/csv_out.gd:196)
```

| 檔 | 有無 | 列數（含表頭） | 備註 |
|---|---|---|---|
| `season_cells.csv` | 有 | 1 | **僅表頭**（30d＜1 季，無資料列） |
| `season_ports.csv`（含 pf1–6） | 有 | 1 | **僅表頭** |
| `trader_summary.csv` | 有 | 1 | **僅表頭** |
| `summary.csv` | **缺** | — | MET-01 鍵缺失中斷 |

→ 輸出**未齊全**（H4 無三檔；W4 三檔僅空表頭且 summary 缺）。

## D-120(e) 失敗列

| # | Run／tip | 失敗 job | 原文／原因 |
|---|---|---|---|
| 1 | [45836215006](https://github.com/wayung0217/Project-Patrician/actions/runs/45836215006) @ `e45865b` | `m1b-h4-smoke` | Za_G0_A0 跑完 PROGRESS 100 後無 `summary.csv`／`trader_summary.csv` → job exit 1；Zb 未跑。 |
| 2 | 同上 | `m1b-w4-inline-cmp` | `SCRIPT ERROR: Invalid access to property or key 'MET-01' … _write_summary (csv_out.gd:196)`；subprocess job exit=1。 |

本步**未修碼、未調參、未重跑、未合併**。

## 證據路徑

`/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-72/E1/evidence/`  
（`m1b-h4-smoke/`、`m1b-w4-inline-cmp/`、`h4_job.log`、`w4_job.log`）

## 未做

- 未合併 #97；未推 `z-1758-3`／四年正式 E  
- 未改 docs/spec／ci.yml／情境數值  
- Y-b G2'／Y-c G1：既有 H4 路徑僅 G0+Zb；本輪未另開矩陣
