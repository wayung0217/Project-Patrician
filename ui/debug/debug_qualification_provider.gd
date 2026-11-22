class_name DebugQualificationProvider
extends QualificationProvider
## 僅供除錯介面，正式開機不得使用。
## D-90(f)／WP-61：Debug UI always-allow QualificationProvider（一律放行）.
## 非正式產品 Autoload；正式開機改由 TierRegistry（WP-35）注入。


func can_enter(_actor_id: StringName, _port_id: StringName) -> bool:
	_last_error = {}
	return true


func can_trade(
	_actor_id: StringName, _port_id: StringName, _good_id: StringName, _side: int
) -> bool:
	_last_error = {}
	return true


func can_build(_actor_id: StringName, _port_id: StringName) -> bool:
	_last_error = {}
	return true
