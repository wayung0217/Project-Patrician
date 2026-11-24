# W8 — band 用語與 BAND-1 摘要（補正三）

## 用語（正式）

| Band | 中文 | 含義 |
|------|------|------|
| **band0** | **價格天花板** | 缺貨：`w < 1`（庫存週數過低 → 高價端） |
| **band4** | **價格地板** | 過剩：`w ≥ 10`（庫存週數過高 → 低價端） |
| mid | band ∈ {1,2,3} | 中間帶 |

## BAND-1 摘要更正

Source counts: lane1 `band1_y5_counts`（z-1758-2 Y5，`season_index==19`，448 cells／group）.

Example Za_G0_A0: band0=42, mid=15, **band4=391** → band4／448 = **87.3%**.

| 舊（誤） | 新（正） |
|----------|----------|
| 天花板為主 | **地板為主（87.3%）** |

Rationale: dominant Y5 mass is **band4**（過剩／價格地板）, not band0（缺貨／天花板）. band0+4% ≈96.7% still fails ≤30% M1b gate; composition is floor-heavy.

Lane1 owns refreshing `band1_y5_counts.*` wording on its orphan if present; this file is L4 W8 report evidence.
