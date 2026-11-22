class_name FormatTael
extends RefCounted
## 03A_Goods §8／OQ-12w：金額顯示七條（R1–R7）的具名格式化。
## 內部單位＝厘（int）；1 兩＝1000 厘。UI 全域只准經此函數顯示兩額。
## R4／R6／R7 為使用約定（主顯示整批、同表不混單位、玩家不自行換算）— 呼叫端遵守。


const LI_PER_TAEL: int = 1000
const WAN_THRESHOLD_TAEL: float = 10000.0


## R1–R3：把厘整數格式成「…兩」字串（永不複合錢／分）。
static func format_tael(li: int) -> String:
	var sign: String = ""
	var abs_li: int = li
	if li < 0:
		sign = "-"
		abs_li = 0 - li
	var tael: float = float(abs_li) / float(LI_PER_TAEL)
	var body: String = _format_abs_tael(tael)
	return "%s%s兩" % [sign, body]


## R5：單價固定兩位小數（對齊用）；單位仍為兩。
static func format_tael_unit_price(li: int) -> String:
	var sign: String = ""
	var abs_li: int = li
	if li < 0:
		sign = "-"
		abs_li = 0 - li
	var tael: float = float(abs_li) / float(LI_PER_TAEL)
	return "%s%.2f兩" % [sign, tael]


## mid_price 等 float 厘 → 顯示用（先經 AmountQuantize，再 floori 成厘）。
static func format_tael_from_float_li(li_f: float) -> String:
	var q: float = AmountQuantize.quantize_amount(li_f)
	var li_i: int = 0
	if q >= 0.0:
		li_i = floori(q)
	else:
		li_i = 0 - floori(0.0 - q)
		if q != float(li_i):
			# negative non-int after quantize: mirror floor toward −∞
			li_i = floori(q)
	return format_tael(li_i)


static func _format_abs_tael(tael: float) -> String:
	# R3：超過一萬兩改用「萬」
	if tael >= WAN_THRESHOLD_TAEL:
		var wan: float = tael / WAN_THRESHOLD_TAEL
		# keep up to 2 decimals on 萬 scale
		var wan_s: String = _trim_decimals("%.2f" % wan)
		return "%s萬" % wan_s
	# R2：小數位依量級收斂
	if tael >= 1000.0:
		return _with_thousands(int(floori(tael)))
	if tael >= 100.0:
		return str(int(floori(tael)))
	if tael >= 1.0:
		return _trim_decimals("%.1f" % tael)
	# < 1 兩：兩位小數
	return "%.2f" % tael


static func _with_thousands(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count == 3:
			out = "," + out
			count = 0
		out = s[i] + out
		count = count + 1
	return out


static func _trim_decimals(s: String) -> String:
	if not s.contains("."):
		return s
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s
