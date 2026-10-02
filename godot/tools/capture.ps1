# Saves a screenshot of every screen to tests\output\, for reviewing the
# game's look without playing through it. Opens a real game window for about
# half a minute. Runs sandboxed, so real saves are left alone.
#
#   tools\capture.ps1

$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot

$godot = $env:GODOT
if (-not $godot -or -not (Test-Path $godot)) {
    $godot = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Directory -Filter 'GodotEngine.GodotEngine*' |
        ForEach-Object { Get-ChildItem $_.FullName -Filter 'Godot_v*_console.exe' } |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godot) { throw 'Godot was not found. Set $env:GODOT to its executable.' }

$outFile = [IO.Path]::GetTempFileName()
$errFile = [IO.Path]::GetTempFileName()
$arguments = @(
    '--path', "`"$projectDir`"", '--resolution', '1280x720',
    '-s', 'res://tools/capture/capture_screens.gd', '++', '--sandbox'
)
$process = Start-Process -FilePath $godot -ArgumentList $arguments -NoNewWindow -PassThru `
    -RedirectStandardOutput $outFile -RedirectStandardError $errFile
if (-not $process.WaitForExit(180000)) {
    # Stop only the run this script started.
    & taskkill /PID $process.Id /T /F *> $null
    Write-Host 'TIMEOUT' -ForegroundColor Red
}
Get-Content $outFile, $errFile | Where-Object {
    $_ -and $_ -notmatch '^(Godot Engine|OpenGL API)' -and $_ -notmatch 'low quality OpenGL|display_server_windows'
} | ForEach-Object { Write-Host $_ }
Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
