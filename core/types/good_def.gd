class_name GoodDef
extends Resource
## SYS-01 GoodDef static cargo definition (03_Systems §1 / TechSpec 3.2).
## controlled_scale_only is derived at load (FRM-SYS01-02), not an exported authoring field.

@export var good_id: String = ""
@export var name_zh: String = ""
@export var tier: int = 0
@export var is_staple: bool = false
@export var is_build_material: bool = false
@export var is_strategic: bool = false
@export var base_price_li: int = 0
## Bitmask; D-08a MVP must be year-full = 2^PRM-SYS00-SEASONS_PER_YEAR − 1 (validated by GoodCatalog).
@export var season_mask: int = 0

## FRM-SYS01-02 derived: (tier > FREE_PORT_TIER_MAX) OR is_strategic.
var controlled_scale_only: bool = false
