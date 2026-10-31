. "$PSScriptRoot\common.ps1"
function Invoke-GodotCheck([string[]]$GodotArgs, [string]$Marker = '') {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $GodotExe @GodotArgs 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    Write-Output $output
    if ($exitCode -ne 0 -or $output -match '(?m)SCRIPT ERROR:|ERROR:|FAIL:|UI_SMOKE_FAILED') {
        throw 'Godot check failed; see output above.'
    }
    if ($Marker -and -not $output.Contains($Marker)) { throw "Missing completion marker: $Marker" }
}
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--editor', '--import')
$tests = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'tests') -Filter '*_test.gd' -File | Sort-Object Name)
if ($tests.Count -eq 0) { throw 'No *_test.gd suites found.' }
foreach ($test in $tests) {
    Write-Output $test.Name
    Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', ("tests/" + $test.Name)) '0 failures'
}
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--quit-after', '300', '--', '--smoke-test') 'UI_SMOKE_OK'
