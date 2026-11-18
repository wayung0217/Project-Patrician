class_name Rng
extends RefCounted
## SYS-00 Rng derive hash — FRM-SYS23-10 / TechSpec 11-08 (WP-25).
## Static tool only (not Autoload). mod 2^64 wrap is defined here (C-10 sole exception).
## Godot int literals clamp above INT64_MAX — store uint64 constants as signed bit-patterns.

## FNV-1a 64 offset basis (unsigned 0xcbf29ce484222325).
const FNV_OFFSET := -3750763034362895579
## FNV-1a 64 prime (unsigned 0x100000001b3) — fits signed.
const FNV_PRIME := 1099511628211
## SplitMix64 constants as signed bit-patterns of the standard uint64 values.
const SPLITMIX_INC := -7046029254386353131
const SPLITMIX_M1 := -4658895280553007687
const SPLITMIX_M2 := -7723592293110705685
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
		h = _mul_u64(h ^ int(data[i]), FNV_PRIME)
	return h


## SplitMix64 next: advances state in-place via return [new_state, output].
## Caller passes prior state; first call with 0 yields 0xE220A8397B1DCDAF (11-08).
static func next(state: int) -> Array:
	# Standard SplitMix64; all * and + wrap mod 2^64 (C-10 exception, this file only).
	var s: int = _add_u64(state, SPLITMIX_INC)
	var z: int = s
	z = _mul_u64(z ^ _ushr64(z, 30), SPLITMIX_M1)
	z = _mul_u64(z ^ _ushr64(z, 27), SPLITMIX_M2)
	var out: int = z ^ _ushr64(z, 31)
	return [s, out]


## Logical right shift for uint64 bit-pattern held in signed int.
static func _ushr64(x: int, n: int) -> int:
	if n <= 0:
		return x
	return (x >> n) & ((1 << (64 - n)) - 1)


## uint64 add via 32-bit limbs (avoids Godot clamping large int ops).
static func _add_u64(a: int, b: int) -> int:
	var a_lo: int = a & 0xffffffff
	var b_lo: int = b & 0xffffffff
	var lo_sum: int = a_lo + b_lo
	var carry: int = _ushr64(lo_sum, 32)
	var lo: int = lo_sum & 0xffffffff
	var a_hi: int = _ushr64(a, 32)
	var b_hi: int = _ushr64(b, 32)
	var hi: int = (a_hi + b_hi + carry) & 0xffffffff
	return lo | (hi << 32)


## uint64 multiply via 16-bit limbs (each product fits signed int32×int32).
static func _mul_u64(a: int, b: int) -> int:
	var a0: int = a & 0xffff
	var a1: int = _ushr64(a, 16) & 0xffff
	var a2: int = _ushr64(a, 32) & 0xffff
	var a3: int = _ushr64(a, 48) & 0xffff
	var b0: int = b & 0xffff
	var b1: int = _ushr64(b, 16) & 0xffff
	var b2: int = _ushr64(b, 32) & 0xffff
	var b3: int = _ushr64(b, 48) & 0xffff
	var r0: int = 0
	var r1: int = 0
	var r2: int = 0
	var r3: int = 0
	# Accumulate a_i * b_j into 16-bit result limbs (mod 2^64 → 4 limbs).
	var p: int
	p = a0 * b0
	r0 += p
	p = a0 * b1 + a1 * b0
	r1 += p
	p = a0 * b2 + a1 * b1 + a2 * b0
	r2 += p
	p = a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0
	r3 += p
	# Propagate carries across 16-bit limbs.
	r1 += _ushr64(r0, 16)
	r0 = r0 & 0xffff
	r2 += _ushr64(r1, 16)
	r1 = r1 & 0xffff
	r3 += _ushr64(r2, 16)
	r2 = r2 & 0xffff
	r3 = r3 & 0xffff
	return r0 | (r1 << 16) | (r2 << 32) | (r3 << 48)
