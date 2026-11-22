#!/usr/bin/env python3
"""A35 / D-85／D-88a：規範掃描（只報不擋）。

範圍：autoload、core、sim、tools、tests（含 tests/fixtures 所有 .gd）
規則：
  R1 數字字面量（含 0x 與 1+1／1.0+1.0／0-1 規避）；允許 0／1／0.0／1.0
  R2 跨模組底線成員存取（產品碼 vs 測試分開計）
  R3 int(／round(／roundi(／floor(／ceil(
  R4 await／call_deferred／process_priority／Timer／randi／randf／randomize／Time.／OS.get_ticks
  R5 DirAccess 列舉後未見 sort（啟發式）
  R6 測試名缺 TST ID（tests/unit|property 內 func test_）
  R7 FRM／ERR／PRM 字串缺同行或鄰近 ID 註解（盡力而為）

例外只能引用 AI_README 6.2 EX-01..EX-06（本腳本對已知路徑做 EX 註記，不消命中）。
退出碼：永遠 0（CI continue-on-error／本腳本不擋）。
沿用 wp51_literal_scan.py 的註解剝離做法。
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parents[1]
SCAN_DIRS = ["autoload", "core", "sim", "tools", "tests"]
PRODUCT_TOP = {"autoload", "core", "sim", "tools"}

NUM_RE = re.compile(
    r"(?<![\w.])("
    r"0x[0-9A-Fa-f]+"
    r"|-?(?:\d+\.\d+(?:[eE][+-]?\d+)?|\d+(?:[eE][+-]?\d+)?)"
    r")(?![\w.])"
)
ARITH_EVADE_RE = re.compile(
    r"(?<![\w.])(?:1\s*\+\s*1|1\.0\s*\+\s*1\.0|0\s*-\s*1)(?![\w.])"
)
PRIV_RE = re.compile(r"\b([A-Z][A-Za-z0-9]*)\._([a-zA-Z0-9_]+)\b")
CAST_RE = re.compile(r"\b(int|round|roundi|floor|ceil)\s*\(")
BANNED_RE = re.compile(
    r"\b(await|call_deferred|process_priority|randi|randf|randomize)\b"
    r"|Timer\b|\bTime\.|\bOS\.get_ticks"
)
DIR_LIST_RE = re.compile(r"\blist_dir_begin\s*\(")
SORT_RE = re.compile(r"\b(sort|sort_custom)\s*\(")
TEST_FUNC_RE = re.compile(r"^\s*func\s+(test_[A-Za-z0-9_]+)\s*\(")
TST_OK_RE = re.compile(r"(TST_|SYS\d|_SYS|_PROP_|PROP_|WP\d|R2_|R\d)")
ID_TOKEN_RE = re.compile(r"\b((?:FRM|ERR|PRM|TST|WRN)-[A-Z0-9-]+)\b")
COMMENT_ID_RE = re.compile(r"#.*\b((?:FRM|ERR|PRM|TST|WRN)-[A-Z0-9-]+)\b")

ALLOWED_NUM = {"0", "1", "0.0", "1.0", "-0", "-0.0"}

EX_PATH_HINTS = {
    "core/rng.gd": "EX-01",
    "tools/csv_import.gd": "EX-05",
}


def strip_comment(s: str) -> str:
    in_str = False
    quote = None
    out: list[str] = []
    i = 0
    while i < len(s):
        c = s[i]
        if not in_str:
            if c in ('"', "'"):
                in_str = True
                quote = c
                out.append(c)
            elif c == "#":
                break
            else:
                out.append(c)
        else:
            out.append(c)
            if c == "\\" and i + 1 < len(s):
                out.append(s[i + 1])
                i += 1
            elif c == quote:
                in_str = False
                quote = None
        i += 1
    return "".join(out)


def strip_strings(s: str) -> str:
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', s)


def is_product(rel: str) -> bool:
    return rel.split("/", 1)[0] in PRODUCT_TOP


def iter_gd_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for d in SCAN_DIRS:
        base = root / d
        if not base.exists():
            continue
        for p in base.rglob("*.gd"):
            if "addons/" in str(p).replace("\\", "/"):
                continue
            files.append(p)
    return sorted(files)


def scan_file(path: Path, root: Path, hits: dict[str, list]) -> None:
    rel = str(path.relative_to(root)).replace("\\", "/")
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    product = is_product(rel)
    bucket_priv = "R2_product" if product else "R2_tests"
    for i, raw in enumerate(lines, 1):
        code = strip_comment(raw)
        code_ns = strip_strings(code)
        note = EX_PATH_HINTS.get(rel, "")
        if ARITH_EVADE_RE.search(code_ns):
            hits["R1"].append(
                f"{rel}:{i}:ARITH_EVADE:{raw.strip()}" + (f":{note}" if note else "")
            )
        for m in NUM_RE.finditer(code_ns):
            val = m.group(1)
            if val in ALLOWED_NUM:
                continue
            tag = note
            if rel == "core/rng.gd":
                tag = "EX-01"
            elif rel == "tools/csv_import.gd" and re.search(
                r"\b10\b|place|/\s*10|%\s*10", code_ns
            ):
                tag = "EX-05"
            hits["R1"].append(
                f"{rel}:{i}:NUM={val}:{raw.strip()}" + (f":{tag}" if tag else "")
            )
        for m in PRIV_RE.finditer(code_ns):
            hits[bucket_priv].append(
                f"{rel}:{i}:{m.group(1)}._{m.group(2)}:{raw.strip()}"
            )
        for m in CAST_RE.finditer(code_ns):
            hits["R3"].append(f"{rel}:{i}:{m.group(1)}(:{raw.strip()}")
        if BANNED_RE.search(code_ns) or BANNED_RE.search(raw):
            tag = ""
            if rel.startswith("sim/") and (
                "Time.get_ticks" in raw or "OS.get_ticks" in raw
            ):
                tag = "EX-04"
            hits["R4"].append(f"{rel}:{i}:{raw.strip()}" + (f":{tag}" if tag else ""))
        if DIR_LIST_RE.search(code_ns):
            window = "\n".join(lines[i - 1 : i - 1 + 40])
            if not SORT_RE.search(window):
                hits["R5"].append(
                    f"{rel}:{i}:list_dir_begin_without_nearby_sort:{raw.strip()}"
                )
        if rel.startswith("tests/unit/") or rel.startswith("tests/property/"):
            m = TEST_FUNC_RE.match(raw)
            if m:
                name = m.group(1)
                if not TST_OK_RE.search(name):
                    hits["R6"].append(f"{rel}:{i}:{name}")
        if product:
            for m in ID_TOKEN_RE.finditer(raw):
                tok = m.group(1)
                prev = lines[i - 2] if i >= 2 else ""
                if COMMENT_ID_RE.search(raw) or COMMENT_ID_RE.search(prev):
                    continue
                if raw.strip().startswith("#"):
                    continue
                if re.search(rf'const\s+\w+.*["\']' + re.escape(tok), raw):
                    continue
                hits["R7"].append(f"{rel}:{i}:{tok}:{raw.strip()}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(DEFAULT_ROOT))
    args = ap.parse_args()
    root = Path(args.root)

    hits: dict[str, list] = defaultdict(list)
    files = iter_gd_files(root)
    for p in files:
        scan_file(p, root, hits)

    probes = sorted((root / "tests/fixtures/sys23").glob("probe_*.gd"))
    probe_names = [p.name for p in probes]

    print("A35_NORM_SCAN")
    print(f"ROOT={root}")
    print(f"FILES={len(files)}")
    print(f"PROBES_EXPECTED={len(probe_names)}:{','.join(probe_names)}")
    keys = ["R1", "R2_product", "R2_tests", "R3", "R4", "R5", "R6", "R7"]
    for k in keys:
        print(f"COUNT_{k}={len(hits[k])}")
    missing = []
    for name in probe_names:
        needle = f"tests/fixtures/sys23/{name}:"
        found = any(needle in line for bucket in hits.values() for line in bucket)
        print(f"PROBE_IN_HITS={name}:{found}")
        if not found:
            missing.append(name)
    if missing:
        print(f"PROBE_MISSING_FROM_HITS={','.join(missing)}")
    print("HITS_BEGIN")
    for k in keys:
        for line in hits[k]:
            print(f"{k}:{line}")
    print("HITS_END")
    return 0


if __name__ == "__main__":
    sys.exit(main())
