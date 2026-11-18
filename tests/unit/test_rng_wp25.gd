extends GutTest
## WP-25 Rng derive hash (TechSpec 11-08 / FRM-SYS23-10 / TST-SYS23-08).


## Unsigned vectors as signed bit-patterns (Godot clamps hex literals > INT64_MAX).
const FNV_EMPTY := -3750763034362895579
const FNV_A := -5808556873153909620
const SPLITMIX0_FIRST := -2152535657050944081


func test_TST_SYS23_08_fnv_empty() -> void:
	var empty := PackedByteArray()
	assert_eq(Rng.fnv1a64(empty), FNV_EMPTY)


func test_TST_SYS23_08_fnv_letter_a() -> void:
	var buf := "a".to_utf8_buffer()
	assert_eq(Rng.fnv1a64(buf), FNV_A)


func test_WP25_11_08_splitmix64_state0_first() -> void:
	var step: Array = Rng.next(0)
	assert_eq(step[1], SPLITMIX0_FIRST)


func test_WP25_11_08_field_sep_no_collision() -> void:
	# "PT-1" + "0" must not collide with "PT-10" (+ empty item) across 0x1F separators.
	var a: int = Rng.derive_seed(0, 0, "PT-1", "0", "p")
	var b: int = Rng.derive_seed(0, 0, "PT-10", "", "p")
	assert_ne(a, b)


func test_WP25_11_08_same_input_same_output() -> void:
	var x: int = Rng.derive_seed(42, 7, "PT-01", "GD-001", "lottery")
	var y: int = Rng.derive_seed(42, 7, "PT-01", "GD-001", "lottery")
	assert_eq(x, y)
