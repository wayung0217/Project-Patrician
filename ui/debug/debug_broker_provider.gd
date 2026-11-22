class_name DebugBrokerProvider
extends BrokerProvider
## 僅供除錯介面，正式開機不得使用。
## D-90(f)／WP-61：Debug UI always-allow BrokerProvider（一律放行）.
## 非正式產品 Autoload；正式開機改由 BrokerDesk（WP-41）注入。


func has_kontor(_actor_id: StringName, _port_id: StringName) -> bool:
	_last_error = {}
	return true


func is_broker_qualified(_actor_id: StringName, _port_id: StringName) -> bool:
	_last_error = {}
	return true
