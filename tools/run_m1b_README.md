# run_m1b.ps1 — Owner-local M1b runner (17-59 Lane H / 17-64 T1–T5)

Windows PowerShell **5.1**. No extra modules. Always launches Godot with **`--inline`** so season progress prints in your console (17-60 W4).

## Godot 4.7.2

Download the Windows zip from Godot 4.7.2-stable. Extract so the **console** binary sits beside the normal exe:

- `Godot_v4.7.2-stable_win64.exe`
- `Godot_v4.7.2-stable_win64_console.exe` ← **use this** (`-GodotPath` must contain `console`)

Owner paths used in examples below:

- Godot: `C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe`
- Repo: `C:\Users\user\Documents\GitHub\Project-Patrician`

After checkout, run once so gut `.import` matches 4.7.2 (17-64 T1); tree must stay clean:

```powershell
& "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
git status --porcelain
```

## Pasteable commands

```powershell
cd C:\Users\user\Documents\GitHub\Project-Patrician

# Smoke one group (30 days → out\m1b_smoke\)
# 17-64 T2: SmokeDays < 1 season (90d) is OK — report samples last season
# row when present, else metrics are N/A (never fake PASS/FAIL).
.\tools\run_m1b.ps1 `
  -GodotPath "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" `
  -Group Za_G0_A0 `
  -SmokeDays 30

# Min 1 season smoke (explicit)
.\tools\run_m1b.ps1 `
  -GodotPath "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" `
  -Group Za_G0_A0 `
  -SmokeDays 90

# All nine groups (5y; out\m1b\)
.\tools\run_m1b.ps1 `
  -GodotPath "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" `
  -Group all

# Resume after Ctrl+C (skips groups with done.txt)
.\tools\run_m1b.ps1 `
  -GodotPath "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" `
  -Group all `
  -Resume

# Rebuild report.md only
.\tools\run_m1b.ps1 `
  -GodotPath "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" `
  -ReportOnly
```

Fixed group names: `Za_G0_A0`, `Za_G0_A250`, `Za_G1_A0`, `Za_G1_A250`, `Za_G2_A0`, `Za_G2_A250`, `Zb_G0_notrader`, `Zc_G0H_A0`, `Zd_G0_seed2`.

## Progress watch

While a run is going (another window). **17-64 T5:** PS 5.1 needs UTF-8 when the log may contain non-ASCII:

```powershell
Get-Content .\out\m1b\progress.log -Wait -Tail 20 -Encoding UTF8
```

Each season line (also printed live; ASCII for PS 5.1):

`PROGRESS pct=<job%> all_pct=<%> group=<i>/<n> <name> y=<y> q=<q> elapsed=<h:mm> eta=<h:mm> pop=<n> sails_cum=<n>`

`pop=<n>` is **live population at emit** (17-64 T4; report prefers this over season-sample sums).  
`Write-Progress` shows two bars: all groups (i/9) and current group %.  
`tools/*.ps1` must stay pure ASCII (CI gate).

## Report N/A (17-64 T3)

`tools/run_m1b_report.gd` writes `N/A` for class/band/tier/cash when a group has no season data (short smoke, missing CSV). It never invents PASS/FAIL for empty inputs. Missing groups stay `未跑`.

## ETA / interrupt

From 17-55 timing, ~37–40 s per sim-year per combo on the reference machine; 5y × 1 combo ≈ 3–4 min/group (traders on a bit higher). Ctrl+C, then `-Resume`.

## Zip-back

After a full pack, zip `out\m1b\` (keep under 150 MB; if over, keep per group `summary.csv`, `season_ports.csv`, `trader_summary.csv`, `timing.txt`, `commit_sha.txt`, `done.txt` + md5 of the rest).

## 17-60 Owner Windows verify (Guild T5)

1. Console Godot path as above; clean `git status`.
2. Smoke with parent+inline (script always passes `--inline`):

```powershell
.\tools\run_m1b.ps1 -GodotPath "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" -Group Za_G0_A0 -SmokeDays 30
```

3. Confirm CSVs under `out\m1b_smoke\Za_G0_A0\` and `progress.log` season lines (read with `Get-Content -Encoding UTF8`).
4. Optional subprocess cmp (Linux CI `m1b-w4-inline-cmp` job) — Owner: status **待 Owner 驗證** until you confirm Guild T5.
