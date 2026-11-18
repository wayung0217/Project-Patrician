class_name SeasonLedgerReport
extends RefCounted
## SeasonLedgerReport (03_Systems r565 / TechSpec 3.6 D).
## 每帳戶列：opening, sum_credit, sum_debit, charges, arrears_new, closing。

const KEY_OPENING := "opening"
const KEY_SUM_CREDIT := "sum_credit"
const KEY_SUM_DEBIT := "sum_debit"
const KEY_CHARGES := "charges"
const KEY_ARREARS_NEW := "arrears_new"
const KEY_CLOSING := "closing"

var season_index: int = 0
## account_id:String → Dictionary 列（上列 KEY_*）
var accounts: Dictionary = {}
