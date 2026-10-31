param([string]$GodotExe = (Join-Path $env:USERPROFILE 'DevTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'))
$ErrorActionPreference = 'Stop'
$brandingRoot = $PSScriptRoot
if ($env:SOMNICARD_GODOT) { $GodotExe = $env:SOMNICARD_GODOT }
if (-not (Test-Path -LiteralPath $GodotExe)) { throw 'Godot executable not found. Supply -GodotExe or SOMNICARD_GODOT.' }
& python (Join-Path $brandingRoot 'build_assets.py') $brandingRoot
if ($LASTEXITCODE -ne 0) { throw 'SVG generation failed.' }
$toolRoot = Join-Path $brandingRoot 'tools'
& $GodotExe --headless --path $toolRoot --script (Join-Path $brandingRoot 'export-assets.gd') --log-file (Join-Path $toolRoot 'export.log') -- $brandingRoot
if ($LASTEXITCODE -ne 0) { throw 'PNG export failed.' }
& $GodotExe --headless --path $toolRoot --script (Join-Path $toolRoot 'render-previews.gd') --log-file (Join-Path $toolRoot 'previews.log') -- $brandingRoot
if ($LASTEXITCODE -ne 0) { throw 'Preview render failed.' }
Write-Output "Exported SVG and PNG assets to $brandingRoot"
