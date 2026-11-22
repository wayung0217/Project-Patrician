extends GutTest
## WP-49 property：現金 Σ 全帳戶餘額＝0（SYS-05／FRM-SYS05-01）；失敗過帳不留痕（派工 17-41 D／D-59b）.


const PARAMS_DEMO := "res://tests/fixtures/params_sys05_demo.json"

const REQUESTER_SYS04 := &"SYS-04"
const REQUESTER_SYS13 := &"SYS-13"
const REQUESTER_BAD := &"SYS-07"
const REASON_TRADE := &"TRADE"
const REASON_CHARGE := &"CHARGE"

## 種子＝具名常數（C-08）.
const PROP_SEED_CASH := 20261122
## 測試預算，非規格值.
const PROP_SEQ_LEN_CASH := 200
const PROP_MAX_AMOUNT := 5000
const PROP_CITY_TOKEN := "PROP1"
const PROP_REGIME_TOKEN := "PROP1"
## T7: named branch counts (no 1+1+1 evasions)
const KIND_BRANCHES := 3
const FAIL_MODES := 3
const CHARGE_TARGETS := 3


func before_each() -> void:
	assert_eq(Params.load_and_validate(PARAMS_DEMO).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)


func test_PROP_SYS05_sum_balances_zero_after_post_and_charge() -> void:
	# FRM-SYS05-01／示範 5.1：任意 post／charge_mandatory 後 Σ balance＝0；失敗不留痕.
	assert_eq(CashLedger.genesis_grant(), OK)
	assert_eq(CashLedger.sum_all_balances(), 0)

	var city_id: StringName = CashLedger.make_city_id(PROP_CITY_TOKEN)
	var regime_id: StringName = CashLedger.make_regime_id(PROP_REGIME_TOKEN)
	assert_eq(CashLedger.create_account(city_id, Account.Kind.CITY), OK)
	assert_eq(CashLedger.create_account(regime_id, Account.Kind.REGIME), OK)
	assert_eq(CashLedger.sum_all_balances(), 0)

	var stream := PropStream.new()
	stream.reset(Rng.derive_seed(PROP_SEED_CASH, 0, "CASH", "LEDGER", "PROP_CASH"))

	var accounts: Array[StringName] = [
		CashLedger.ACCOUNT_PLAYER,
		city_id,
		regime_id,
		CashLedger.ID_SOURCE,
		CashLedger.ID_SINK,
	]

	var fail_count: int = 0
	for _i in PROP_SEQ_LEN_CASH:
		var kind: int = stream.next_index(KIND_BRANCHES) ## 0=balanced post；1=bad post；2=charge
		match kind:
			0:
				_do_balanced_post(stream, accounts)
			1:
				if _do_failing_post(stream, accounts):
					fail_count += 1
			_:
				_do_charge(stream, accounts)

		assert_eq(
			CashLedger.sum_all_balances(),
			0,
			"SYS-05 Σ balances must stay 0 after every step"
		)

	assert_gt(fail_count, 0, "budget must include failed posts")
	_consume_expected_push_errors()


func _consume_expected_push_errors() -> void:
	## Expected ERR-SYS05-* push_error from intentional failing posts.
	for e in get_errors():
		e.handled = true


func _snapshot_balances(accounts: Array[StringName]) -> Dictionary:
	var snap: Dictionary = {}
	for id in accounts:
		snap[String(id)] = {
			"bal": CashLedger.balance(id),
			"arr": CashLedger.arrears(id),
		}
	## D-32b 斷言輔助：讀私有 _postings 長度以證失敗不留 posting 痕.
	snap["__postings"] = CashLedger._postings.size()
	return snap


func _assert_snap_equal(before: Dictionary, accounts: Array[StringName], label: String) -> void:
	for id in accounts:
		var key: String = String(id)
		assert_eq(CashLedger.balance(id), int(before[key]["bal"]), "%s balance %s" % [label, key])
		assert_eq(CashLedger.arrears(id), int(before[key]["arr"]), "%s arrears %s" % [label, key])
	assert_eq(CashLedger._postings.size(), int(before["__postings"]), "%s posting count" % label)


func _do_balanced_post(stream: PropStream, accounts: Array[StringName]) -> void:
	var amount: int = stream.next_qty(PROP_MAX_AMOUNT)
	var src_i: int = stream.next_index(accounts.size())
	var dst_i: int = stream.next_index(accounts.size())
	if dst_i == src_i:
		dst_i = (src_i + 1) % accounts.size()
	var src: StringName = accounts[src_i]
	var dst: StringName = accounts[dst_i]
	# Prefer SOURCE debit when funding; skip if voluntary debit would go negative.
	if src != CashLedger.ID_SOURCE and CashLedger.balance(src) < amount:
		src = CashLedger.ID_SOURCE
	var err: Error = CashLedger.post(
		[CashLedger.make_entry(src, 0 - amount), CashLedger.make_entry(dst, amount)],
		REASON_TRADE,
		REQUESTER_SYS04
	)
	# May still fail (e.g. SOURCE-only edge); Σ check is outside.
	if err != OK:
		pass


func _do_failing_post(stream: PropStream, accounts: Array[StringName]) -> bool:
	var before: Dictionary = _snapshot_balances(accounts)
	var mode: int = stream.next_index(FAIL_MODES)
	var err: Error = OK
	match mode:
		0:
			# Unbalanced → ERR-SYS05-02
			err = CashLedger.post(
				[CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, stream.next_qty(PROP_MAX_AMOUNT))],
				REASON_TRADE,
				REQUESTER_SYS04
			)
		1:
			# Unauthorized → ERR-SYS05-06
			var amt: int = stream.next_qty(PROP_MAX_AMOUNT)
			err = CashLedger.post(
				[
					CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - amt),
					CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, amt),
				],
				REASON_TRADE,
				REQUESTER_BAD
			)
		_:
			# Insufficient cash → ERR-SYS05-01
			var player_bal: int = CashLedger.balance(CashLedger.ACCOUNT_PLAYER)
			var over: int = player_bal + stream.next_qty(PROP_MAX_AMOUNT)
			if over <= 0:
				over = stream.next_qty(PROP_MAX_AMOUNT)
			err = CashLedger.post(
				[
					CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, 0 - over),
					CashLedger.make_entry(CashLedger.ID_SINK, over),
				],
				REASON_TRADE,
				REQUESTER_SYS04
			)
	assert_eq(err, FAILED, "expected failing post")
	_assert_snap_equal(before, accounts, "failed post must leave no trace")
	return true


func _do_charge(stream: PropStream, accounts: Array[StringName]) -> void:
	var due: int = stream.next_qty(PROP_MAX_AMOUNT)
	var target: StringName = CashLedger.ACCOUNT_PLAYER
	var pick: int = stream.next_index(CHARGE_TARGETS)
	if pick == 1:
		target = accounts[1] ## city
	elif pick == 2:
		target = accounts[2] ## regime
	CashLedger.charge_mandatory(target, due, REASON_CHARGE, REQUESTER_SYS13)
