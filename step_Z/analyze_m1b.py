#!/usr/bin/env python3
"""Analyze Step Z season_ports vs draft_class_test C / M1b three bars (Y5=season 19)."""
from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

# D-109(f) / D-112(e): year-5 (season_index 19) class-share bands
RICH_LO, RICH_HI = 0.03, 0.08
CIT_LO, CIT_HI = 0.20, 0.40
POOR_MIN = 0.45
BEGGAR_MAX = 0.10
POP_FLOOR = 0.90  # vs opening total

# M1b three bars (dispatch): Y5 floor/ceiling cells ≤30%; three-tier ratios same order as open; city cash not monotonically rising


def load_ports(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def as_int(v: str) -> int:
    try:
        return int(float(v))
    except Exception:
        return 0


def analyze_group(label: str, ports_path: Path, opening_total: int | None = None) -> dict:
    rows = load_ports(ports_path)
    # season 19 = end of year 5 (0-based season_index)
    y5 = [r for r in rows if as_int(r.get("season_index", "-1")) == 19]
    by_combo: dict[str, list] = defaultdict(list)
    for r in y5:
        by_combo[r.get("run_id", r.get("combo_index", "?"))].append(r)

    # Also group by combo from summary if present
    results = {"label": label, "combos": []}
    # Aggregate all Y5 ports per run_id
    runs: dict[str, list] = defaultdict(list)
    for r in y5:
        runs[str(r.get("run_id", "0"))].append(r)

    for run_id, ports in sorted(runs.items(), key=lambda x: int(x[0]) if x[0].isdigit() else 0):
        rich = sum(as_int(r["rich"]) for r in ports)
        cit = sum(as_int(r["citizen"]) for r in ports)
        poor = sum(as_int(r["poor"]) for r in ports)
        beg = sum(as_int(r["beggar"]) for r in ports)
        total = rich + cit + poor + beg
        shares = {
            "rich": rich / total if total else 0,
            "citizen": cit / total if total else 0,
            "poor": poor / total if total else 0,
            "beggar": beg / total if total else 0,
            "total": total,
        }
        class_pass = (
            RICH_LO <= shares["rich"] <= RICH_HI
            and CIT_LO <= shares["citizen"] <= CIT_HI
            and shares["poor"] >= POOR_MIN
            and shares["beggar"] <= BEGGAR_MAX
            and (opening_total is None or total >= opening_total * POP_FLOOR)
        )
        # city cash not monotonically rising: check each port across seasons
        cash_mono = {}
        for pid in sorted({r["port_id"] for r in rows if str(r.get("run_id", "0")) == run_id}):
            series = [
                as_int(r["city_balance_li"])
                for r in rows
                if str(r.get("run_id", "0")) == run_id and r["port_id"] == pid
            ]
            rising = all(series[i] <= series[i + 1] for i in range(len(series) - 1)) if len(series) > 1 else True
            cash_mono[pid] = rising
        mono_ports = sum(1 for v in cash_mono.values() if v)
        results["combos"].append(
            {
                "run_id": run_id,
                "shares": shares,
                "class_criteria_pass": class_pass,
                "city_cash_monotone_rising_ports": mono_ports,
                "city_cash_ports": len(cash_mono),
                "bar_cash_not_mono": mono_ports < len(cash_mono),  # pass if at least one port not mono rising
            }
        )
    return results


def floor_ceiling_cells(cells_path: Path) -> dict:
    """Y5 floor/ceiling band cells ≤30% of cells at season 19."""
    if not cells_path.is_file():
        return {"ok": None, "reason": "missing season_cells"}
    with cells_path.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    y5 = [r for r in rows if as_int(r.get("season_index", "-1")) == 19]
    if not y5:
        return {"ok": None, "reason": "no season 19 cells"}
    by_run: dict[str, list] = defaultdict(list)
    for r in y5:
        by_run[str(r.get("run_id", "0"))].append(r)
    out = {}
    for rid, cells in by_run.items():
        n = len(cells)
        ext = sum(1 for r in cells if str(r.get("band", "")).upper() in ("FLOOR", "CEILING", "0", "4"))
        # band may be numeric enum — also check common labels
        # Prefer band column values: look at unique
        bands = {}
        for r in cells:
            b = str(r.get("band", ""))
            bands[b] = bands.get(b, 0) + 1
        # Heuristic: FLOOR/CEILING string or extreme ints
        extreme = 0
        for r in cells:
            b = str(r.get("band", "")).upper()
            if b in ("FLOOR", "CEILING") or b.endswith("FLOOR") or b.endswith("CEILING"):
                extreme += 1
            elif b in ("0", "4"):  # possible enum ends
                extreme += 1
        pct = extreme / n if n else 0
        out[rid] = {"n": n, "extreme": extreme, "pct": pct, "bands": bands, "pass_le_30": pct <= 0.30}
    return out


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    opening = None
    # optional opening total from opening_population if provided as 2nd arg
    if len(sys.argv) > 2:
        opening = int(sys.argv[2])
    report = []
    for sub in sorted(root.iterdir()):
        if not sub.is_dir():
            continue
        ports = sub / "season_ports.csv"
        if not ports.is_file():
            continue
        a = analyze_group(sub.name, ports, opening)
        cells = floor_ceiling_cells(sub / "season_cells.csv")
        a["floor_ceiling"] = cells
        report.append(a)
        print(json.dumps(a, ensure_ascii=False, indent=2))
    (root / "analysis.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
