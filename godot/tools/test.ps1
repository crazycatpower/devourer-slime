# Runs the project's automated checks headlessly.
#
#   tools\test.ps1              everything: compile check, unit + parity tests, smoke test
#   tools\test.ps1 unit         only test files whose path contains "unit" (no smoke test)
#   tools\test.ps1 -Smoke       only the end-to-end smoke test
#
# The import step first refreshes Godot's class cache, so newly added
# `class_name` scripts are visible. The smoke test runs with `--sandbox`, which
# keeps it away from real save files. Each Godot run has a time limit and only
# the process this script started is ever stopped.

param(
    [string]$Filter = '',
    [switch]$Smoke
)

$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot

function Find-Godot {
    if ($env:GODOT -and (Test-Path $env:GODOT)) { return $env:GODOT }
    $onPath = Get-Command godot_console, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { return $onPath.Source }
    $wingetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path $wingetRoot) {
        $exe = Get-ChildItem $wingetRoot -Directory -Filter 'GodotEngine.GodotEngine*' |
            ForEach-Object { Get-ChildItem $_.FullName -Filter 'Godot_v*_console.exe' } |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($exe) { return $exe.FullName }
    }
    throw 'Godot was not found. Install it (winget install GodotEngine.GodotEngine) or set $env:GODOT.'
}

$godot = Find-Godot

# Runs Godot with a time limit. Returns its output lines; sets $script:lastExit.
function Invoke-Godot([string[]]$GodotArgs, [int]$TimeoutSec) {
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    try {
        $allArgs = @('--path', "`"$projectDir`"") + $GodotArgs
        $process = Start-Process -FilePath $godot -ArgumentList $allArgs -NoNewWindow -PassThru `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        if (-not $process.WaitForExit($TimeoutSec * 1000)) {
            # Stop this run and the engine process it spawned, nothing else.
            & taskkill /PID $process.Id /T /F *> $null
            $script:lastExit = 124
            return @(Get-Content $outFile) + @(Get-Content $errFile) + "TIMEOUT after $TimeoutSec s"
        }
        $process.WaitForExit()
        $script:lastExit = $process.ExitCode
        return @(Get-Content $outFile) + @(Get-Content $errFile)
    } finally {
        Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
    }
}

$failed = $false

function Invoke-Step([string]$Name, [string[]]$GodotArgs, [int]$TimeoutSec) {
    Write-Host "== $Name"
    $output = Invoke-Godot $GodotArgs $TimeoutSec
    # Engine and script errors count as failures even when the exit code is 0.
    $errors = @($output | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR|WARNING):' -or $_ -match '^TIMEOUT' })
    $output | Where-Object { $_ -and $_ -notmatch '^Godot Engine v' } | ForEach-Object { Write-Host $_ }
    if ($script:lastExit -ne 0 -or $errors.Count -gt 0) {
        Write-Host "-- $Name FAILED (exit $($script:lastExit), $($errors.Count) error lines)" -ForegroundColor Red
        $script:failed = $true
    } else {
        Write-Host "-- $Name passed" -ForegroundColor Green
    }
}

Invoke-Godot @('--headless', '--import') 180 | Where-Object { $_ -match '^(SCRIPT ERROR|ERROR):' } | ForEach-Object { Write-Host $_ }

if (-not $Smoke) {
    if (-not $Filter) {
        Invoke-Step 'compile check' @('--headless', '-s', 'res://tools/check_scripts.gd') 180
    }
    $testArgs = @('--headless', '-s', 'res://tests/run_tests.gd')
    if ($Filter) { $testArgs += @('++', $Filter) }
    Invoke-Step 'unit and parity tests' $testArgs 600
}
if ($Smoke -or -not $Filter) {
    Invoke-Step 'smoke test' @('--headless', '-s', 'res://tests/smoke/smoke_test.gd', '++', '--sandbox') 300
}

if ($failed) { Write-Host 'FAILED' -ForegroundColor Red; exit 1 }
Write-Host 'ALL PASSED' -ForegroundColor Green
exit 0
