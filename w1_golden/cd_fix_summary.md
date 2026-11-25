# W1(c)/(d) 修正（tip 19d1a4e）

## (c) S9b bootstrap
- 提交 `.github/ci/golden_30d_bootstrap_1764.csv`（sha256 `8b25c951…`）
- PR 無可用 main `golden-30d` artifact 時：複製 bootstrap → 比對 → 輸出 `GOLDEN_BOOTSTRAP=1` 與 `DIFF_CELLS`
- main 有未過期 artifact → `GOLDEN_BOOTSTRAP=0`，不走 bootstrap

## (d) 下載邏輯
- 舊：只取 `conclusion==success` 的 main run → 落到 45358265237（無 golden）
- 新：`actions/artifacts?name=golden-30d` 篩 `head_branch==main` 且 `expired==false` 最新一筆
- 可下載 cancelled-but-uploaded 的 main artifact（例：id **14932606115** / run 45415084221）
- main workflow 已含 `golden-30d` 且 `upload if: always()` + `retention-days: 14`；本 PR 不需再改上傳條件
