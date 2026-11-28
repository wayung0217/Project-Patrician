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
## D-23c／WP-36: second sole exception for TraderRegistry.grant_genesis_cash()；清單本身不改。
const REQUESTER_TRADER_GENESIS_GRANT := &"TRADER_GENESIS_GRANT"
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
## A18: MarketPricer.quote failure key（與 MarketPricer.KEY_ERROR 對齊）.
const KEY_ERROR := "error"

## Day／season 占位：本堆疊無 Clock（WP-02）— 見 PR 缺口。
const DAY_PLACEHOLDER := 1

var _accounts: Dictionary = {} ## String → Account
## D-84f: binary-search midpoint divisor (was 1+1).
const INT_DIV_MID_DENOM := 2
## D-84f／EX-02: failure sentinel for int APIs.
const INT_API_FAILURE := -1
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
## A19: accounts that already emitted bankruptcy_referred while continuously over threshold.
var _bankruptcy_referred_ids: Dictionary = {} ## String → true
## A23: last successful post apply meta for reverse_last_post（待追認）.
## Each row: {id, balance_delta, arrears_delta, sink_credit, debit_stat, credit_stat}
var _last_apply_meta: Array = []
var _last_post_reason: StringName = &""


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

	# A22: posting.seq 必須經 GoodsLedger；未載入不得靜默退回 posting_id（C-06）.
	if not GoodsLedger.is_loaded():
		return _fail(ERR_SYS05_04, "seq", null, "GoodsLedger must be loaded for posting.seq")

	# Snapshot for rollback（A20：含 SINK 與季統計，欠款抵償會寫入 SINK）
	var snap_balances: Dictionary = {}
	var snap_arrears: Dictionary = {}
	for pe2 in parsed:
		var k2 := String(pe2.account_id)
		var acc2: Account = _accounts[k2]
		snap_balances[k2] = acc2.balance
		snap_arrears[k2] = acc2.arrears
	var sink_key := String(ID_SINK)
	if not snap_balances.has(sink_key):
		var sink0: Account = _accounts[sink_key]
		snap_balances[sink_key] = sink0.balance
		snap_arrears[sink_key] = sink0.arrears
	var snap_season_stats: Dictionary = _season_stats.duplicate(true)

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
	var apply_meta: Array = []
	for pe4 in parsed:
		var acc4: Account = _accounts[String(pe4.account_id)]
		if pe4.amount > 0:
			var applied: Dictionary = apply_inbound_credit(acc4, pe4.amount)
			if bool(applied.get("overflow", false)):
				_restore_snap(snap_balances, snap_arrears, snap_season_stats)
				return _fail(ERR_SYS05_08, FIELD_AMOUNT, pe4.amount, "overflow on credit")
			var bal_delta: int = int(applied["balance_delta"])
			var arr_off: int = int(applied["arrears_offset"])
			deltas.append({"id": acc4.id, "delta": bal_delta, "reason": reason})
			var meta_row: Dictionary = {
				"id": acc4.id,
				"balance_delta": bal_delta,
				"arrears_delta": 0 - arr_off,
				"sink_credit": arr_off,
			}
			if arr_off > 0:
				var sink: Account = _accounts[sink_key]
				if not _add_checked(sink.balance, arr_off):
					_restore_snap(snap_balances, snap_arrears, snap_season_stats)
					return _fail(ERR_SYS05_08, FIELD_AMOUNT, arr_off, "overflow on SINK")
				sink.balance = sink.balance + arr_off
				deltas.append({"id": ID_SINK, "delta": arr_off, "reason": reason})
				_bump_season_stat(sink_key, SeasonLedgerReport.KEY_SUM_CREDIT, arr_off)
				_bump_season_stat(String(acc4.id), SeasonLedgerReport.KEY_SUM_DEBIT, arr_off)
				arrears_signals.append(acc4.id)
			if bal_delta > 0:
				_bump_season_stat(String(acc4.id), SeasonLedgerReport.KEY_SUM_CREDIT, bal_delta)
			apply_meta.append(meta_row)
		else:
			# 出帳
			if not _add_checked(acc4.balance, pe4.amount):
				_restore_snap(snap_balances, snap_arrears, snap_season_stats)
				return _fail(ERR_SYS05_08, FIELD_AMOUNT, pe4.amount, "overflow on debit")
			var new_bal: int = acc4.balance + pe4.amount
			if acc4.kind != Account.Kind.SOURCE and new_bal < 0:
				# ERR-SYS05-03 保底
				_restore_snap(snap_balances, snap_arrears, snap_season_stats)
				return _fail(ERR_SYS05_03, FIELD_AMOUNT, pe4.amount, "negative balance")
			acc4.balance = new_bal
			deltas.append({"id": acc4.id, "delta": pe4.amount, "reason": reason})
			_bump_season_stat(String(acc4.id), SeasonLedgerReport.KEY_SUM_DEBIT, 0 - pe4.amount)
			apply_meta.append({
				"id": acc4.id,
				"balance_delta": pe4.amount,
				"arrears_delta": 0,
				"sink_credit": 0,
			})

	# Commit posting record
	var posting := Posting.new()
	posting.posting_id = _next_posting_id
	_next_posting_id = _next_posting_id + 1
	posting.day = _day
	# seq 與貨物事件共用 GoodsLedger 序列（TechSpec D148）；A22：已於上方閘門
	posting.seq = GoodsLedger.next_seq()
	posting.requester = requester
	posting.reason = reason
	posting.entries = parsed
	_postings.append(posting)
	_last_apply_meta = apply_meta
	_last_post_reason = reason

	for d in deltas:
		var did: StringName = d["id"]
		var acc_d: Account = _accounts[String(did)]
		cash_changed.emit(did, acc_d.balance, int(d["delta"]), reason)
	for aid in arrears_signals:
		var acc_a: Account = _accounts[String(aid)]
		arrears_changed.emit(acc_a.id, acc_a.arrears, acc_a.arrears_seasons)
	return OK


func reverse_last_post(requester: StringName) -> Error:
	## WP-63 (f)／D-96d: validate-all-then-write；保留原分錄、只追加沖銷分錄.
	## TradeDesk 步驟 6 備用回滾；不經入帳抵欠路徑，直接還原 balance／arrears／SINK／季統計效應.
	assert(_loaded, "CashLedger.reverse_last_post before load")
	_clear_last_error()
	if not _is_authorized(requester):
		return _fail(ERR_SYS05_06, FIELD_REQUESTER, requester, "unauthorized requester")
	if _last_apply_meta.is_empty() or _postings.is_empty():
		return _fail(ERR_SYS05_04, FIELD_ENTRIES, null, "no posting to reverse")
	if not GoodsLedger.is_loaded():
		return _fail(ERR_SYS05_04, "seq", null, "GoodsLedger must be loaded for reverse_last_post")

	var sink: Account = _accounts[String(ID_SINK)]
	## Phase 1: complete validation (all-or-nothing); no writes.
	var i_v: int = _last_apply_meta.size()
	while i_v > 0:
		i_v = i_v - 1
		var mv: Dictionary = _last_apply_meta[i_v]
		var aid_v: StringName = mv["id"]
		var acc_v: Account = _accounts[String(aid_v)]
		var bal_dv: int = int(mv["balance_delta"])
		var arr_dv: int = int(mv["arrears_delta"])
		var sink_cv: int = int(mv["sink_credit"])
		if bal_dv != 0 and not _add_checked(acc_v.balance, 0 - bal_dv):
			return _fail(ERR_SYS05_08, FIELD_AMOUNT, bal_dv, "overflow reversing balance")
		if arr_dv != 0 and acc_v.arrears - arr_dv < 0:
			return _fail(ERR_SYS05_03, "arrears", acc_v.arrears - arr_dv, "arrears underflow on reverse")
		if sink_cv > 0 and not _add_checked(sink.balance, 0 - sink_cv):
			return _fail(ERR_SYS05_08, FIELD_AMOUNT, sink_cv, "overflow reversing SINK")

	## Phase 2: apply undo writes.
	var signals_cash: Array = []
	var signals_arr: Array = []
	var i: int = _last_apply_meta.size()
	while i > 0:
		i = i - 1
		var m: Dictionary = _last_apply_meta[i]
		var aid: StringName = m["id"]
		var acc: Account = _accounts[String(aid)]
		var bal_d: int = int(m["balance_delta"])
		var arr_d: int = int(m["arrears_delta"])
		var sink_c: int = int(m["sink_credit"])
		if bal_d != 0:
			acc.balance = acc.balance - bal_d
			signals_cash.append({"id": aid, "delta": 0 - bal_d})
			if bal_d > 0:
				_bump_season_stat(String(aid), SeasonLedgerReport.KEY_SUM_CREDIT, 0 - bal_d)
			elif bal_d < 0:
				_bump_season_stat(String(aid), SeasonLedgerReport.KEY_SUM_DEBIT, bal_d)
		if arr_d != 0:
			acc.arrears = acc.arrears - arr_d
			signals_arr.append(aid)
		if sink_c > 0:
			sink.balance = sink.balance - sink_c
			signals_cash.append({"id": ID_SINK, "delta": 0 - sink_c})
			_bump_season_stat(String(ID_SINK), SeasonLedgerReport.KEY_SUM_CREDIT, 0 - sink_c)
			_bump_season_stat(String(aid), SeasonLedgerReport.KEY_SUM_DEBIT, 0 - sink_c)

	## Keep original posting; append reverse audit row with new seq (D-96d).
	var orig: Posting = _postings[_postings.size() - 1] as Posting
	var rev := Posting.new()
	rev.posting_id = _next_posting_id
	_next_posting_id = _next_posting_id + 1
	rev.day = _day
	rev.seq = GoodsLedger.next_seq()
	rev.requester = requester
	rev.reason = orig.reason
	rev.entries = []
	for pe_o in orig.entries:
		var pe_r: PostingEntry = make_entry(pe_o.account_id, 0 - pe_o.amount)
		rev.entries.append(pe_r)
	_postings.append(rev)
	_last_apply_meta = []
	_last_post_reason = &""

	for sc in signals_cash:
		var sid: StringName = sc["id"]
		var sacc: Account = _accounts[String(sid)]
		cash_changed.emit(sid, sacc.balance, int(sc["delta"]), orig.reason)
	for arid in signals_arr:
		var aacc: Account = _accounts[String(arid)]
		arrears_changed.emit(aacc.id, aacc.arrears, aacc.arrears_seasons)
	return OK


func has_account(id: StringName) -> bool:
	## FRM-SYS05-13 (0)(b): assert-free existence check for TradeDesk pre-validation.
	assert(_loaded, "CashLedger.has_account before load")
	return _accounts.has(String(id))


func balance(id: StringName) -> int:
	assert(_loaded, "CashLedger.balance before load")
	var key := String(id)
	assert(_accounts.has(key), "unknown account %s" % key)
	return (_accounts[key] as Account).balance



func last_posting_seq() -> int:
	## D-89b 待追認: readonly last Posting.seq (was _postings cross-module).
	assert(_loaded, "CashLedger.last_posting_seq before load")
	if _postings.is_empty():
		return 0
	return int((_postings[_postings.size() - 1] as Posting).seq)

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
	# A20／C-10：乘法溢位 → ERR-SYS05-08
	var out: Array = []
	_clear_last_error()
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
		if not _add_checked(w_sum, wi):
			_record_error(ERR_SYS05_08, FIELD_WEIGHTS, wi, "weight sum overflow")
			return []
		w_sum = w_sum + wi
	if w_sum == 0:
		_record_error(ERR_SYS05_09, FIELD_WEIGHTS, w_sum, "weight sum 0")
		return []

	var bases: Array = []
	var mods: Array = [] ## {mod, index}
	var base_sum: int = 0
	for i in range(w_ints.size()):
		var wi2: int = int(w_ints[i])
		if not _mul_checked(total, wi2):
			_record_error(ERR_SYS05_08, FIELD_AMOUNT, {"total": total, "weight": wi2}, "split multiply overflow")
			return []
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
	# A20／C-10：乘法溢位 → ERR-SYS05-08
	assert(_loaded, "CashLedger.prorate before load")
	_clear_last_error()
	if fee < 0 or days_held < 0:
		_record_error(ERR_SYS05_05, FIELD_AMOUNT, {"fee": fee, "days_held": days_held}, "prorate negative input")
		return 0
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	assert(days_d > 0, "DAYS_PER_SEASON must be > 0")
	if days_held == 0 or fee == 0:
		return 0
	if not _mul_checked(fee, days_held):
		_record_error(ERR_SYS05_08, FIELD_AMOUNT, {"fee": fee, "days_held": days_held}, "prorate multiply overflow")
		return INT_API_FAILURE
	var product: int = fee * days_held
	var pad: int = days_d - 1
	if not _add_checked(product, pad):
		_record_error(ERR_SYS05_08, FIELD_AMOUNT, product, "prorate ceil-pad overflow")
		return INT_API_FAILURE
	# 整數 CEIL(fee * days_held / D) = (fee * days_held + D - 1) / D
	var numer: int = product + pad
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
	# FRM-SYS05-09／D-124（Owner 2026-11-24；docs/spec v6.99.220；03_Systems r574）：
	# q_afford = 最大 q 同時滿足 buy_total(q) ≤ balance 且 q ≤ s
	# ＝ MIN(現金可負擔量, s)；s = 該港該貨 MARKET 庫存。
	# s = 0 → 回 0，不以 q = 1 試探；倍增／二分不得以 q > s 呼叫 quote()
	# （r451：買量須 ≤ s，否則 ERR-SYS04-06；收斂上界＝回到 quote 定義域，非 C-06 clamp）。
	# A18：quote 失敗不得當 total＝0；視為該 q 不可買。
	# 數值例：frm_examples EX-05-09-01 至 03。庫存不再於 FRM-SYS05-10 重做。
	assert(_loaded, "CashLedger.max_affordable_qty before load")
	var bal: int = balance(actor)
	if bal <= 0:
		return 0
	if _quote_provider == null:
		_record_error(ERR_SYS05_04, "quote_provider", null, "quote provider missing (MarketPricer WP-06 gap)")
		return 0
	## FRM-SYS05-09／D-124／D-125 甲（Owner 2026-11-25；v6.99.222）：
	## 庫存上界無條件適用（不限 MarketPricer／DemoQuoteProvider）；
	## exclusive upper = s+1；s = MARKET 庫存。舊測 Given 須先種足量庫存。
	## abs_hi sentinel -1 =「尚未設庫存上界」(AI_README 6.2 EX-02；不得輸出／存檔)。
	## D-08d：容器地址字串只由 GoodsLedger.container_id 產生；KIND+PORT Dictionary
	## → get_qty → _container_key → container_id（不用 make_market）。
	## 2.8：GoodsLedger.is_loaded 未見 03_Systems H → 缺口見 evening-17-69-lane2
	## （is_loaded 沿用既有 Autoload 慣例）。
	var abs_hi: int = -1
	if GoodsLedger.is_loaded():
		var port_s: String = String(port)
		var market: Dictionary = {
			GoodsLedger.KEY_KIND: GoodsLedger.KIND_MARKET,
			GoodsLedger.KEY_PORT: port_s,
		}
		var stock_cap: int = GoodsLedger.get_qty(market, good)
		## D-124／EX-05-09-03：s = 0 → 0；不得以 q = 1 呼叫 quote()。
		if stock_cap < 1:
			return 0
		abs_hi = stock_cap + 1
		## FRM-SYS05-09／D-124（17-88 A2／H5）：
		## abs_hi 已定且 s≥1 後，先單次 quote(q＝s) 取總額；總額有效且 ≤ 餘額 → 直接回 s。
		## 否則（報價失敗或總額 > 餘額）走現行搜尋；結果與副作用不變；不以 q > s 呼叫 quote。
		var t_stock: int = _quote_buy_total(port, good, stock_cap)
		if t_stock >= 0 and t_stock <= bal:
			return stock_cap
	# 擴張上界：hi 倍增直到 total > bal 或 quote 失敗（或碰到 s+1，永不 quote q>s）
	var lo: int = 0
	var hi: int = 1
	while true:
		if abs_hi > 0 and hi >= abs_hi:
			hi = abs_hi
			break
		var t_hi: int = _quote_buy_total(port, good, hi)
		if t_hi < 0 or t_hi > bal:
			break
		lo = hi
		# hi = hi * 2 without literal 2
		var next_hi: int = hi + hi
		if next_hi <= hi:
			# overflow / cap
			break
		if abs_hi > 0 and next_hi >= abs_hi:
			hi = abs_hi
			break
		hi = next_hi
	# 二分
	while lo + 1 < hi:
		var mid: int = floori((lo + hi) / INT_DIV_MID_DENOM)
		var t_mid: int = _quote_buy_total(port, good, mid)
		if t_mid < 0 or t_mid > bal:
			hi = mid
		else:
			lo = mid
	# 整數 quote 校正：確認 lo 可負擔、lo+1 不可
	if lo > 0:
		var t_lo: int = _quote_buy_total(port, good, lo)
		if t_lo < 0 or t_lo > bal:
			lo = lo - 1
	return lo


func buy_slider_max(q_afford: int, hold_free: int, stock: int) -> int:
	# FRM-SYS05-10：買 = MIN(q_afford, hold_free, stock)
	# D-124：庫存上界已在 FRM-SYS05-09 的 q_afford；此處不再重做 stock 語意。
	# A22／C-06：負數不得靜默夾成 0
	_clear_last_error()
	if q_afford < 0 or hold_free < 0 or stock < 0:
		_record_error(
			ERR_SYS05_05,
			FIELD_AMOUNT,
			{"q_afford": q_afford, "hold_free": hold_free, "stock": stock},
			"buy_slider_max negative input"
		)
		return INT_API_FAILURE
	var m: int = q_afford
	if hold_free < m:
		m = hold_free
	if stock < m:
		m = stock
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
		# 4 FRM-SYS05-08；A19：達門檻只發一次，清償歸零後可再發
		if acc.arrears > 0:
			acc.arrears_seasons = acc.arrears_seasons + 1
		else:
			acc.arrears_seasons = 0
			_bankruptcy_referred_ids.erase(acc_id)
		arrears_changed.emit(acc.id, acc.arrears, acc.arrears_seasons)
		if acc.arrears_seasons >= bankrupt_lim:
			if not _bankruptcy_referred_ids.has(acc_id):
				_bankruptcy_referred_ids[acc_id] = true
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
	## A18：quote 失敗（error 鍵）回 INT_API_FAILURE，不得把 total_li＝0 當可負擔.
	if _quote_provider == null:
		return INT_API_FAILURE
	if not _quote_provider.has_method("quote"):
		_record_error(ERR_SYS05_04, "quote_provider", null, "quote provider missing quote()")
		return INT_API_FAILURE
	var q: Variant = _quote_provider.call("quote", port, good, SIDE_BUY, qty)
	if typeof(q) != TYPE_DICTIONARY:
		return INT_API_FAILURE
	var d: Dictionary = q
	if d.has(KEY_ERROR):
		return INT_API_FAILURE
	if not d.has(KEY_TOTAL_LI):
		return INT_API_FAILURE
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
	# AUTHORIZED_REQUESTERS unchanged（D-03／D-23c）；exceptions are named constants only.
	if requester == REQUESTER_GENESIS_GRANT:
		return true
	if requester == REQUESTER_TRADER_GENESIS_GRANT:
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


func _mul_checked(a: int, b: int) -> bool:
	# A20／C-10／ERR-SYS05-08：乘法溢位檢查（不得依賴環繞）
	if a == 0 or b == 0:
		return true
	var product: int = a * b
	return product / a == b


func _restore_snap(balances: Dictionary, arrears_map: Dictionary, season_stats: Dictionary = {}) -> void:
	## A20：還原分錄帳戶＋SINK 抵欠與季統計
	for k in balances.keys():
		var acc: Account = _accounts[k]
		acc.balance = int(balances[k])
		acc.arrears = int(arrears_map[k])
	if not season_stats.is_empty():
		_season_stats = season_stats.duplicate(true)


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
	_bankruptcy_referred_ids = {}
	_last_apply_meta = []
	_last_post_reason = &""
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
