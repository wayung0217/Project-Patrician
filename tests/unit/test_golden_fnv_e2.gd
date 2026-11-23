extends GutTest
## E2／FRM-SYS23-10: golden harness FNV-1a 64 matches Rng bit-pattern vectors.


func test_E2_fnv_empty_offset_basis() -> void:
	## Unsigned 14695981039346656037 as signed int64 bit-pattern.
	assert_eq(Rng.fnv1a64(PackedByteArray()), Rng.FNV_OFFSET)
	assert_eq(Rng.FNV_OFFSET, -3750763034362895579)


func test_E2_fnv_letter_a_known_vector() -> void:
	var buf := PackedByteArray()
	buf.append(0x61) ## 'a'
	assert_eq(Rng.fnv1a64(buf), -5808556873153909620)


func test_E2_golden_harness_fnv_matches_rng() -> void:
	## tools/golden_harness.gd _fnv1a64 must use Rng, not String.hash().
	var harness: GDScript = load("res://tools/golden_harness.gd") as GDScript
	assert_ne(harness, null)
	var src: String = FileAccess.get_file_as_string("res://tools/golden_harness.gd")
	assert_true(src.contains("Rng.fnv1a64"), "golden_harness must call Rng.fnv1a64")
	assert_false(src.contains("s.hash()"), "golden_harness must not use String.hash()")
