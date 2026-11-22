class_name ChargeSchedule
extends RefCounted
## ST-CASH ChargeSchedule (03_Systems r564 / TechSpec 3.6 D).
## end_day < 0 表示仍有效（null）；費率由請求系統自帶。

var account_id: StringName = &""
var requester: StringName = &""
var reason: StringName = &""
var fee_per_season: int = 0 ## 厘
var start_day: int = 0
const END_DAY_NONE := -1 ## EX-02: 哨兵＝無結束日（規格 null）
var end_day: int = END_DAY_NONE
