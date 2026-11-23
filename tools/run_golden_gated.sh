#!/usr/bin/env bash
# D-111(e)／F6: run golden_harness; fail if log has ERROR or SCRIPT ERROR lines.
# Usage:
#   tools/run_golden_gated.sh --godot /path/to/godot --out /abs/out.csv [--days 360] [--seed 1] [--log /abs/run.log]
set -euo pipefail

GODOT="${GODOT:-godot}"
OUT=""
DAYS=360
SEED=1
LOG=""
PROJECT="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot) GODOT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$OUT" ]]; then
  echo "require --out <abs.csv>" >&2
  exit 2
fi
if [[ -z "$LOG" ]]; then
  LOG="${OUT%.csv}.log"
fi

mkdir -p "$(dirname "$OUT")" "$(dirname "$LOG")"

set +e
"$GODOT" --headless --path "$PROJECT" -s res://tools/golden_harness.gd -- \
  --out "$OUT" --days "$DAYS" --seed "$SEED" 2>&1 | tee "$LOG"
GODOT_RC=${PIPESTATUS[0]}
set -e

# Count ERROR / SCRIPT ERROR lines (Godot push_error / script faults).
ERROR_N=$(grep -cE '^ERROR:' "$LOG" || true)
SCRIPT_N=$(grep -cF 'SCRIPT ERROR' "$LOG" || true)
# Also match indented Godot engine prefixes that still contain the tokens.
if [[ "$ERROR_N" -eq 0 ]]; then
  ERROR_N=$(grep -cE 'ERROR:' "$LOG" || true)
fi
if [[ "$SCRIPT_N" -eq 0 ]]; then
  SCRIPT_N=$(grep -cF 'SCRIPT ERROR' "$LOG" || true)
fi

echo "GOLDEN_GATE ERROR=$ERROR_N SCRIPT_ERROR=$SCRIPT_N godot_rc=$GODOT_RC log=$LOG"

if [[ "$GODOT_RC" -ne 0 ]]; then
  exit "$GODOT_RC"
fi
if [[ "$ERROR_N" -gt 0 || "$SCRIPT_N" -gt 0 ]]; then
  echo "GOLDEN_GATE FAIL: ERROR or SCRIPT ERROR lines > 0" >&2
  exit 1
fi
echo "GOLDEN_GATE PASS"
exit 0
