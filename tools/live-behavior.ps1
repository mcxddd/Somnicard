# Interactive, one-use credential entry. No key file, shell argument or clipboard reads.
. "$PSScriptRoot\common.ps1"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = 'Somnicard - CommandCode test'
$form.Size = New-Object Drawing.Size(570, 365)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.TopMost = $true
$note = New-Object Windows.Forms.Label
$note.Location = New-Object Drawing.Point(20, 18)
$note.Size = New-Object Drawing.Size(520, 82)
$note.Text = "CommandCode live opponent test (up to 20 requests, may incur charges).`r`nUse the exact model ID selected in your game.`r`nKey stays in process memory; reports contain synthetic games only.`r`nEndpoint: https://api.commandcode.ai/provider/v1"
$form.Controls.Add($note)
$keyLabel = New-Object Windows.Forms.Label
$keyLabel.Text = 'API Key'
$keyLabel.Location = New-Object Drawing.Point(20, 112)
$form.Controls.Add($keyLabel)
$keyBox = New-Object Windows.Forms.TextBox
$keyBox.Location = New-Object Drawing.Point(120, 108)
$keyBox.Size = New-Object Drawing.Size(410, 28)
$keyBox.UseSystemPasswordChar = $true
$form.Controls.Add($keyBox)
$modelLabel = New-Object Windows.Forms.Label
$modelLabel.Text = 'Model ID'
$modelLabel.Location = New-Object Drawing.Point(20, 158)
$form.Controls.Add($modelLabel)
$modelBox = New-Object Windows.Forms.TextBox
$modelBox.Location = New-Object Drawing.Point(120, 154)
$modelBox.Size = New-Object Drawing.Size(410, 28)
$form.Controls.Add($modelBox)
$start = New-Object Windows.Forms.Button
$start.Text = 'Start test (max 20 requests)'
$start.Location = New-Object Drawing.Point(120, 220)
$start.Size = New-Object Drawing.Size(280, 40)
$start.Add_Click({
    if ([string]::IsNullOrWhiteSpace($keyBox.Text) -or [string]::IsNullOrWhiteSpace($modelBox.Text)) {
        [void][Windows.Forms.MessageBox]::Show('Enter both API Key and Model ID.')
        return
    }
    $form.DialogResult = [Windows.Forms.DialogResult]::OK
    $form.Close()
})
$form.Controls.Add($start)
if ($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $form.Dispose(); exit }
$info = New-Object Diagnostics.ProcessStartInfo
$info.FileName = $GodotExe
$info.Arguments = '--headless --path "' + $ProjectRoot + '" --script tools/benchmarks/live_behavior.gd'
$info.WorkingDirectory = $ProjectRoot
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.EnvironmentVariables['SOMNICARD_TEST_KEY'] = $keyBox.Text.Trim()
$info.EnvironmentVariables['SOMNICARD_TEST_MODEL'] = $modelBox.Text.Trim()
$keyBox.Clear()
$form.Dispose()
try {
    $process = [Diagnostics.Process]::Start($info)
    $info.EnvironmentVariables.Remove('SOMNICARD_TEST_KEY')
    $process.WaitForExit()
} finally {
    $info.EnvironmentVariables.Remove('SOMNICARD_TEST_KEY')
}
