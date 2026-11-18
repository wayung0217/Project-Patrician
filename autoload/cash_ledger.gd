extends Node
## Autoload: CashLedger — SYS-05 ST-CASH (TechSpec 3.6 / WP-07).
## _ready() only clears fields; load_and_validate() inits SOURCE／SINK (2.2-01).
## TradeSlider／帳本報表 UI 不做（1-A8）。
## D-04／R2-05: post() -> Error：成功 OK、失敗 FAILED；原因只經 last_error()（03_Systems r589／TechSpec D290）.
## D-03: genesis_grant() API only（SimLoop.boot 呼叫屬 WP-08）.
## D-01／N-04: money float→int only via AmountQuantize.quantize_amount then ceili／floori（from WP-06）.

signal cash_changed(id: StringName, new_balance: int, delta: int, reason: StringName)
signal arrears_changed(id: StringName, arrears: int, seasons: int)
signal bankruptcy_referred(id: StringName)
signal season_ledger_closed(season_index: int, report: SeasonLedgerReport)

const SYS_ID := &"SYS-05"
const SCRIPT_PATH := "res://autoload/cash_ledger.gd"

const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_START_CASH := "PRM-SYS05-START_CASH"
const PRM_ARREARS_SEASONS_TO_BANKRUPT := "PRM-SYS05-ARREARS_SEASONS_TO_BANKRUPT"
const PRM_MIN_CASH_UNIT := "PRM-SYS05-MIN_CASH_UNIT"

## post()／create_account／revalidate／genesis use Godot Error OK／FAILED (r589／D290／R2-05).
## paid／qty returns stay domain ints; ->int fail surfaces as 0 only where applicable (D-04).

const ERR_SYS05_01 := &"ERR-SYS05-01"
const ERR_SYS05_02 := &"ERR-SYS05-02"
const ERR_SYS05_03 := &"ERR-SYS05-03"
const ERR_SYS05_04 := &"ERR-SYS05-04"
const ERR_SYS05_05 := &"ERR-SYS05-05"
const ERR_SYS05_06 := &"ERR-SYS05-06"
const ERR_SYS05_07 := &"ERR-SYS05-07"
const ERR_SYS05_08 := &"ERR-SYS05-08"
const ERR_SYS05_09 := &"ERR-SYS05-09"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_MISSING_KEY := &"MISSING_KEY"
const CODE_MIN_CASH_UNIT := &"MIN_CASH_UNIT"

## 帳戶 id 具名常數（TechSpec 3.6）；組 id 一律經常數，不得手打字串判斷種類。
const PREFIX_ACT := "ACT-"
const PREFIX_CITY := "CITY-"
const PREFIX_REG := "REG-"
const ID_SOURCE := &"SOURCE"
const ID_SINK := &"SINK"
## D-03: player actor account; kind = ACTOR. AI ACT-AI-nn is SYS-18（Phase 0 不建）.
const ACCOUNT_PLAYER := &"ACT-PLAYER"

## ERR-SYS05-06 授權請求者清單（來源：03_Systems ST-CASH r73／TechSpec G ERR-SYS05-06）。
## D-03: list itself unchanged — genesis exception is a separate named constant below.
const AUTHORIZED_REQUESTERS: Array[StringName] = [
	&"SYS-04",
	&"SYS-08",
	&"SYS-09",
	&"SYS-10",
	&"SYS-12",
	&"SYS-13",
	&"SYS-16",
	&"SYS-21",
]

## D-03: sole ERR-SYS05-06 exception for genesis_grant()（裁決 D-03）；不寫入 AUTHORIZED_REQUESTERS。
const REQUESTER_GENESIS_GRANT := &"GENESIS_GRANT"
const REASON_GENESIS_CASH := &"GENESIS_CASH"

## quote side（TechSpec 3.5 H：BUY=0, SELL=1）
const SIDE_BUY := 0
const SIDE_SELL := 1

## quantize_money mode literals 0／1 only (D-04／C-03); ceili／floori after AmountQuantize.
const MODE_CEIL := 0
const MODE_FLOOR := 1

const FIELD_PARAMS := "Params"
const FIELD_ENTRIES := "entries"
const FIELD_AMOUNT := "amount"
const FIELD_REQUESTER := "requester"
const FIELD_ACCOUNT := "account_id"
const FIELD_WEIGHTS := "weights"
const KEY_TOTAL_LI := "total_li"

## Day／season 占位：本堆疊無 Clock（WP-02）— 見 PR 缺口。
const DAY_PLACEHOLDER := 1

var _accounts: Dictionary = {} ## String → Account
var _postings: Array = [] ## Array[Posting] 本季明細
var _charges: Array = [] ## Array[ChargeSchedule] 登記序
var _next_posting_id: int = 1
var _day: int = DAY_PLACEHOLDER
var _season_index: int = 0
var _season_start_day: int = DAY_PLACEHOLDER
## account_id → 本季彙總列（SeasonLedgerReport KEY_*）
var _season_stats: Dictionary = {}
var _loaded: bool = false
## 缺口：應呼叫 MarketPricer.quote；WP-06 平行未登錄。暫用 set_quote_provider。
var _quote_provider: Object = null
## D-04: last single-call ErrorInfo {code,sys,detail}; empty Dictionary when none.
var _last_error: Dictionary = {}


func _ready() -> void:
	_clear_state()


func load_and_validate() -> Array:
	# 2.2-01／2.2-02: field init + Params gate；開局 SOURCE／SINK。
	var errors: Array = []
	_clear_state()
	if not Params.is_loaded():
		errors.append(_err(CODE_PARAMS_NOT_LOADED, FIELD_PARAMS, null, "Params must load_and_validate before CashLedger"))
		_emit_errors(errors)
		return errors
	# 1-A8: START_CASH／ARREARS_SEASONS_TO_BANKRUPT 缺鍵由 Params 拒絕；此處再確認可讀。
	if not Params.has_prm(PRM_START_CASH):
		errors.append(_err(CODE_MISSING_KEY, PRM_START_CASH, null, "PRM-SYS05-START_CASH required (1-A8)"))
	if not Params.has_prm(PRM_ARREARS_SEASONS_TO_BANKRUPT):
		errors.append(_err(CODE_MISSING_KEY, PRM_ARREARS_SEASONS_TO_BANKRUPT, null, "PRM-SYS05-ARREARS_SEASONS_TO_BANKRUPT required (1-A8)"))
	if not errors.is_empty():
		_emit_errors(errors)
		return errors
	# 讀取以確認型別可用；正式值 [待審] 不得寫入 params.json（測試用 fixtures）。
	var _start: int = Params.get_int(PRM_START_CASH)
	var _arrears_lim: int = Params.get_int(PRM_ARREARS_SEASONS_TO_BANKRUPT)
	var _min_unit: int = Params.get_int(PRM_MIN_CASH_UNIT)
	if _min_unit != 1:
		errors.append(_err(CODE_MIN_CASH_UNIT, PRM_MIN_CASH_UNIT, _min_unit, "MIN_CASH_UNIT must be 1"))
		_emit_errors(errors)
		return errors
	_ensure_system_account(ID_SOURCE, Account.Kind.SOURCE)
	_ensure_system_account(ID_SINK, Account.Kind.SINK)
	_next_posting_id = 1
	_day = DAY_PLACEHOLDER
	_season_index = 0
	_season_start_day = DAY_PLACEHOLDER
	_loaded = true
	# D-03: START_CASH 發放經 genesis_grant()；SimLoop.boot 呼叫屬 WP-08，此處不自動發放。
	return errors


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	# D-04: single-call failures (post／revalidate／create_account／genesis_grant／charge) expose ErrorInfo here.
	return _last_error.duplicate(true)


func set_day(day: int) -> void:
	## 缺口：應由 Clock.day 驅動；無 Clock 時測試／呼叫端可 set_day。
	_day = day


func set_quote_provider(provider: Object) -> void:
	## 缺口：TechSpec 寫呼叫 MarketPricer.quote()；WP-06 平行未登錄。
	_quote_provider = provider


func create_account(id: StringName, kind: Account.Kind, owner_id: StringName = &"") -> Error:
	## 缺口：H 未列建戶 API；測試／開局需要。SOURCE／SINK 已於 load 建立。
	## D-04／R2-05: OK／FAILED + last_error.
	assert(_loaded, "CashLedger.create_account before load")
	_clear_last_error()
	var key := String(id)
	if _accounts.has(key):
		return OK
	if kind == Account.Kind.SOURCE or kind == Account.Kind.SINK:
		return _fail(ERR_SYS05_04, FIELD_ACCOUNT, id, "system accounts are singleton")
	var acc := Account.new()
	acc.id = id
	acc.kind = kind
	acc.owner_id = owner_id
	acc.balance = 0
	acc.arrears = 0
	acc.arrears_seasons = 0
	_accounts[key] = acc
	_init_season_stats(key)
	return OK


func make_actor_id(owner_token: String) -> StringName:
	# 組 id 經常數前綴（TechSpec 3.6）
	return StringName(PREFIX_ACT + owner_token)


func make_city_id(owner_token: String) -> StringName:
	return StringName(PREFIX_CITY + owner_token)


func make_regime_id(owner_token: String) -> StringName:
	return StringName(PREFIX_REG + owner_token)


func register_charge(schedule: ChargeSchedule) -> void:
	## 缺口：H 未列登記 API；季末 FRM-SYS05-05 需要 ChargeSchedule。
	assert(_loaded, "CashLedger.register_charge before load")
	_charges.append(schedule)


func genesis_grant() -> Error:
	# D-03: {SOURCE: −START_CASH, ACT-PLAYER: +START_CASH}, reason GENESIS_CASH.
	# Sole ERR-SYS05-06 exception via REQUESTER_GENESIS_GRANT. SimLoop.boot calls once（WP-08）.
	assert(_loaded, "CashLedger.genesis_grant before load")
	_clear_last_error()
	var start_cash: int = Params.get_int(PRM_START_CASH)
	if not _accounts.has(String(ACCOUNT_PLAYER)):
		var created: Error = create_account(ACCOUNT_PLAYER, Account.Kind.ACTOR)
		if created != OK:
			return created
	return post([
		make_entry(ID_SOURCE, 0 - start_cash),
		make_entry(ACCOUNT_PLAYER, start_cash),
	], REASON_GENESIS_CASH, REQUESTER_GENESIS_GRANT)


func post(entries: Array, reason: StringName, requester: StringName) -> Error:
	# FRM-SYS05-01／02；授權 ERR-SYS05-06；金額 ERR-SYS05-05
	# 03_Systems r589／TechSpec D290（R2-05）：成功 OK、失敗 FAILED；原因只經 last_error().
	assert(_loaded, "CashLedger.post before load")
	_clear_last_error()

	# 1 驗證請求者（D-03 genesis exception）
	if not _is_authorized(requester):
		return _fail(ERR_SYS05_06, FIELD_REQUESTER, requester, "unauthorized requester")

	if entries.is_empty():
		return _fail(ERR_SYS05_02, FIELD_ENTRIES, entries, "empty posting")

	var parsed: Array = [] ## Array[PostingEntry]
	var sum_amount: int = 0
	for item in entries:
		var pe: PostingEntry = _coerce_entry(item)
		if pe == null:
			return _fail(ERR_SYS05_05, FIELD_AMOUNT, item, "invalid entry")
		# ERR-SYS05-05：金額須為非整 0 的整數（正入／負出）；≤0 且非負入帳之出帳已含於 amount==0
		if pe.amount == 0:
			return _fail(ERR_SYS05_05, FIELD_AMOUNT, pe.amount, "amount must be non-zero int")
		var acc_key := String(pe.account_id)
		if not _accounts.has(acc_key):
			return _fail(ERR_SYS05_04, FIELD_ACCOUNT, pe.account_id, "unknown account")
		if not _add_checked(sum_amount, pe.amount):
			return _fail(ERR_SYS05_08, FIELD_AMOUNT, pe.amount, "int64 overflow on sum")
		sum_amount = sum_amount + pe.amount
		parsed.append(pe)

	# FRM-SYS05-01
	if sum_amount != 0:
		return _fail(ERR_SYS05_02, FIELD_ENTRIES, sum_amount, "unbalanced posting")

	# Snapshot for rollback
	var snap_balances: Dictionary = {}
	var snap_arrears: Dictionary = {}
	for pe2 in parsed:
		var k2 := String(pe2.account_id)
		var acc2: Account = _accounts[k2]
		snap_balances[k2] = acc2.balance
		snap_arrears[k2] = acc2.arrears

	# 預檢自願支出非負（FRM-SYS05-02）；欠款抵償入帳在 apply 時處理
	for pe3 in parsed:
		var acc3: Account = _accounts[String(pe3.account_id)]
		if pe3.amount < 0 and acc3.kind != Account.Kind.SOURCE:
			var projected: int = acc3.balance + pe3.amount
			if projected < 0:
				return _fail(ERR_SYS05_01, FIELD_AMOUNT, pe3.amount, "insufficient cash")

	# Apply entries；正入帳走 FRM-SYS05-07
	var deltas: Array = [] ## {id, delta, reason} for signals after commit
	var arrears_signals: Array = []
	for pe4 in parsed:
		var acc4: Account = _accounts[String(pe4.account_id)]
		if pe4.amount > 0:
			var applied: Dictionary = apply_inbound_credit(acc4, pe4.amount)
			if bool(applied.get("overflow", false)):
				_restore_snap(snap_balances, snap_arrears)
				return _fail(ERR_SYS05_08, FIELD_AMOUNT, pe4.amount, "overflow on credit")
			deltas.append({"id": acc4.id, "delta": int(applied["balance_delta"]), "reason": reason})
			if int(applied["arrears_offset"]) > 0:
				var sink: Account = _accounts[String(ID_SINK)]
				if not _add_checked(sink.balance, int(applied["arrears_offset"])):
					_restore_snap(snap_balances, snap_arrears)
					return _fail(ERR_SYS05_08, FIELD_AMOUNT, applied["arrears_offset"], "overflow on SINK")
				sink.balance = sink.balance + int(applied["arrears_offset"])
				deltas.append({"id": ID_SINK, "delta": int(applied["arrears_offset"]), "reason": reason})
				_bump_season_stat(String(ID_SINK), SeasonLedgerReport.KEY_SUM_CREDIT, int(applied["arrears_offset"]))
				arrears_signals.append(acc4.id)
			if int(applied["balance_delta"]) > 0:
				_bump_season_stat(String(acc4.id), SeasonLedgerReport.KEY_SUM_CREDIT, int(applied["balance_delta"]))
			# 入帳抵欠：對抵金額視作出帳至 SINK（統計）
			if int(applied["arrears_offset"]) > 0:
				_bump_season_stat(String(acc4.id), SeasonLedgerReport.KEY_SUM_DEBIT, int(applied["arrears_offset"]))
		else:
			# 出帳
			if not _add_checked(acc4.balance, pe4.amount):
				_restore_snap(snap_balances, snap_arrears)
				return _fail(ERR_SYS05_08, FIELD_AMOUNT, pe4.amount, "overflow on debit")
			var new_bal: int = acc4.balance + pe4.amount
			if acc4.kind != Account.Kind.SOURCE and new_bal < 0:
				# ERR-SYS05-03 保底
				_restore_snap(snap_balances, snap_arrears)
				return _fail(ERR_SYS05_03, FIELD_AMOUNT, pe4.amount, "negative balance")
			acc4.balance = new_bal
			deltas.append({"id": acc4.id, "delta": pe4.amount, "reason": reason})
			_bump_season_stat(String(acc4.id), SeasonLedgerReport.KEY_SUM_DEBIT, 0 - pe4.amount)

	# Commit posting record
	var posting := Posting.new()
	posting.posting_id = _next_posting_id
	_next_posting_id = _next_posting_id + 1
	posting.day = _day
	# seq 與貨物事件共用 GoodsLedger 序列（TechSpec D148）
	if GoodsLedger.is_loaded():
		posting.seq = GoodsLedger.next_seq()
	else:
		# 缺口：GoodsLedger 未載入時無法取 seq；測試應先載入。
		posting.seq = posting.posting_id
	posting.requester = requester
	posting.reason = reason
	posting.entries = parsed
	_postings.append(posting)

	for d in deltas:
		var did: StringName = d["id"]
		var acc_d: Account = _accounts[String(did)]
		cash_changed.emit(did, acc_d.balance, int(d["delta"]), reason)
	for aid in arrears_signals:
		var acc_a: Account = _accounts[String(aid)]
		arrears_changed.emit(acc_a.id, acc_a.arrears, acc_a.arrears_seasons)
	return OK


func balance(id: StringName) -> int:
	assert(_loaded, "CashLedger.balance before load")
	var key := String(id)
	assert(_accounts.has(key), "unknown account %s" % key)
	return (_accounts[key] as Account).balance


func arrears(id: StringName) -> int:
	assert(_loaded, "CashLedger.arrears before load")
	var key := String(id)
	assert(_accounts.has(key), "unknown account %s" % key)
	return (_accounts[key] as Account).arrears


func arrears_seasons(id: StringName) -> int:
	assert(_loaded, "CashLedger.arrears_seasons before load")
	var key := String(id)
	assert(_accounts.has(key), "unknown account %s" % key)
	return (_accounts[key] as Account).arrears_seasons


func can_afford(id: StringName, amount: int) -> bool:
	assert(_loaded, "CashLedger.can_afford before load")
	if amount <= 0:
		return false
	return balance(id) >= amount


func make_entry(account_id: StringName, amount: int) -> PostingEntry:
	var pe := PostingEntry.new()
	pe.account_id = account_id
	pe.amount = amount
	return pe


func apply_inbound_credit(account: Account, credit: int) -> Dictionary:
	# FRM-SYS05-07：欠款優先抵償 — 獨立單一函數（D153）
	# 有 arrears 時，入帳先轉 SINK 抵欠，餘額才入 balance。
	var result := {
		"balance_delta": 0,
		"arrears_offset": 0,
		"overflow": false,
	}
	if credit <= 0:
		return result
	var offset: int = credit
	if account.arrears < offset:
		offset = account.arrears
	if offset > 0:
		account.arrears = account.arrears - offset
		result["arrears_offset"] = offset
	var to_balance: int = credit - offset
	if to_balance > 0:
		if not _add_checked(account.balance, to_balance):
			result["overflow"] = true
			return result
		account.balance = account.balance + to_balance
		result["balance_delta"] = to_balance
	return result


func revalidate_submit(account_balance: int, new_total_b_prime: int) -> Error:
	# FRM-SYS05-11：提交重驗 — 獨立單一函數（D157）
	# B′ ≤ balance → OK；否則 ERR-SYS05-07，不自動減量。
	# D-04／R2-05: OK／FAILED + last_error.
	_clear_last_error()
	if new_total_b_prime <= 0:
		return _fail(ERR_SYS05_05, FIELD_AMOUNT, new_total_b_prime, "B' must be > 0")
	if new_total_b_prime <= account_balance:
		return OK
	return _fail(ERR_SYS05_07, FIELD_AMOUNT, new_total_b_prime, "stale quote unaffordable")


func split_largest_remainder(total: int, weights: Array) -> Array:
	# FRM-SYS05-12：最大餘數分攤 — 獨立單一函數（D158）
	# base_i = FLOOR(T·w_i ÷ W)；r = T − Σbase；依 MOD(T·w_i, W) 大到小、同值索引小者先，前 r 名 +1
	var out: Array = []
	if total < 0:
		_record_error(ERR_SYS05_09, FIELD_WEIGHTS, total, "total negative")
		return out
	if weights.is_empty():
		_record_error(ERR_SYS05_09, FIELD_WEIGHTS, weights, "empty weights")
		return out
	var w_sum: int = 0
	var w_ints: Array = []
	for w_variant in weights:
		if typeof(w_variant) != TYPE_INT and typeof(w_variant) != TYPE_FLOAT:
			_record_error(ERR_SYS05_09, FIELD_WEIGHTS, w_variant, "non-numeric weight")
			return []
		if typeof(w_variant) == TYPE_FLOAT and float(w_variant) != floorf(float(w_variant)):
			_record_error(ERR_SYS05_09, FIELD_WEIGHTS, w_variant, "non-int weight")
			return []
		var wi: int = int(w_variant)
		if wi < 0:
			_record_error(ERR_SYS05_09, FIELD_WEIGHTS, wi, "negative weight")
			return []
		w_ints.append(wi)
		w_sum = w_sum + wi
	if w_sum == 0:
		_record_error(ERR_SYS05_09, FIELD_WEIGHTS, w_sum, "weight sum 0")
		return []

	var bases: Array = []
	var mods: Array = [] ## {mod, index}
	var base_sum: int = 0
	for i in range(w_ints.size()):
		var wi2: int = int(w_ints[i])
		var product: int = total * wi2
		var base_i: int = floori(product / w_sum)
		bases.append(base_i)
		base_sum = base_sum + base_i
		var mod_i: int = product % w_sum
		mods.append({"mod": mod_i, "index": i})
	var remainder: int = total - base_sum
	mods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["mod"]) == int(b["mod"]):
			return int(a["index"]) < int(b["index"])
		return int(a["mod"]) > int(b["mod"])
	)
	for j in range(remainder):
		var idx: int = int(mods[j]["index"])
		bases[idx] = int(bases[idx]) + 1
	return bases


func prorate(fee: int, days_held: int) -> int:
	# FRM-SYS05-05：CEIL(fee × days_held ÷ D)；D = PRM-SYS00-DAYS_PER_SEASON
	assert(_loaded, "CashLedger.prorate before load")
	if fee < 0 or days_held < 0:
		_record_error(ERR_SYS05_05, FIELD_AMOUNT, {"fee": fee, "days_held": days_held}, "prorate negative input")
		return 0
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	assert(days_d > 0, "DAYS_PER_SEASON must be > 0")
	if days_held == 0 or fee == 0:
		return 0
	# 整數 CEIL(fee * days_held / D) = (fee * days_held + D - 1) / D
	var numer: int = fee * days_held + days_d - 1
	return floori(numer / days_d)


func charge_mandatory(id: StringName, due: int, reason: StringName, requester: StringName) -> int:
	# FRM-SYS05-06：paid = MIN(balance, due)；arrears += due − paid；balance 最低到 0
	assert(_loaded, "CashLedger.charge_mandatory before load")
	_clear_last_error()
	if not _is_authorized(requester):
		_fail(ERR_SYS05_06, FIELD_REQUESTER, requester, "unauthorized")
		return 0
	if due <= 0:
		_fail(ERR_SYS05_05, FIELD_AMOUNT, due, "due must be > 0")
		return 0
	var key := String(id)
	if not _accounts.has(key):
		_fail(ERR_SYS05_04, FIELD_ACCOUNT, id, "unknown account")
		return 0
	var acc: Account = _accounts[key]
	var paid: int = due
	if acc.balance < paid:
		paid = acc.balance
	var unpaid: int = due - paid
	if paid > 0:
		# 分錄：帳戶 −paid，SINK +paid
		var err: Error = post([
			make_entry(id, 0 - paid),
			make_entry(ID_SINK, paid),
		], reason, requester)
		if err != OK:
			return 0
	if unpaid > 0:
		acc.arrears = acc.arrears + unpaid
		_bump_season_stat(key, SeasonLedgerReport.KEY_ARREARS_NEW, unpaid)
		arrears_changed.emit(acc.id, acc.arrears, acc.arrears_seasons)
	_bump_season_stat(key, SeasonLedgerReport.KEY_CHARGES, due)
	return paid


func max_affordable_qty(actor: StringName, port: StringName, good: StringName) -> int:
	# FRM-SYS05-09：最大 q 使 buy_total(q) ≤ balance；二分搜尋＋整數 quote 校正
	assert(_loaded, "CashLedger.max_affordable_qty before load")
	var bal: int = balance(actor)
	if bal <= 0:
		return 0
	if _quote_provider == null:
		_record_error(ERR_SYS05_04, "quote_provider", null, "quote provider missing (MarketPricer WP-06 gap)")
		return 0
	# 擴張上界：hi 倍增直到 total > bal 或 quote 失敗
	var lo: int = 0
	var hi: int = 1
	while true:
		var t_hi: int = _quote_buy_total(port, good, hi)
		if t_hi < 0:
			return 0
		if t_hi > bal:
			break
		lo = hi
		# hi = hi * 2 without literal 2
		var next_hi: int = hi + hi
		if next_hi <= hi:
			# overflow / cap
			break
		hi = next_hi
	# 二分
	while lo + 1 < hi:
		var mid: int = floori((lo + hi) / (1 + 1))
		var t_mid: int = _quote_buy_total(port, good, mid)
		if t_mid < 0:
			return 0
		if t_mid <= bal:
			lo = mid
		else:
			hi = mid
	# 整數 quote 校正：確認 lo 可負擔、lo+1 不可
	if lo > 0:
		var t_lo: int = _quote_buy_total(port, good, lo)
		if t_lo > bal:
			lo = lo - 1
	return lo


func buy_slider_max(q_afford: int, hold_free: int, stock: int) -> int:
	# FRM-SYS05-10：買 = MIN(q_afford, hold_free, stock)
	var m: int = q_afford
	if hold_free < m:
		m = hold_free
	if stock < m:
		m = stock
	if m < 0:
		return 0
	return m


func sell_slider_max(cargo_held: int) -> int:
	# FRM-SYS05-10：賣 = cargo_held（不受現金限制）
	if cargo_held < 0:
		return 0
	return cargo_held


func close_season() -> SeasonLedgerReport:
	# F 季末：1 帳戶升序 → 2 ChargeSchedule 登記序 FRM-05 → 3 FRM-06 → 4 FRM-08 → 5 報表 → 6 清明細
	assert(_loaded, "CashLedger.close_season before load")
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var bankrupt_lim: int = Params.get_int(PRM_ARREARS_SEASONS_TO_BANKRUPT)
	var season_end_exclusive: int = _season_start_day + days_d

	var ids: Array = _accounts.keys()
	ids.sort()
	for id_variant in ids:
		var acc_id: String = String(id_variant)
		var acc: Account = _accounts[acc_id]
		if acc.kind == Account.Kind.SOURCE or acc.kind == Account.Kind.SINK:
			continue
		# 2 依 ChargeSchedule 登記序
		for sched_variant in _charges:
			var sched: ChargeSchedule = sched_variant
			if String(sched.account_id) != acc_id:
				continue
			var days_held: int = _days_held_in_season(sched, _season_start_day, season_end_exclusive)
			if days_held <= 0:
				continue
			var due: int = prorate(sched.fee_per_season, days_held)
			if due <= 0:
				continue
			# 3 FRM-SYS05-06 扣費入 SINK
			charge_mandatory(sched.account_id, due, sched.reason, sched.requester)
		# 4 FRM-SYS05-08
		if acc.arrears > 0:
			acc.arrears_seasons = acc.arrears_seasons + 1
		else:
			acc.arrears_seasons = 0
		arrears_changed.emit(acc.id, acc.arrears, acc.arrears_seasons)
		if acc.arrears_seasons >= bankrupt_lim:
			bankruptcy_referred.emit(acc.id)

	# 5 SeasonLedgerReport
	var report := SeasonLedgerReport.new()
	report.season_index = _season_index
	for id_variant2 in ids:
		var k: String = String(id_variant2)
		var acc_r: Account = _accounts[k]
		var stats: Dictionary = _season_stats.get(k, _empty_stats())
		stats[SeasonLedgerReport.KEY_CLOSING] = acc_r.balance
		report.accounts[k] = stats.duplicate()

	# 6 清除上季 Posting 明細
	_postings.clear()
	_season_index = _season_index + 1
	_season_start_day = season_end_exclusive
	_reset_season_stats_opening()
	# D-05(c): emit closed season_index（首季 0）；report already holds pre-bump index.
	season_ledger_closed.emit(report.season_index, report)
	return report


func sum_all_balances() -> int:
	## 守恆觀察：Σ 全帳戶 balance（示範 5.1 / FRM-SYS05-01）
	assert(_loaded, "CashLedger.sum_all_balances before load")
	var keys: Array = _accounts.keys()
	keys.sort()
	var s: int = 0
	for k in keys:
		s = s + (_accounts[k] as Account).balance
	return s


func market_net_recovery_delta(sink_delta: int, source_issued_delta: int) -> int:
	# FRM-SYS05-04：ΔSINK − Δ|SOURCE| 發出
	return sink_delta - source_issued_delta


func quantize_money(x: float, mode: int) -> int:
	# D-01／N-04: sole snap = AmountQuantize.quantize_amount；then ceili／floori (C-09).
	assert(mode == MODE_CEIL or mode == MODE_FLOOR, "CashLedger.quantize_money mode must be CEIL or FLOOR")
	var q: float = AmountQuantize.quantize_amount(x)
	if mode == MODE_CEIL:
		return ceili(q)
	return floori(q)


func _quote_buy_total(port: StringName, good: StringName, qty: int) -> int:
	if _quote_provider == null:
		return 0 - 1
	if not _quote_provider.has_method("quote"):
		_record_error(ERR_SYS05_04, "quote_provider", null, "quote provider missing quote()")
		return 0 - 1
	var q: Variant = _quote_provider.call("quote", port, good, SIDE_BUY, qty)
	if typeof(q) != TYPE_DICTIONARY:
		return 0 - 1
	var d: Dictionary = q
	if not d.has(KEY_TOTAL_LI):
		return 0 - 1
	return int(d[KEY_TOTAL_LI])


func _days_held_in_season(sched: ChargeSchedule, season_start: int, season_end_exclusive: int) -> int:
	# 含起日、不含止日；裁切至本季
	var start_i: int = sched.start_day
	if start_i < season_start:
		start_i = season_start
	var end_i: int = season_end_exclusive
	if sched.end_day >= 0 and sched.end_day < end_i:
		end_i = sched.end_day
	if end_i <= start_i:
		return 0
	return end_i - start_i


func _is_authorized(requester: StringName) -> bool:
	# AUTHORIZED_REQUESTERS unchanged（D-03）；sole exception = REQUESTER_GENESIS_GRANT.
	if requester == REQUESTER_GENESIS_GRANT:
		return true
	for r in AUTHORIZED_REQUESTERS:
		if r == requester:
			return true
	return false


func _coerce_entry(item: Variant) -> PostingEntry:
	if item is PostingEntry:
		var pe: PostingEntry = item
		if not _is_int_amount(pe.amount):
			return null
		return pe
	if typeof(item) == TYPE_DICTIONARY:
		var d: Dictionary = item
		if not d.has("account_id") or not d.has("amount"):
			return null
		var amt: Variant = d["amount"]
		if not _is_int_amount(amt):
			return null
		return make_entry(StringName(String(d["account_id"])), int(amt))
	return null


func _is_int_amount(value: Variant) -> bool:
	# ERR-SYS05-05：非整數拒絕（含 1.5）
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return float(value) == floorf(float(value))
	return false


func _add_checked(a: int, b: int) -> bool:
	# ERR-SYS05-08 粗檢：同號相加不可變號反向溢位
	if b == 0:
		return true
	if b > 0:
		return a <= a + b
	return a >= a + b


func _restore_snap(balances: Dictionary, arrears_map: Dictionary) -> void:
	for k in balances.keys():
		var acc: Account = _accounts[k]
		acc.balance = int(balances[k])
		acc.arrears = int(arrears_map[k])


func _ensure_system_account(id: StringName, kind: Account.Kind) -> void:
	var key := String(id)
	if _accounts.has(key):
		return
	var acc := Account.new()
	acc.id = id
	acc.kind = kind
	acc.owner_id = &""
	acc.balance = 0
	acc.arrears = 0
	acc.arrears_seasons = 0
	_accounts[key] = acc
	_init_season_stats(key)


func _init_season_stats(key: String) -> void:
	_season_stats[key] = _empty_stats()
	var acc: Account = _accounts[key]
	_season_stats[key][SeasonLedgerReport.KEY_OPENING] = acc.balance


func _empty_stats() -> Dictionary:
	return {
		SeasonLedgerReport.KEY_OPENING: 0,
		SeasonLedgerReport.KEY_SUM_CREDIT: 0,
		SeasonLedgerReport.KEY_SUM_DEBIT: 0,
		SeasonLedgerReport.KEY_CHARGES: 0,
		SeasonLedgerReport.KEY_ARREARS_NEW: 0,
		SeasonLedgerReport.KEY_CLOSING: 0,
	}


func _bump_season_stat(key: String, field: String, delta: int) -> void:
	if not _season_stats.has(key):
		_init_season_stats(key)
	var row: Dictionary = _season_stats[key]
	row[field] = int(row.get(field, 0)) + delta
	_season_stats[key] = row


func _reset_season_stats_opening() -> void:
	for k in _accounts.keys():
		_init_season_stats(String(k))


func _clear_state() -> void:
	_accounts = {}
	_postings = []
	_charges = []
	_next_posting_id = 1
	_day = DAY_PLACEHOLDER
	_season_index = 0
	_season_start_day = DAY_PLACEHOLDER
	_season_stats = {}
	_loaded = false
	_quote_provider = null
	_clear_last_error()


func _clear_last_error() -> void:
	_last_error = {}


func _fail(code: StringName, field: String, value: Variant, message: String) -> Error:
	# r589／D290／R2-05: status fail → FAILED；ErrorInfo via last_error() only.
	_record_error(code, field, value, message)
	return FAILED


func _record_error(code: StringName, field: String, value: Variant, message: String) -> void:
	var info: Dictionary = _err(code, field, value, message)
	_last_error = info
	push_error("CashLedger: %s" % str(info))


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	# D-04 ErrorInfo = {code, sys, detail}; C-06 file/field/value live in detail.
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("CashLedger: %s" % str(e))
