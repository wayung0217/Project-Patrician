class_name RoleCell
extends Resource
## SYS-02 RoleCell — one port × good role slot (03_Systems §2 / TechSpec 3.3).
## role uses PortRegistry.ROLE_* ints (PRODUCER=1／TRANSIT=2／TERMINAL=3); 0 = ROLE_INVALID (D-04／R3-02).

@export var role: int = 0 ## default ROLE_INVALID until set to a valid role
@export var downstream_terminals: PackedStringArray = PackedStringArray()
@export var base_output_per_season: int = 0
