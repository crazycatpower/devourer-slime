param([switch]$PackOnly)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectDir 'build'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$mode = if ($PackOnly) { '--export-pack' } else { '--export-release' }
$output = if ($PackOnly) { 'build/devourer-slime.pck' } else { 'build/devourer-slime.exe' }
& (Join-Path $PSScriptRoot 'godot.ps1') --headless $mode 'Windows Desktop' $output
if ($LASTEXITCODE -ne 0) { throw "Godot export failed ($LASTEXITCODE). A Windows release requires matching Godot export templates." }
