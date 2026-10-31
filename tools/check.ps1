. "$PSScriptRoot\common.ps1"
function Invoke-GodotCheck([string[]]$GodotArgs, [string]$Marker = '') {
    $output = & $GodotExe @GodotArgs 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    Write-Output $output
    if ($exitCode -ne 0 -or $output -match '(?m)SCRIPT ERROR:|ERROR:|FAIL:|UI_SMOKE_FAILED') {
        throw 'Godot check failed; see output above.'
    }
    if ($Marker -and -not $output.Contains($Marker)) { throw "Missing completion marker: $Marker" }
}
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--editor', '--import')
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/poker_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/ui_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/multiplayer_ui_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/review_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/strategy_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/experience_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/portrait_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/feedback_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/table_presence_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/teaching_history_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/training_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/opponents_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/range_touch_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/navigation_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/river_extension_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/version111_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/version112_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/version113_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/product_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/system_audit_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--script', 'tests/stateful_stress_test.gd') '0 failures'
Invoke-GodotCheck @('--headless', '--path', $ProjectRoot, '--quit-after', '300', '--', '--smoke-test') 'UI_SMOKE_OK'

