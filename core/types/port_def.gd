class_name PortDef
extends Resource
## SYS-02 PortDef static port definition (03_Systems §2 / TechSpec 3.3).
## draft_limit_class: stored only; not validated / not used until SYS-13 (Owner B3 / 1-A5).
##
## 缺口（承載關係）：03_Systems r256–r263／TechSpec 3.3 D 欄未列出 PortDef→RoleCell 容器欄位名。
## 實作以 role_cells: Dictionary[good_id → RoleCell] 承載 ST-ROLE，以支援 ports/*.tres 與 FRM-SYS02-01。

@export var port_id: String = ""
@export var name_zh: String = ""
@export var is_free_port: bool = false
## UNIT-DRAFT [待審] — store only (B3); no validation in SYS-02.
@export var draft_limit_class: int = 0
@export var regime_id: String = ""
## good_id (String) → RoleCell. Not listed as a D-field name in TechSpec; see file header gap note.
@export var role_cells: Dictionary = {}
