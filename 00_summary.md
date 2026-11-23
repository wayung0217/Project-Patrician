# evening-17-55 — M1b overnight (D-115) pack summary

`git branch -r` (relevant @ pack close HKT 2026-11-24 ~00:22): `origin/main`, `origin/cursor/step0-m1b-params-data-0638`, `origin/cursor/laneC-queue-outputs-a116`, `origin/cursor/laneD-city-housing-a116`, `origin/cursor/lane-b-pop-demand-003b`, `origin/cursor/lane-a-wp36-traders-26f5`, `origin/cursor/int-1755-merge-0a6e`, `origin/cursor/wp69-test-hygiene-f3ea`, `origin/cursor/ui-1755-debug-panels-ff98`, plus prior `origin/review/evening-17-{51,53,54,56,57}`.

| Branch | Full SHA |
|--------|----------|
| `origin/main` (post 0-A #60+#64) | `ade2dc8ca9b04faad03eedea26eb6754ac0607ab` |
| `origin/cursor/step0-m1b-params-data-0638` | `ef70d4214274d90cc6bb1150eb3d64c14e898523` |
| `origin/cursor/laneC-queue-outputs-a116` | `7101e9c546392aa51390182476606b42c21737c9` |
| `origin/cursor/laneD-city-housing-a116` | `8603d8ca6a57eb799a03a51dc65f911fd3bfa9f3` |
| `origin/cursor/lane-b-pop-demand-003b` | `6b38ae03c1c816dafc17166a1a28dca06c6eb433` |
| `origin/cursor/lane-a-wp36-traders-26f5` | `14b22ee629a7385319ebf30be0abb77db87509ce` |
| `origin/cursor/int-1755-merge-0a6e` | `c13249e65181bb0bb38a6005a4aed9b84abaa7a2` |
| `origin/cursor/wp69-test-hygiene-f3ea` | `fbdaa8126154f566d915fa462e7d507f67ce54ca` |
| `origin/cursor/ui-1755-debug-panels-ff98` | `1fd181acf5012a49494b3084e4045202987e4507` |

## Status table (D-115)

| Item | Status | Reason |
|------|--------|--------|
| step0 | 完成 | B9=`v6.99.170`; rows 28/82/16/353/116/37; #60+#64 on main; tip `ef70d42…` draft [#71](https://github.com/wayung0217/Project-Patrician/pull/71); boot stock 136088 / cons 0 |
| lane A | 完成 | WP-36 tip `14b22ee…` draft [#72](https://github.com/wayung0217/Project-Patrician/pull/72); GUT traders 21/21; C-05 gaps (sim_engine layers) |
| lane B | 完成 | tip `6b38ae0…` draft [#73](https://github.com/wayung0217/Project-Patrician/pull/73) |
| lane C | 完成 | tip `7101e9c…` draft [#74](https://github.com/wayung0217/Project-Patrician/pull/74) |
| lane D | 完成 | tip `8603d8c…` draft [#75](https://github.com/wayung0217/Project-Patrician/pull/75); G0H scenario |
| lane E | 完成 | tip `fbdaa81…` draft [#77](https://github.com/wayung0217/Project-Patrician/pull/77); **not** merged into int-1755 (arrived after int; D-115); artifacts `laneE/` |
| int-1755 | 完成 | tip `c13249e…` draft [#76](https://github.com/wayung0217/Project-Patrician/pull/76); merges C→D→B→A clean; E skipped at int time |
| Z | 完成 | 6×5y + G0 traders-off; SCRIPT ERROR 0; class/3bars **FAIL** (pop~60% open; band0\|4~97%); traders unwired (G-INT-01) |
| Z2 | 完成 | G0H≡G0 `season_ports` (no housing effect measured) |
| Z3 | 完成 | seeds 2/3 class/3bars FAIL same pattern as seed1 |
| Z4 | 完成 | H0≡H1 10y `season_ports` |
| U | 完成（部分） | tip `1fd181a…` draft [#78](https://github.com/wayung0217/Project-Patrician/pull/78); traders + open zones + built-ratio OK; **city auto-housing count C-05 gap** (no public query); not merged to int/main |
| Windows exe | 完成 | cross-export Godot 4.7.2 from **ui-1755** tip `1fd181a…` (D-115(d)(e)); `windows/ProjectPatrician-win.zip`; 3-line note `windows/這次能玩到什麼.txt` |

**Do not merge** any product PR (#71–#78) to main.

## Orphan / zip

- Orphan branch: `review/evening-17-55` (no PR) — tip recorded in pack `orphan_sha.txt` (branch HEAD)
- Zip: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/evening-17-55.zip`
- Pack size gate: zip &lt; 150 MB (Z3/Z4 full outputs retained)

---

## S9a A — 基線

- Spec B9: `v6.99.170` (step0 `00_version_gate.txt`)
- Main after 0-A: `ade2dc8ca9b04faad03eedea26eb6754ac0607ab`
- `step0_head`: `ef70d4214274d90cc6bb1150eb3d64c14e898523`
- Int tip (Z): `c13249e65181bb0bb38a6005a4aed9b84abaa7a2`
- Lane E tip (not in int): `fbdaa8126154f566d915fa462e7d507f67ce54ca`
- UI tip (Windows): `1fd181acf5012a49494b3084e4045202987e4507`
- Int final GUT **576/576** after A

## S9a B — 變更清單（包層）

產品碼落在各 lane/int/ui PR（未合 main）：traders、population/demand、building_economy queue/housing、season outputs、step0 PRMs/scenarios/D-107、`ui/debug_main.gd`（U）。Lane E **僅** `tests/`。詳見各 `diff.patch`。

## S9a C — 規格對照

| 裁決／FRM | 實作 | 測試／證據 |
|-----------|------|------------|
| D-114(a)(b) 0-A | #60+#64 merge; upgrade spend once | step0/0A |
| D-107 reimport | csv batches; EX 1051/499 | step0/0-3 |
| WP-36 / 17.1 | Lane A | `test_trader_registry_wp36` |
| FRM-SYS07-16/17, FRM-SYS08-25 | Lane B | laneB GUT |
| D-110(b)(d)(i) | Lane C | laneC |
| FRM-SYS08-24 / WP-68 | Lane D | `test_wp68_city_housing` |
| D-114(d) WP-69 | Lane E | #77 |
| D-115(e) UI panels | Step U `ui/debug_main.gd` | gut_ui 6/6; housing count C-05 |
| D-115 Z–Z4 | step_Z* | reports |

缺口：`step_int/gaps.md`（G-INT-01/03）；`step_U/gaps.md`（auto-housing count）。

## S9a D — 介面

新增 Autoload `TraderRegistry`; SimLoop hooks; BuildingEconomy queue/housing queries; scenario layers; U 僅呼叫公開 API 顯示商人／區資料。Lane E 無產品介面變更。

## S9a E — 自查

各 lane／U `report.md`。已知 G-INT-01；U housing count 停於 C-05。

## S9a F — 測試

- step0 CI green on `ef70d42…`
- int after A: 576/576, SCRIPT ERROR 0
- Lane E: names 531≡531; GUT 525×2 + UI 6/6
- U: `tests/ui` 6/6

## S9a G — 排程與信號

Lane A 改 SimLoop。U 不改排程。E 不改產品。

## S9a H — 偏離與缺口

1. G-INT-01 TRADERS wiring → Z traders 無實效。
2. G-INT-03 ABUND override∩grid → Z 用 user:// 副本。
3. Lane E 完成但未合 int（D-115 晚到）。
4. Z/Z2–Z4 class/3bars FAIL；CITY_HOUSING 開關輸出相同。
5. U：城市自建住宅**計數** C-05（無公開查詢）；其餘面板完成。
6. Windows：raw exe ~105MB → zip 交付（store/GitHub 100MB 單檔上限）。

## S9a I — 特別證據

- step0 / int merges / Z* reports
- laneE #77；step_U #78 + gaps.md
- windows export.log / md5 / 這次能玩到什麼.txt（source=ui-1755）

## PRs（draft only）

| PR | Head |
|----|------|
| [#71](https://github.com/wayung0217/Project-Patrician/pull/71) step0 | `ef70d42…` |
| [#72](https://github.com/wayung0217/Project-Patrician/pull/72) A | `14b22ee…` |
| [#73](https://github.com/wayung0217/Project-Patrician/pull/73) B | `6b38ae0…` |
| [#74](https://github.com/wayung0217/Project-Patrician/pull/74) C | `7101e9c…` |
| [#75](https://github.com/wayung0217/Project-Patrician/pull/75) D | `8603d8c…` |
| [#76](https://github.com/wayung0217/Project-Patrician/pull/76) int | `c13249e…` |
| [#77](https://github.com/wayung0217/Project-Patrician/pull/77) E | `fbdaa81…` |
| [#78](https://github.com/wayung0217/Project-Patrician/pull/78) U | `1fd181a…` |
