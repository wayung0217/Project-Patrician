#!/usr/bin/env python3
"""Prepare a pinned M1b scenario JSON for smoke / CI (strip ABUND clash; pin grid)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


GROUPS = {
    "Za_G0_A0": ("docs/spec/scenario_M1b_G0.json", 0, True, 1, False),
    "Za_G0_A250": ("docs/spec/scenario_M1b_G0.json", 250000, True, 1, False),
    "Za_G1_A0": ("docs/spec/scenario_M1b_G1.json", 0, True, 1, False),
    "Za_G1_A250": ("docs/spec/scenario_M1b_G1.json", 250000, True, 1, False),
    "Za_G2_A0": ("docs/spec/scenario_M1b_G2.json", 0, True, 1, False),
    "Za_G2_A250": ("docs/spec/scenario_M1b_G2.json", 250000, True, 1, False),
    "Zb_G0_notrader": ("docs/spec/scenario_M1b_G0.json", 0, False, 1, False),
    "Zc_G0H_A0": ("docs/spec/scenario_M1b_G0H.json", 0, True, 1, True),
    "Zd_G0_seed2": ("docs/spec/scenario_M1b_G0.json", 0, True, 2, False),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", required=True, choices=sorted(GROUPS.keys()))
    ap.add_argument("--out", required=True)
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()
    rel, abund, traders, seed, housing = GROUPS[args.group]
    src = Path(args.repo) / rel
    obj = json.loads(src.read_text(encoding="utf-8"))
    ov = obj.get("overrides") or {}
    ov.pop("PRM-SYS07-ABUND_BONUS_MAX_PPM", None)
    obj["overrides"] = ov
    obj["grid"] = {"PRM-SYS07-ABUND_BONUS_MAX_PPM": [int(abund)]}
    obj["seeds"] = [int(seed)]
    layers = obj.get("layers") or {}
    layers["TRADERS"] = bool(traders)
    layers["CITY_HOUSING"] = bool(housing)
    obj["layers"] = layers
    obj["scenario_id"] = args.group
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
