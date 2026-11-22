class_name DebugConfig
extends RefCounted
## WP-61／D-90(g)(h): UI-only debug layout／timing constants (not game economy values).
## Named constants in ui/ are allowed for pixels, font sizes, and debug clock speed.


## Real-world seconds per simulated game day while continuous play is on.
const SECONDS_PER_GAME_DAY: float = 1.0

## Sea chart layout (pixels).
const MAP_WIDTH: int = 520
const MAP_HEIGHT: int = 640
const MAP_PAD: int = 24
const NODE_RADIUS_PORT: float = 7.0
const NODE_RADIUS_JUNCTION: float = 4.0
const LANE_WIDTH: float = 1.0
const SELECTED_RING: float = 3.0

## Panel／font layout.
const FONT_SIZE_BODY: int = 14
const FONT_SIZE_TITLE: int = 16
const PANEL_MIN_WIDTH: int = 360
const MESSAGE_MAX_LINES: int = 200

## Market table column widths (approx chars; Tree uses expand).
const MARKET_ROW_MIN_HEIGHT: int = 22
