class_name Rng
extends RefCounted
## SYS-00 Rng derive hash — FRM-SYS23-10 / TechSpec 11-08 (WP-25).
## Static tool only (not Autoload). mod 2^64 wrap is defined here (C-10 sole exception).

## FNV-1a 64 offset basis (unsigned 14695981039346656037).
const FNV_OFFSET := 0xcbf29ce484222325
## FNV-1a 64 prime (unsigned 1099511628211).
const FNV_PRIME := 0x100000001b3
## SplitMix64 increment.
const SPLITMIX_INC := 0x9e3779b97f4a7c15
const SPLITMIX_M1 := 0xbf58476d1ce4e5b9
const SPLITMIX_M2 := 0x94d049bb133111eb
## Unit-separator byte between FRM-SYS23-10 fields.
const FIELD_SEP := 0x1f


## FRM-SYS23-10: FNV-1a 64 over UTF-8 fields joined by 0x1F; result = SplitMix64 seed.
static func derive_seed(
	seed: int, day: int, port_id: String, item: String, purpose: String
) -> int:
	var parts: Array[PackedByteArray] = [
		str(seed).to_utf8_buffer(),
		str(day).to_utf8_buffer(),
		port_id.to_utf8_buffer(),
		item.to_utf8_buffer(),
		purpose.to_utf8_buffer(),
	]
	var data := PackedByteArray()
	for i in parts.size():
		if i > 0:
			data.append(FIELD_SEP)
		data.append_array(parts[i])
	return fnv1a64(data)


## FNV-1a 64 over raw bytes. Empty → offset basis (TST-SYS23-08).
static func fnv1a64(data: PackedByteArray) -> int:
	var h: int = FNV_OFFSET
	for i in data.size():
		# C-10 exception: uint64 wrap is the defined FNV step (FRM-SYS23-10).
		h = (h ^ int(data[i])) * FNV_PRIME
	return h


## SplitMix64 next: advances state in-place via return [new_state, output].
## Caller passes prior state; first call with 0 yields 0xE220A8397B1DCDAF (11-08).
static func next(state: int) -> Array:
	# Standard SplitMix64; all * and + wrap mod 2^64 (C-10 exception, this file only).
	# Shifts are logical (unsigned) — GDScript >> is arithmetic, so mask after.
	var s: int = state + SPLITMIX_INC
	var z: int = s
	z = (z ^ _ushr64(z, 30)) * SPLITMIX_M1
	z = (z ^ _ushr64(z, 27)) * SPLITMIX_M2
	var out: int = z ^ _ushr64(z, 31)
	return [s, out]


## Logical right shift for uint64 bit-pattern held in signed int (C-10 exception helpers).
static func _ushr64(x: int, n: int) -> int:
	if n <= 0:
		return x
	return (x >> n) & ((1 << (64 - n)) - 1)
