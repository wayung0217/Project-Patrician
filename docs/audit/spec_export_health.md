# N1 規格匯出區健檢（17-76）

- **Pack:** 17-76 / lane=AUDIT
- **Repo tip audited:** `e2a99d26df99d640977f4699073bbc85dc48f82f` (`origin/main` at worktree create)
- **Scope:** `docs/spec/*.csv`（28 files）；結構自洽只讀檢查；**未改任何 CSV（C-14）**
- **Method:** UTF-8 decode with `errors=replace`; strip BOM for header/key parse; `csv.reader` on splitlines; blank = all cells empty/whitespace

## 總表

| 檔名 | 總行數 | 資料列（扣表頭） | 有效資料列（去尾空白） | 欄數 | 異常碼 | 證據摘要 |
|---|---:|---:|---:|---:|---|---|
| `00_Overview.csv` | 143 | 142 | 142 | 5 | `BLANK_TAIL_COLS,MID_BLANK,BOM` | BOM; LF:156; tail_blank_cols=4; mid_blank=10 |
| `03_Systems.csv` | 3207 | 3206 | 3206 | 21 | `BLANK_TAIL_COLS,MID_BLANK,MIXED_EOL,BOM` | BOM; MIXED_EOL(CRLF:3207,LF:85); tail_blank_cols=20; mid_blank=236 |
| `05_TechSpec.csv` | 973 | 972 | 972 | 10 | `BLANK_TAIL_COLS,MID_BLANK,MIXED_EOL,BOM` | BOM; MIXED_EOL(CRLF:973,LF:3378); tail_blank_cols=9; mid_blank=18 |
| `AI_README.csv` | 648 | 647 | 647 | 6 | `BLANK_TAIL_COLS,MID_BLANK,MIXED_EOL,BOM` | BOM; MIXED_EOL(CRLF:648,LF:53); tail_blank_cols=5; mid_blank=9 |
| `acct_reason_map.csv` | 15 | 14 | 14 | 5 | `BOM` | BOM; LF:15 |
| `ai_profiles.csv` | 5 | 4 | 4 | 4 | `BOM` | BOM; LF:5 |
| `build_queue.csv` | 354 | 353 | 353 | 4 | `BOM,DUP_port_id,DUP_cb_id` | BOM; LF:354 |
| `buildings.csv` | 49 | 48 | 48 | 10 | `BOM,EMPTY_output_good_id,EMPTY_input1_good_id,DUP_input1_good_id,EMPTY_input2_good_id,DUP_input2_good_id` | BOM; LF:49 |
| `city_center.csv` | 17 | 16 | 16 | 2 | `BOM` | BOM; LF:17 |
| `demand_rates.csv` | 29 | 28 | 28 | 4 | `BOM` | BOM; LF:29 |
| `event_defs.csv` | 1 | 0 | 0 | 11 | `BOM` | BOM; LF:1 |
| `event_script.csv` | 1 | 0 | 0 | 5 | `BOM` | BOM; LF:1 |
| `frm_examples.csv` | 47 | 46 | 46 | 9 | `BOM,DUP_frm_id` | BOM; LF:47 |
| `goods.csv` | 29 | 28 | 28 | 8 | `BOM` | BOM; LF:29 |
| `lanes.csv` | 56 | 55 | 55 | 7 | `BOM,DUP_region_id` | BOM; LF:56 |
| `nodes.csv` | 30 | 29 | 29 | 5 | `BOM` | BOM; LF:30 |
| `opening_population.csv` | 17 | 16 | 16 | 4 | `BOM` | BOM; LF:17 |
| `opening_public.csv` | 117 | 116 | 116 | 3 | `BOM,DUP_port_id,DUP_cb_id` | BOM; LF:117 |
| `opening_workshops.csv` | 89 | 88 | 88 | 3 | `BOM,DUP_port_id,DUP_good_id` | BOM; LF:89 |
| `ports.csv` | 17 | 16 | 16 | 5 | `BOM,DUP_regime_id` | BOM; LF:17 |
| `price_curve.csv` | 6 | 5 | 5 | 2 | `BOM` | BOM; LF:6 |
| `regions.csv` | 8 | 7 | 7 | 3 | `BOM` | BOM; LF:8 |
| `role_cells.csv` | 449 | 448 | 448 | 5 | `BOM,DUP_port_id,DUP_good_id` | BOM; LF:449 |
| `satisfaction_weights.csv` | 29 | 28 | 28 | 4 | `BOM` | BOM; LF:29 |
| `sim_overrides_draft.csv` | 99 | 98 | 98 | 8 | `BOM,DUP_prm_id` | BOM; LF:99 |
| `substitutions.csv` | 8 | 7 | 7 | 4 | `BOM,DUP_good_id` | BOM; LF:8 |
| `tax_rates.csv` | 21 | 20 | 16 | 3 | `BLANK_TAIL_ROWS,BOM` | BOM; LF:21; tail_blank_rows=4 |
| `zones.csv` | 62 | 61 | 61 | 6 | `BOM,DUP_port_id` | BOM; LF:62 |

## 關鍵觀察（非阻斷）

1. **AI_README B9 版本戳：** 儲存格 B9（列「版本」）＝ **`v6.99.283`**。派工背景寫「停在 v6.99.227」——**本次匯出已追上派工戳**，不再落後。證據：`docs/spec/AI_README.csv` 列9欄B；指令 `python csv.reader` 讀 `rows[8][1]`。
2. **opening_workshops 空白尾：** 總行 89（含表頭）、空白資料列 **0**。派工背景「工作簿端曾有 360 列空白尾巴」——**repo 現況無此尾巴**（可能已在匯出端清掉）。
3. **跨檔參照（BOM 剝除後）：** `role_cells` / `opening_*` / `zones` / `tax_rates` / `build_queue` / `demand_rates` / `satisfaction_weights` / `substitutions` / `buildings`（非空 good_id）/ `lanes.node_a|node_b|region_id` → 對 `ports`/`goods`/`nodes`/`regions` **全部命中，0 落空**。
4. **acct_reason_map 列舉：** 14 資料列之 `line_code` 皆∈ `03_Systems.csv:3114` 列舉；`accrual_kind` 皆∈ `03_Systems.csv:3117`（含 NONE／D-140）；`activity` ∈ {OPERATING, INVESTING, FINANCING}（`03_Systems.csv:3212`）。**無列舉外值。**
5. **欄數不齊：** 28 張表 **COL_MISMATCH = 0**。
6. **U+FFFD / NUL：** 全檔 **0**。

## 異常清單

### A. UTF-8 BOM（28/28）

全部 `docs/spec/*.csv` 檔首為 `EF BB BF`。Excel／工作簿匯出常見。鍵名解析須 strip BOM，否則 `port_id` 會變成 `\ufeffport_id`（初掃曾因此假報全部 xref 失敗）。

證據：`Path.read_bytes()[:3].hex()` → `efbbbf`（例：`AI_README.csv`、`ports.csv`）。

**缺口（等裁決）：** 是否規定匯出去 BOM，或 csv_import／稽核一律 strip？本項只記錄。

### B. 混用 CRLF/LF（3）

| 檔 | endings 計數 |
|---|---|
| `03_Systems.csv` | CRLF:3207, LF:85 |
| `05_TechSpec.csv` | CRLF:973, LF:3378 |
| `AI_README.csv` | CRLF:648, LF:53 |

其餘 25 張為純 LF。敘事大表細胞內換行（LF）+ 列分隔 CRLF 會被計為 mixed——需 Owner 判定是否視為異常或可接受。

### C. 空白尾列（1）

- **`tax_rates.csv`**：有效資料 16 列；檔案行 18–21 為空白列 `["","",""]`（共 4 尾空白）。
  - 證據：最後非空 `["PT-16","FLOW","33333"]`（行17）；其後四行皆空。

**缺口：** 是否清尾（僅 Owner／工作簿可改，C-14）。

### D. 空白尾欄（4，皆敘事表）

表頭尾欄為空字串（匯出寬度 > 實際有名欄）：

| 檔 | 尾空欄數 | 表頭（strip BOM 後） |
|---|---:|---|
| `00_Overview.csv` | 4 | `['00_Overview — 專案主軸、現況與缺口｜暫定遊戲名稱：《銀與絲：東海商人》（Silver & Silk: Merchants of the Eastern Seas）', '', '', '', '']` |
| `03_Systems.csv` | 20 | `['03_Systems — 系統規則、公式、參數框架與驗收規格（Phase 0：規格環境與依賴盤點）', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']` |
| `05_TechSpec.csv` | 9 | `['05_TechSpec — Phase 0 代碼實作落實書（給 Cursor）v0.4', '', '', '', '', '', '', '', '', '']` |
| `AI_README.csv` | 5 | `['AI_README — AI 責任、工作範圍與工作流程', '', '', '', '', '']` |

資料表（ports/goods/…）無此碼。

### E. 中段空白列（敘事表結構分隔）

| 檔 | 中段空白列數 | 樣例行號 |
|---|---:|---|
| `00_Overview.csv` | 10 | [3, 20, 32, 42, 58] |
| `03_Systems.csv` | 236 | [3, 11, 40, 67, 90] |
| `05_TechSpec.csv` | 18 | [3, 21, 42, 58, 180] |
| `AI_README.csv` | 9 | [3, 21, 37, 69, 71] |

解讀：節與節之間的空列，非資料損壞。**缺口：** 是否納入「允許的結構空白」白名單。

### F. `*_id` 空值

#### `buildings.csv`

- `output_good_id` 空：**20** 列（RB-01、WH-01、CB-01…CB-18）——非生產建築，空輸出料預期行為。
- `input1_good_id` 空：**32**；`input2_good_id` 空：**42**——無該輸入的配方。
- 證據例：行2 `RB-01,0,0,0,,,,,,RESIDENTIAL`（output/input 皆空）。
- 非空的 input/output good_id **全部**可在 `goods.csv` 找到。

**缺口：** 空 `*_id` 對非生產建築是否正式允許（建議規格註記，勿當資料錯誤清掉）。

### G. `*_id` 單欄重複（多為複合鍵表——單欄本就不唯一）

稽核要求逐欄掃 `*_id`；下列重複在**複合主鍵**表屬預期，列為觀察而非損壞：

| 檔 | 欄 | dup 事件數 | 複合鍵檢查 |
|---|---|---:|---|
| `role_cells.csv` | port_id / good_id | 432 / 420 | `(port_id,good_id)` **0 dup** |
| `opening_workshops.csv` | port_id / good_id | 72 / 60 | `(port_id,good_id)` **0 dup** |
| `opening_public.csv` | port_id / cb_id | 100 / 100 | 多列／港預期 |
| `build_queue.csv` | port_id / cb_id | 337 / 339 | 佇列多列預期 |
| `zones.csv` | port_id | 45 | 每港多區預期 |
| `lanes.csv` | region_id | 48 | 多航段／區預期 |
| `ports.csv` | regime_id | 4 | 非主鍵；政體標籤共用（例「明」×4） |
| `substitutions.csv` | good_id | 1 | 同 good 可有多替代？見缺口 |
| `frm_examples.csv` | frm_id | 30 | **example 表**：同 FRM 多例預期（鍵應為 `example_id`） |
| `buildings.csv` | input1/2_good_id | 2 / 3 | 多建築共用原料，非主鍵 |

#### 需裁決的真重複候選

1. **`sim_overrides_draft.csv` `prm_id=PRM-SYS08-ZONE_OPEN_COST_LI` 出現兩次**
   - 行71：`[2000000,4000000,6000000,8000000]` status=試驗值（非正式） basis=OQ-14l…
   - 行92：`[0,5000000,10000000,20000000,40000000]` status=試驗值（非正式） basis=D-100…
   - **缺口：** 草稿表允許同鍵多試驗列，或應只留一列？不改檔，等 Owner。

2. **`substitutions.csv`**：`good_id` 有 1 次重複事件——請確認是否允許同一 good 多個 `substitute_id`（若是，複合鍵應為 `(good_id,substitute_id)`）。

### H. 事件表空殼

- `event_defs.csv`：僅表頭 11 欄，**0 資料列**
- `event_script.csv`：僅表頭 5 欄，**0 資料列**

可能尚未填內容；記錄現況。

## 缺口彙總（B-4 / C-05，只列不動手）

1. 匯出是否去 BOM／統一 EOL？
2. `tax_rates.csv` 4 行尾空白是否清？
3. 敘事表中段空列、尾空欄是否白名單？
4. `buildings.csv` 空 good_id 是否正式允許？
5. `sim_overrides_draft.csv` 同 `prm_id` 雙列如何處置？
6. `substitutions` 主鍵語意（單 good 多替代）？

## 指令複現

```bash
# worktree @ e2a99d2
python3 n1_scan.py   # 結構 / xref / anomaly
```

本報告路徑：`docs/audit/spec_export_health.md`
