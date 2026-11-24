# M1b report

Input: `/home/runner/work/Project-Patrician/Project-Patrician/out/m1b`

## ① Class shares (Y5 season 19 / draft_class_test C)

| Group | status | rich% | cit% | poor% | beg% | pop | class |
|-------|--------|-------|------|-------|------|-----|-------|
| Za_G0_A0 | ok | 5.82 | 22.04 | 66.64 | 5.50 | 20365 | FAIL |
| Za_G0_A250 | ok | 6.02 | 22.71 | 65.34 | 5.93 | 19866 | FAIL |
| Za_G1_A0 | ok | 5.98 | 16.70 | 71.77 | 5.55 | 20277 | FAIL |
| Za_G1_A250 | ok | 6.03 | 17.31 | 70.72 | 5.94 | 19931 | FAIL |
| Za_G2_A0 | ok | 5.85 | 22.05 | 66.61 | 5.49 | 20349 | FAIL |
| Za_G2_A250 | ok | 5.95 | 22.67 | 65.45 | 5.93 | 19901 | FAIL |
| Zb_G0_notrader | ok | 5.82 | 22.04 | 66.64 | 5.50 | 20365 | FAIL |
| Zc_G0H_A0 | ok | 5.82 | 22.04 | 66.64 | 5.50 | 20365 | FAIL |
| Zd_G0_seed2 | ok | 5.82 | 22.04 | 66.64 | 5.50 | 20365 | FAIL |

## ② Floor/ceiling band cells ≤30% (Y5)

| Group | status | band0+4%% | pass |
|-------|--------|----------|------|
| Za_G0_A0 | ok | 96.7 | FAIL |
| Za_G0_A250 | ok | 97.1 | FAIL |
| Za_G1_A0 | ok | 97.3 | FAIL |
| Za_G1_A250 | ok | 97.1 | FAIL |
| Za_G2_A0 | ok | 96.7 | FAIL |
| Za_G2_A250 | ok | 97.1 | FAIL |
| Zb_G0_notrader | ok | 96.7 | FAIL |
| Zc_G0H_A0 | ok | 96.7 | FAIL |
| Zd_G0_seed2 | ok | 96.7 | FAIL |

## ③ Three-tier ratio order vs opening

| Group | status | order | pass |
|-------|--------|-------|------|
| Za_G0_A0 | ok | poor≥cit≥rich | PASS |
| Za_G0_A250 | ok | poor≥cit≥rich | PASS |
| Za_G1_A0 | ok | poor≥cit≥rich | PASS |
| Za_G1_A250 | ok | poor≥cit≥rich | PASS |
| Za_G2_A0 | ok | poor≥cit≥rich | PASS |
| Za_G2_A250 | ok | poor≥cit≥rich | PASS |
| Zb_G0_notrader | ok | poor≥cit≥rich | PASS |
| Zc_G0H_A0 | ok | poor≥cit≥rich | PASS |
| Zd_G0_seed2 | ok | poor≥cit≥rich | PASS |

## ④ City cash not monotonically rising

| Group | status | mono_ports | ports | pass |
|-------|--------|------------|-------|------|
| Za_G0_A0 | ok | 4 | 16 | PASS |
| Za_G0_A250 | ok | 4 | 16 | PASS |
| Za_G1_A0 | ok | 4 | 16 | PASS |
| Za_G1_A250 | ok | 4 | 16 | PASS |
| Za_G2_A0 | ok | 4 | 16 | PASS |
| Za_G2_A250 | ok | 4 | 16 | PASS |
| Zb_G0_notrader | ok | 4 | 16 | PASS |
| Zc_G0H_A0 | ok | 4 | 16 | PASS |
| Zd_G0_seed2 | ok | 4 | 16 | PASS |

## ⑤ Timing / traders / abort

| Group | status | duration_s | aborted | abort_reason | sail_sum |
|-------|--------|------------|---------|--------------|----------|
| Za_G0_A0 | ok | 3883 | 0 |  | 0 |
| Za_G0_A250 | ok | 3357 | 0 |  | 0 |
| Za_G1_A0 | ok | 3367 | 0 |  | 0 |
| Za_G1_A250 | ok | 4488 | 0 |  | 0 |
| Za_G2_A0 | ok | 4946 | 0 |  | 0 |
| Za_G2_A250 | ok | 4932 | 0 |  | 0 |
| Zb_G0_notrader | ok | 266 | 0 |  | 0 |
| Zc_G0H_A0 | ok | 4940 | 0 |  | 0 |
| Zd_G0_seed2 | ok | 2981 | 0 |  | 0 |

