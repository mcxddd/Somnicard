# -Portrait is kept as a compatibility alias; all launches now use portrait.
param([switch]$Editor, [switch]$Portrait)
. "$PSScriptRoot\common.ps1"
if ($Editor) { & $GodotExe --path $ProjectRoot --editor }
else { & $GodotExe --path $ProjectRoot }
if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }

