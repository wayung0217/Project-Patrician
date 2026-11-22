class_name DebugTradeObserver
extends TradeObserver
## 僅供除錯介面，正式開機不得使用。
## D-90(f)／WP-61：Debug UI TradeObserver — 認可成交、不改現金／貨物。
## 非正式產品 Autoload；正式開機改由 ReputationLedger／TaxLedger 注入。


func record_trade(
	_actor_id: StringName,
	_port_id: StringName,
	_good_id: StringName,
	_side: int,
	_qty: int,
	_mid_before: float,
	_mid_after: float,
	_seq: int
) -> int:
	return RECORD_OK
