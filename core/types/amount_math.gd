class_name AmountMath
extends RefCounted
## D-01 shared money quantization for SYS-04／SYS-05 (N-04).
## Normalize float near an integer within PRM-SYS04-ROUND_EPS, then ceili／floori.
## Bare 1e-9 forbidden — EPS only via Params.

const PRM_ROUND_EPS := "PRM-SYS04-ROUND_EPS"

## mode literals 0／1 only (D-04／C-03).
const MODE_CEIL := 0
const MODE_FLOOR := 1

const _ONE_F := 1.0


static func quantize_amount(x: float, mode: int) -> int:
	# FRM-SYS04-05 pre-step (D-01): if |x−round(x)| <= EPS×max(1,|x|) then x = round(x); then ceili／floori.
	assert(Params.is_loaded(), "AmountMath.quantize_amount requires Params")
	assert(mode == MODE_CEIL or mode == MODE_FLOOR, "AmountMath.quantize_amount mode must be CEIL or FLOOR")
	var eps: float = Params.get_float(PRM_ROUND_EPS)
	var nearest: float = roundf(x)
	var scale: float = absf(x)
	if scale < _ONE_F:
		scale = _ONE_F
	if absf(x - nearest) <= eps * scale:
		x = nearest
	if mode == MODE_CEIL:
		return ceili(x)
	return floori(x)
