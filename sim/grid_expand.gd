class_name SimGridExpand
extends RefCounted
## FRM-SYS23-02 — cartesian product of grid; run_id = combo_index * seed_count + seed_index.


static func expand(grid: Dictionary, seeds: Array) -> Array:
	## Returns Array of {combo_index, combo: Dictionary, seed, seed_index, run_id}.
	var key_list: Array = grid.keys()
	key_list.sort() ## string ascending
	var combos: Array = [{}]
	for k_v in key_list:
		var k: String = String(k_v)
		var cands: Array = grid[k] as Array
		var next: Array = []
		for base_v in combos:
			var base: Dictionary = (base_v as Dictionary).duplicate(true)
			for cand in cands:
				var cell: Dictionary = base.duplicate(true)
				cell[k] = cand
				next.append(cell)
		combos = next
	if combos.is_empty():
		combos = [{}]
	var seed_count: int = seeds.size()
	var jobs: Array = []
	for combo_index in range(combos.size()):
		var combo: Dictionary = combos[combo_index]
		for seed_index in range(seed_count):
			var seed_v: Variant = seeds[seed_index]
			## 乙：seeds 經 JSON 可能為 float 整數 → floori 還原（非截斷真小數）。
			var seed_i: int
			if typeof(seed_v) == TYPE_INT:
				seed_i = seed_v
			else:
				seed_i = floori(float(seed_v))
			var run_id: int = combo_index * seed_count + seed_index
			jobs.append({
				"combo_index": combo_index,
				"combo": combo,
				"seed": seed_i,
				"seed_index": seed_index,
				"run_id": run_id,
			})
	return jobs
