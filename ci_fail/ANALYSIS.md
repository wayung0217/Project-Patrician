# CI fail @ b998cea (run 45418446352) — root cause

## gut-unit-gate (failure — false REMOVED)
- TOTAL_PASSING=558 ≥ 555 OK
- SEEN_NAMES=511 (under-count) → false REMOVED_NAMES (~46)
- Cause: GUT prefixes first test of each script with ANSI `\x1b[0m* test_…`;
  shard extract used `^\* (test_\w+)` and missed those lines.
- Fix tip `bb1b50d`: strip ANSI before extract; warn if names≠passing.
- Local replay on run artifacts after fix: SEEN=558 REMOVED=無 ADDED=3 EX-05-09 names.

## golden-30d (failure — intentional 2.5)
- GOLDEN_BASE_MISSING: main has no successful `golden-30d` artifact yet.
- Expected until main produces baseline; not a merge blocker for Lane2 signal.
