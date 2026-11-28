report.md
# 17-90 Lane Q QA-READONLY-4 report

ASOF_HKT=2026-11-28 13:20:01 Asia/Hong_Kong  
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

- `q1-source.txt` — Q1(a)–(e) full sources + git grep
- `q2-answers.txt` — Q2(a)–(d) 答案＋原文
- `q3-recompute.txt` — d1800 trader_summary 重算 vs 已知事實 1
- `lane.txt`
- `report.md` — this file（含 Q4）
- `orphan_push.log`／`orphan_sha.txt`（S9d；推送後更新）

## S9a A 基線

- Lane: Q QA-READONLY-4（orphan only）
- Product HEAD read: `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6`（read-only；no product branch）
- Base: pinned aa098a8（不得用最新 main）
- docs/spec: B9 v6.99.293；tree SHA `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- 本線未跑 CI／未改碼／未跑模擬
- Q3 來源：orphan `review/overnight-17-88-L` SHA `orphan_sha.txt
29472f3c367d770a03577797656b8df33d166f87`；product commit `6d1ad7331166f3a5eb366d7631f3f24bbccaa630`；檔 `artifacts/d1800/trader_summary.csv`

## S9a B 變更清單

無產品碼變更。

## S9a C 規格對照

| 項 | 題 | 本線產出 |
|----|----|----------|
| Q1 | eval/sail/explore/allocation/sampler 原文＋grep | `q1-source.txt` |
| Q2 | 排除條件／EXPLORE 值／五港擋否／開局船數 | `q2-answers.txt` |
| Q3 | L d1800 trader_summary 重算 | `q3-recompute.txt` |
| Q4 | sail_count／ships_in_port 語意 | 本報告下節 |
| Q5 | 答案＋原文；不下判斷 | 上列 |

## S9a D–G

無產品碼／無測試／無信號變更。

## S9a H 偏離與缺口

- Q2(d) 開局船數為碼＋資料靜態重算（largest-remainder＋SHIP_MIX 打包），非模擬執行觀測。
- Q3 來源 product SHA `6d1ad7331166f3a5eb366d7631f3f24bbccaa630`（非本線讀碼 SHA aa098a8）；本線未比對兩 SHA 的 sampler／trader_registry 是否相同（未要求）。
- params.json 無 EXPLORE 預設；實際值僅見情境 overrides。

## S9a I 失敗執行

無。

---

## Q2 摘要（答案；細節見 q2-answers.txt）

- (a) 排除條件見 q2-answers：同港、入港、吃水、無航程、買賣准入、本港庫存、無行市（非探索）、探索無 base_price、週需求<1、可負擔量、q<1、精算報價失敗／現金不足。
- (b) EXPLORE_RATE=0.05、EXPLORE_QTY=50（scenario_M1b_G0.json:267-268／Za_G0_A0）。
- (c) 吃水／入港／商品准入：碼上不會（SH-03 + QUAL_OPEN）。
- (d) 開局船數：寧波 9、松江 10、雞籠 3、淡水 2、那霸 4。

## Q3 摘要

- 五港 20 季 sail_sum：寧波 124、松江 90、雞籠 97、淡水 37、那霸 4。
- zero_seasons：14/16/15/17/19。
- 全圖合計 20241；與已知事實 1 數字對照見 `q3-recompute.txt` MISMATCH 節。

## Q4 sail_count／ships_in_port 語意（依 Q1(d) 原文）

### sail_count

答案：季內自該港出發的出航次數（D-123(c)：`season_sail_count(port_id, season_index)` ← `_season_sails`；於成功 buy+sail 時 `_record_season_sail` +1）。

原文：
```
autoload/trader_registry.gd:82-84
func season_sail_count(port_id: StringName, season_index: int) -> int:
	## D-123(c): sails departed from port_id during season_index.
	return int(_season_sails.get(_season_port_key(season_index, port_id), 0))
```
```
sim/sampler.gd:200-201
		if tre.has_method("season_sail_count"):
			sail = int(tre.call("season_sail_count", StringName(port_s), season_index))
```
```
autoload/trader_registry.gd:947
		_record_season_sail(from_port, good_f, qty_f, int(best["daily_profit_li"]))
```

### ships_in_port

答案：取樣當下（季末 sample）停泊（STATE_DOCKED）於該港的散商船數（非季內平均；`ships_in_port_count` 即時計數）。

原文：
```
autoload/trader_registry.gd:103-120
func ships_in_port_count(port_id: StringName) -> int:
	## Docked trader ships currently at port_id.
	...
			if StringName(info.get("state", &"")) != Ship.STATE_DOCKED:
				continue
			if String(info.get("port_id", "")) == String(port_id):
				n += 1
```
```
sim/sampler.gd:202-203
		if tre.has_method("ships_in_port_count"):
			in_port = int(tre.call("ships_in_port_count", StringName(port_s)))
```

### frozen_traders（Q1(d) 一併）

答案：至少有一艘船「位於」該港（不限 docked）的凍結散商人數。

原文：`frozen_trader_count` autoload/trader_registry.gd:123-142；sampler :204-205。

---

## Orphan (S9d)

- Branch: 
- Full SHA (orphan_sha.txt): 
- URL: https://github.com/wayung0217/Project-Patrician/tree/review/overnight-17-90-Q

## FILES_TOTAL


