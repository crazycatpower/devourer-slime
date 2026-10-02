# Locates the Godot console executable and runs it against this project.
#
#   tools\godot.ps1 --headless --import          import assets / rebuild the class cache
#   tools\godot.ps1 --headless -s res://tests/run_tests.gd
#   tools\godot.ps1 -e                           open the editor
#
# Set the GODOT environment variable to override the executable.

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

& (Find-Godot) --path $projectDir @args
exit $LASTEXITCODE
