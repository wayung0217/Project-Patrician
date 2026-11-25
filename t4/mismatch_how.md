# T4 故意不符 — 如何觸發（未推紅 tip）

本地（不進 CI tip）：
1. 以 `.github/ci/golden_30d_bootstrap_1764.csv` 為 A
2. 複製為 B，改一列 `note` 欄（例 day=0 那列）附加 `_T4_MISMATCH`
3. `python3 tools/golden_compare.py A B`

預期輸出要點：
- COMPARED_ROWS=527 COMPARED_COLS=19 COMPARED_CELLS=10013（網格完整，閘門通過）
- IDENTICAL=0；DIFF_CELLS≥1（compare 退出碼 1 → CI golden 步驟仍會 fail）
- 見 `compared_mismatch.out`

通過樣本見 `compared_pass.out`（IDENTICAL=1 DIFF 隱含 0）。
