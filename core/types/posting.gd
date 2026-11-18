class_name Posting
extends RefCounted
## ST-CASH Posting / EV-SYS05-POST (03_Systems r563 / TechSpec 3.6 D).
## seq 經 GoodsLedger.next_seq()；posting_id 由 CashLedger 自增（兩者不得混用）。

var posting_id: int = 0
var day: int = 0
var seq: int = 0
var requester: StringName = &""
var reason: StringName = &""
var entries: Array = [] ## Array[PostingEntry]
