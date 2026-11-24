# run_m1b.ps1 — Owner-local M1b runner (17-59 Lane H)

Windows PowerShell **5.1**. No extra modules. Always launches Godot with **`--inline`** so season progress prints in your console (17-60 W4).

## Godot 4.7.2

Download the Windows zip from Godot 4.7.2-stable. Extract so the **console** binary sits beside the normal exe:

- `Godot_v4.7.2-stable_win64.exe`
- `Godot_v4.7.2-stable_win64_console.exe` ← **use this** (`-GodotPath` must contain `console`)

Owner paths used in examples below:

- Godot: `C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe`
- Repo: `C:\Users\user\Documents\GitHub\Project-Patrician`

## Pasteable commands

```powershell
cd C:\Users\user\Documents\GitHub\Project-Patrician

# Smoke one group (30 days → out\m1b_smoke\)
.\tools\run_m1b.ps1 `
  -GodotPath "C:\Users\user\Desktop\Godot_v4.7.2-stable_win64_console.exe" `
  -Group Za_G0_A0 `
  -SmokeDays 30

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

While a run is going (another window):

```powershell
Get-Content .\out\m1b\progress.log -Wait -Tail 20
```

Each season line (also printed live):

`時間｜組 i／9 組名｜第 y 年第 q 季｜本組 xx%｜全部 xx%｜已用 h:mm｜預估剩 h:mm｜人口｜散商出航累計`

`Write-Progress` shows two bars: all groups (i/9) and current group %.

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

3. Confirm CSVs under `out\m1b_smoke\Za_G0_A0\` and `progress.log` season lines.
4. Optional subprocess cmp (Linux CI `m1b-w4-inline-cmp` job) — Owner: status **待 Owner 驗證** until you confirm Guild T5.
