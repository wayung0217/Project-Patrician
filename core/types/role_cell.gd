class_name RoleCell
extends Resource
## SYS-02 RoleCell — one port × good role slot (03_Systems §2 / TechSpec 3.3).
## role uses PortRegistry.ROLE_* ints (enum order PRODUCER／TRANSIT／TERMINAL; no NONE).

@export var role: int = 0
@export var downstream_terminals: PackedStringArray = PackedStringArray()
@export var base_output_per_season: int = 0
