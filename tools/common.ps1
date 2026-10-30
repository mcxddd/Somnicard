$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GodotExe = Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if ($env:SOMNICARD_GODOT) { $GodotExe = $env:SOMNICARD_GODOT }
if (-not (Test-Path -LiteralPath $GodotExe)) { throw 'Godot 4.7.2 not found. Set SOMNICARD_GODOT to the console executable path.' }

