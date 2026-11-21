class_name PropStream
extends RefCounted
## Deterministic stream for property tests — Rng FNV-1a＋SplitMix64 only (C-08).
## No randi／randf／randomize／RandomNumberGenerator.


## Low 31 bits always non-negative in signed int64 (index helper).
const POS_31_MASK := 2147483647


var _state: int = 0


func reset(seed_state: int) -> void:
	_state = seed_state


func next_raw() -> int:
	var step: Array = Rng.next(_state)
	_state = int(step[0])
	return int(step[1])


## Uniform index in [0, bound) from SplitMix64 output.
func next_index(bound: int) -> int:
	assert(bound > 0, "PropStream.next_index bound must be > 0")
	var lo: int = next_raw() & POS_31_MASK
	return lo % bound


## Positive qty in [1, max_qty] inclusive.
func next_qty(max_qty: int) -> int:
	assert(max_qty >= 1, "PropStream.next_qty max_qty must be >= 1")
	return next_index(max_qty) + 1
