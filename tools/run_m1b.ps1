#Requires -Version 5.1
<#
.SYNOPSIS
  Owner-local M1b multi-year runner (17-59 Lane H). Always uses sim_runner --inline.

.PARAMETER GodotPath
  Full path to Godot *console* exe (required; never hardcoded).

.PARAMETER Group
  "all" or comma list of fixed group names (default all).

.PARAMETER Resume
  Skip groups that already have out\m1b\<name>\done.txt.

.PARAMETER SmokeDays
  Trial day count → out\m1b_smoke\ only (sets --days).

.PARAMETER ReportOnly
  Only run tools/run_m1b_report.gd against existing out\m1b\.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$GodotPath,

  [Parameter(Mandatory = $false)]
  [string]$Group = "all",

  [Parameter(Mandatory = $false)]
  [switch]$Resume,

  [Parameter(Mandatory = $false)]
  [int]$SmokeDays = 0,

  [Parameter(Mandatory = $false)]
  [switch]$ReportOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

$AllGroups = @(
  "Za_G0_A0",
  "Za_G0_A250",
  "Za_G1_A0",
  "Za_G1_A250",
  "Za_G2_A0",
  "Za_G2_A250",
  "Zb_G0_notrader",
  "Zc_G0H_A0",
  "Zd_G0_seed2"
)

function Fail([string]$Reason) {
  Write-Host "run_m1b STOP: $Reason" -ForegroundColor Red
  exit 1
}

# --- Preflight ---
if (-not (Test-Path -LiteralPath $GodotPath)) {
  Fail "GodotPath does not exist: $GodotPath"
}
$godotLeaf = [System.IO.Path]::GetFileName($GodotPath)
if ($godotLeaf -notmatch "console") {
  Fail "GodotPath filename must contain 'console' (got '$godotLeaf')"
}

$gitStatus = & git status --porcelain 2>&1
if ($LASTEXITCODE -ne 0) {
  Fail "git status failed: $gitStatus"
}
if ($gitStatus) {
  Fail "git working tree not clean:`n$gitStatus"
}
$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
$sha = (& git rev-parse HEAD).Trim()
Write-Host "run_m1b branch=$branch sha=$sha"

if ($ReportOnly) {
  $reportOut = if ($SmokeDays -gt 0) { "out\m1b_smoke" } else { "out\m1b" }
  & $GodotPath --headless --path $RepoRoot -s res://tools/run_m1b_report.gd -- --in $reportOut
  exit $LASTEXITCODE
}

$selected = @()
if ($Group -eq "all") {
  $selected = $AllGroups
} else {
  foreach ($g in ($Group -split ",")) {
    $name = $g.Trim()
    if (-not $name) { continue }
    if ($AllGroups -notcontains $name) {
      Fail "Unknown group '$name'. Allowed: $($AllGroups -join ', ')"
    }
    $selected += $name
  }
}
if ($selected.Count -eq 0) {
  Fail "No groups selected"
}

$outRoot = if ($SmokeDays -gt 0) { Join-Path $RepoRoot "out\m1b_smoke" } else { Join-Path $RepoRoot "out\m1b" }
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$progressLog = Join-Path $outRoot "progress.log"
$workScenDir = Join-Path $outRoot "_scenarios"
New-Item -ItemType Directory -Force -Path $workScenDir | Out-Null

function Get-GroupSpec([string]$Name) {
  switch ($Name) {
    "Za_G0_A0" { return @{ Scenario = "docs/spec/scenario_M1b_G0.json"; Abund = 0; Traders = $true; Seed = 1; Housing = $false } }
    "Za_G0_A250" { return @{ Scenario = "docs/spec/scenario_M1b_G0.json"; Abund = 250000; Traders = $true; Seed = 1; Housing = $false } }
    "Za_G1_A0" { return @{ Scenario = "docs/spec/scenario_M1b_G1.json"; Abund = 0; Traders = $true; Seed = 1; Housing = $false } }
    "Za_G1_A250" { return @{ Scenario = "docs/spec/scenario_M1b_G1.json"; Abund = 250000; Traders = $true; Seed = 1; Housing = $false } }
    "Za_G2_A0" { return @{ Scenario = "docs/spec/scenario_M1b_G2.json"; Abund = 0; Traders = $true; Seed = 1; Housing = $false } }
    "Za_G2_A250" { return @{ Scenario = "docs/spec/scenario_M1b_G2.json"; Abund = 250000; Traders = $true; Seed = 1; Housing = $false } }
    "Zb_G0_notrader" { return @{ Scenario = "docs/spec/scenario_M1b_G0.json"; Abund = 0; Traders = $false; Seed = 1; Housing = $false } }
    "Zc_G0H_A0" { return @{ Scenario = "docs/spec/scenario_M1b_G0H.json"; Abund = 0; Traders = $true; Seed = 1; Housing = $true } }
    "Zd_G0_seed2" { return @{ Scenario = "docs/spec/scenario_M1b_G0.json"; Abund = 0; Traders = $true; Seed = 2; Housing = $false } }
    default { Fail "internal: bad group $Name" }
  }
}

function Write-PreparedScenario([string]$Name, $Spec) {
  $srcPath = Join-Path $RepoRoot $Spec.Scenario
  if (-not (Test-Path -LiteralPath $srcPath)) {
    Fail "scenario missing: $srcPath"
  }
  $raw = Get-Content -LiteralPath $srcPath -Raw -Encoding UTF8
  $obj = $raw | ConvertFrom-Json
  # Strip ABUND from overrides when also in grid (ERR-SYS23-04 / G-INT-03).
  if ($null -ne $obj.overrides -and $obj.overrides.PSObject.Properties.Name -contains "PRM-SYS07-ABUND_BONUS_MAX_PPM") {
    $obj.overrides.PSObject.Properties.Remove("PRM-SYS07-ABUND_BONUS_MAX_PPM")
  }
  $obj.grid = @{ "PRM-SYS07-ABUND_BONUS_MAX_PPM" = @([int]$Spec.Abund) }
  $obj.seeds = @([int]$Spec.Seed)
  if ($null -eq $obj.layers) { $obj | Add-Member -NotePropertyName layers -NotePropertyValue (@{}) }
  $obj.layers.TRADERS = [bool]$Spec.Traders
  $obj.layers.CITY_HOUSING = [bool]$Spec.Housing
  $obj.scenario_id = $Name
  $dest = Join-Path $workScenDir ("{0}.json" -f $Name)
  ($obj | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath $dest -Encoding UTF8
  return $dest
}

function Append-Progress([string]$Line) {
  Add-Content -LiteralPath $progressLog -Value $Line -Encoding UTF8
  Write-Host $Line
}

$failures = New-Object System.Collections.Generic.List[string]
$packStart = Get-Date
$totalN = $selected.Count
$idx = 0

foreach ($gName in $selected) {
  $idx++
  $groupDir = Join-Path $outRoot $gName
  $doneFile = Join-Path $groupDir "done.txt"
  if ($Resume -and (Test-Path -LiteralPath $doneFile)) {
    Write-Host "RESUME skip $gName (done.txt present)"
    continue
  }

  Write-Progress -Id 1 -Activity "M1b groups" -Status ("{0}/{1} {2}" -f $idx, $totalN, $gName) -PercentComplete ([int](100 * ($idx - 1) / $totalN))
  New-Item -ItemType Directory -Force -Path $groupDir | Out-Null
  $spec = Get-GroupSpec $gName
  $scen = Write-PreparedScenario $gName $spec
  $env:M1B_GROUP_I = "$idx"
  $env:M1B_GROUP_N = "$totalN"
  $env:M1B_GROUP_NAME = $gName
  $env:M1B_ALL_PCT = ("{0:0}" -f (100.0 * ($idx - 1) / [Math]::Max($totalN, 1)))

  $args = @(
    "--headless",
    "--path", $RepoRoot,
    "-s", "res://sim/sim_runner.gd",
    "--",
    "--scenario", $scen,
    "--inline",
    "--season-progress",
    "--out-dir", $groupDir
  )
  if ($SmokeDays -gt 0) {
    $args += @("--days", "$SmokeDays")
  }

  $gStart = Get-Date
  $timingPath = Join-Path $groupDir "timing.txt"
  $shaPath = Join-Path $groupDir "commit_sha.txt"
  Set-Content -LiteralPath $shaPath -Value $sha -Encoding UTF8
  $logPath = Join-Path $groupDir "sim_runner.log"
  Write-Host ("START {0} at {1:o}" -f $gName, $gStart)
  Write-Progress -Id 2 -Activity $gName -Status "running (inline)" -PercentComplete 0

  $ok = $false
  try {
    & $GodotPath @args 2>&1 | Tee-Object -FilePath $logPath | ForEach-Object {
      $line = "$_"
      if ($line -match "第 .+ 年第 .+ 季") {
        Append-Progress $line
        # Rough % from 本組 token when present.
        if ($line -match "本組\s+(\d+)%") {
          $pct = [int]$Matches[1]
          $elapsed = (Get-Date) - $gStart
          $eta = if ($pct -gt 0) { [TimeSpan]::FromSeconds($elapsed.TotalSeconds * (100 - $pct) / $pct) } else { [TimeSpan]::Zero }
          Write-Progress -Id 2 -Activity $gName -Status ("days progress {0}% elapsed={1:hh\:mm\:ss} ETA={2:hh\:mm\:ss}" -f $pct, $elapsed, $eta) -PercentComplete ([Math]::Min(99, $pct))
        }
      } else {
        Write-Host $line
      }
    }
    if ($LASTEXITCODE -eq 0) {
      $ok = $true
      Set-Content -LiteralPath $doneFile -Value ("ok {0:o}" -f (Get-Date)) -Encoding UTF8
    }
  } catch {
    Write-Host "EXCEPTION $gName : $_" -ForegroundColor Red
    Add-Content -LiteralPath $logPath -Value "EXCEPTION: $_"
  }

  $gEnd = Get-Date
  $dur = $gEnd - $gStart
  $status = if ($ok) { "ok" } else { "fail" }
  $summaryLine = ("END {0} status={1} duration={2:hh\:mm\:ss} sha={3}" -f $gName, $status, $dur, $sha)
  Set-Content -LiteralPath $timingPath -Value @(
    "commit_sha=$sha",
    ("start={0:o}" -f $gStart),
    ("end={0:o}" -f $gEnd),
    ("duration_s={0:N3}" -f $dur.TotalSeconds),
    "status=$status"
  ) -Encoding UTF8
  Append-Progress $summaryLine
  Write-Progress -Id 2 -Activity $gName -Completed
  if (-not $ok) {
    $failures.Add($gName) | Out-Null
    Write-Host "FAIL $gName (continuing)" -ForegroundColor Yellow
  }
}

Write-Progress -Id 1 -Activity "M1b groups" -Completed
$packEnd = Get-Date
Write-Host ("PACK done elapsed={0:hh\:mm\:ss} failures={1}" -f ($packEnd - $packStart), ($failures -join ","))
if ($failures.Count -gt 0) {
  Write-Host "FAILURE LIST: $($failures -join ', ')" -ForegroundColor Red
  # Still emit report for completed groups.
}
& $GodotPath --headless --path $RepoRoot -s res://tools/run_m1b_report.gd -- --in $outRoot
if ($failures.Count -gt 0) {
  exit 1
}
exit 0
