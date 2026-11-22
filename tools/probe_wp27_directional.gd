extends SceneTree
## R9-65 B5: headless GDScript directional probe (no Python model).
## Run: godot --headless --path . -s res://tools/probe_wp27_directional.gd


func _init() -> void:
	var ok := true
	## EX-23-04-01 integer path
	var S: int = 110
	var W: int = 300
	var f_ppm: int = 100000
	var ppm: int = 1000000
	var stock := {"A": 100, "B": 10, "C": 0}
	var w := {"A": 0, "B": 200, "C": 100}
	var exports := {}
	for p in ["A", "B", "C"]:
		var sp: int = int(stock[p])
		var numer: int = sp * W - S * int(w[p])
		var e: int = 0
		if numer > 0:
			e = (f_ppm * numer) / (W * ppm)
		if e > 0:
			exports[p] = e
	if str(exports) != str({"A": 10}):
		print("FAIL exports=", exports)
		ok = false
	else:
		print("EX-23-04-01 exports ", exports)
	## MET-01 TH-01b
	var ratio := 1.0
	var th01 := 0.4
	var th01b := 0.6
	var met01_pass: bool = th01 <= ratio and ratio <= th01b
	print("MET-01 TH-01b: ratio=1.0 pass=", met01_pass)
	if met01_pass:
		ok = false
	## MET-05b
	var met05b_pass := "N/A"
	print("MET-05b pass always ", met05b_pass)
	## OBS-02 streak
	var beggar := [0, 0, 0, 1]
	var streak := 0
	var best := 0
	for b in beggar:
		if int(b) == 0:
			streak += 1
			if streak > best:
				best = streak
		else:
			streak = 0
	print("OBS-02 longest_zero_beggar_streak ", best)
	if best != 3:
		ok = false
	if ok:
		print("PROBE_OK")
	else:
		print("PROBE_FAIL")
	quit(0 if ok else 1)
