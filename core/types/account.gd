class_name Account
extends RefCounted
## ST-CASH Account (03_Systems r560 / TechSpec 3.6 D).
## Kind is authoritative; never parse id string for kind (TechSpec 3.6).

enum Kind { ACTOR, CITY, REGIME, SOURCE, SINK }

var id: StringName = &""
var kind: Kind = Kind.ACTOR
var owner_id: StringName = &""
var balance: int = 0 ## 厘；SOURCE 可為負
var arrears: int = 0 ## ≥ 0
var arrears_seasons: int = 0 ## ≥ 0
