. "$PSScriptRoot\common.ps1"
python "$PSScriptRoot\prepare-android.py"
if ($LASTEXITCODE -ne 0) { throw 'Android template setup failed' }
$outputDir = Join-Path $ProjectRoot 'builds\android'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
python "$PSScriptRoot\export-android.py" "$GodotExe" "$outputDir\somnicard-debug.apk"
if ($LASTEXITCODE -ne 0) { throw 'Android export failed' }
Get-Item -LiteralPath "$outputDir\somnicard-debug.apk" | Select-Object FullName,Length,LastWriteTime

