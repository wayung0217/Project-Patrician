class_name AmountQuantize
extends RefCounted
## D-01 / N-04: single shared money float snap before ceili／floori.
## SYS-04 and SYS-05 must route all money float→int via quantize_amount(); no bare EPS.

const PRM_ROUND_EPS := "PRM-SYS04-ROUND_EPS"


static func quantize_amount(x: float) -> float:
	# FRM-SYS04-05 + D-01: if |x − ROUND(x)| <= ROUND_EPS × max(1,|x|) then x = ROUND(x).
	# D-01 authorizes round() for this snap only; final int still via ceili／floori (C-09).
	assert(Params.is_loaded(), "AmountQuantize.quantize_amount requires Params")
	var eps: float = Params.get_float(PRM_ROUND_EPS)
	var nearest: float = round(x)
	var scale: float = absf(x)
	if scale < 1.0:
		scale = 1.0
	if absf(x - nearest) <= eps * scale:
		return nearest
	return x
