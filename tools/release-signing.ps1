param(
    [Parameter(Mandatory=$true)][ValidateSet('Create','Build')][string]$Action
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"
$signingDirectory = Join-Path $env:LOCALAPPDATA 'Somnicard/signing'
$keyFile = Join-Path $signingDirectory 'somnicard-release.p12'
$passwordFile = Join-Path $signingDirectory 'password.dpapi'
$javaBin = Join-Path $env:LOCALAPPDATA 'Programs/Java/jdk-21.0.12.1+1/bin'
$keytool = Join-Path $javaBin 'keytool.exe'
if (-not (Test-Path -LiteralPath $keytool)) { throw 'Pinned JDK keytool not found.' }
if ($Action -eq 'Create') {
    if ((Test-Path -LiteralPath $keyFile) -or (Test-Path -LiteralPath $passwordFile)) { throw 'Signing material already exists. It must never be overwritten.' }
    New-Item -ItemType Directory -Force -Path $signingDirectory | Out-Null
    $principalSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $signingDirectory /inheritance:r /grant:r "*${principalSid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not restrict signing directory permissions.' }
    $randomBytes = New-Object byte[] 32
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $generator.GetBytes($randomBytes) } finally { $generator.Dispose() }
    $privatePassword = [Convert]::ToBase64String($randomBytes)
    $privatePassword | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -LiteralPath $passwordFile -Encoding ASCII
    $env:SOMNICARD_SIGNING_PASSWORD = $privatePassword
    try {
        & $keytool -genkeypair -noprompt -storetype PKCS12 -keystore $keyFile -alias somnicard -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Somnicard Release' -storepass:env SOMNICARD_SIGNING_PASSWORD -keypass:env SOMNICARD_SIGNING_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'Signing key generation failed; inspect the protected directory before retrying.' }
    } finally {
        Remove-Item Env:SOMNICARD_SIGNING_PASSWORD -ErrorAction SilentlyContinue
        $privatePassword = $null
        [Array]::Clear($randomBytes, 0, $randomBytes.Length)
    }
    Write-Output "Dedicated signing material created in $signingDirectory. Preserve both files and arrange a portable recovery backup before replacing this Windows account."
    exit
}
if (-not (Test-Path -LiteralPath $keyFile) -or -not (Test-Path -LiteralPath $passwordFile)) { throw 'Dedicated signing material has not been created.' }
$protectedPassword = (Get-Content -LiteralPath $passwordFile -Raw).Trim() | ConvertTo-SecureString
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keyFile
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'somnicard'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [System.Net.NetworkCredential]::new('', $protectedPassword).Password
$previousJavaHome = $env:JAVA_HOME
try {
    $env:JAVA_HOME = Split-Path -Parent $javaBin
    python "$PSScriptRoot/build-release.py" --identity standalone --engine $GodotExe
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
} finally {
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    $env:JAVA_HOME = $previousJavaHome
    $protectedPassword.Dispose()
}
