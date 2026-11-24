#!/usr/bin/env python3
"""WP-66／17-50：比對兩份黃金 v2 CSV，列每欄第一個差異日與差異筆數。

用法：
  python3 tools/golden_compare.py a.csv b.csv
退出碼：0＝逐位元相同；1＝有差異；2＝用法／讀檔錯。
"""
from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: golden_compare.py <a.csv> <b.csv>", file=sys.stderr)
        return 2
    a_path = Path(sys.argv[1])
    b_path = Path(sys.argv[2])
    if not a_path.is_file() or not b_path.is_file():
        print(f"missing file: {a_path} or {b_path}", file=sys.stderr)
        return 2
    a_bytes = a_path.read_bytes()
    b_bytes = b_path.read_bytes()
    print(f"A={a_path} bytes={len(a_bytes)}")
    print(f"B={b_path} bytes={len(b_bytes)}")
    rows_a = load_rows(a_path)
    rows_b = load_rows(b_path)
    print(f"ROWS_A={len(rows_a)} ROWS_B={len(rows_b)}")
    if not rows_a or not rows_b:
        print("EMPTY_CSV")
        print("COMPARED_ROWS=0")
        print("COMPARED_COLS=0")
        print("COMPARED_CELLS=0")
        return 1
    cols = list(rows_a[0].keys())
    compared_rows = min(len(rows_a), len(rows_b))
    compared_cols = len(cols)
    compared_cells = compared_rows * compared_cols
    # 17-70 T4／N-13：列印比對網格；CI 要求 COMPARED_CELLS == 列×欄 且 > 0。
    print(f"COMPARED_ROWS={compared_rows}")
    print(f"COMPARED_COLS={compared_cols}")
    print(f"COMPARED_CELLS={compared_cells}")
    if a_bytes == b_bytes:
        print("IDENTICAL=1")
        return 0
    print("IDENTICAL=0")
    first_day: dict[str, str] = {}
    counts: dict[str, int] = defaultdict(int)
    for i in range(compared_rows):
        ra, rb = rows_a[i], rows_b[i]
        day = ra.get("day", "?")
        for c in cols:
            va = ra.get(c, "")
            vb = rb.get(c, "")
            if va != vb:
                counts[c] += 1
                if c not in first_day:
                    first_day[c] = day
    if len(rows_a) != len(rows_b):
        print(f"ROW_COUNT_DIFF a={len(rows_a)} b={len(rows_b)}")
    print("DIFFS_BEGIN")
    for c in cols:
        if c in counts:
            print(f"COL={c} first_diff_day={first_day[c]} diff_cells={counts[c]}")
    print("DIFFS_END")
    return 1


if __name__ == "__main__":
    sys.exit(main())
