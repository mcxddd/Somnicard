param(
	[Parameter(Mandatory=$true)][ValidateSet('Build','Github')][string]$Stage,
	[string]$Version
)
. "$PSScriptRoot/common.ps1"
$preset = Get-Content -LiteralPath (Join-Path $ProjectRoot 'export_presets.cfg') -Raw
$versionMatch = [regex]::Match($preset, '(?m)^version/name="([\d.]+)"\r?$')
if (-not $versionMatch.Success) { throw 'Export version/name not found.' }
$exportVersion = $versionMatch.Groups[1].Value
if (-not $Version) { $Version = $exportVersion }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must use major.minor.patch.' }
$apk = Join-Path $ProjectRoot "builds/android/somnicard-$Version-release.apk"
$checksumFile = "$apk.sha256"

if ($Stage -eq 'Build') {
	$project = Get-Content -LiteralPath (Join-Path $ProjectRoot 'project.godot') -Raw
	$projectVersion = [regex]::Match($project, '(?m)^config/version="([\d.]+)"\r?$').Groups[1].Value
	if ($Version -ne $exportVersion -or $Version -ne $projectVersion) { throw 'Build version must match project.godot and export_presets.cfg.' }
	& "$PSScriptRoot/check.ps1"
	if ($LASTEXITCODE -ne 0) { throw 'Project checks failed.' }
	& "$PSScriptRoot/release-signing.ps1" -Action Build
	if ($LASTEXITCODE -ne 0) { throw 'Signed release build failed.' }
	$buildTools = Join-Path $env:USERPROFILE 'DevTools/Android/Sdk/build-tools/36.0.0'
	$previousJavaHome = $env:JAVA_HOME
	try {
		$env:JAVA_HOME = Join-Path $env:LOCALAPPDATA 'Programs/Java/jdk-21.0.12.1+1'
		$signature = & (Join-Path $buildTools 'apksigner.bat') verify --verbose --print-certs $apk
		if ($LASTEXITCODE -ne 0) { throw 'APK signature inspection failed.' }
		$certificateMatch = [regex]::Match(($signature -join "`n"), 'Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]{64})')
		if (-not $certificateMatch.Success) { throw 'APK signing certificate SHA-256 not found.' }
		$certificate = $certificateMatch.Groups[1].Value.ToLowerInvariant()
		Write-Output "Certificate SHA-256: $certificate"
		python "$PSScriptRoot/verify-release.py" $apk --build-tools $buildTools --package com.somnicard.game --certificate $certificate
		if ($LASTEXITCODE -ne 0) { throw 'Release verification failed.' }
	} finally {
		$env:JAVA_HOME = $previousJavaHome
	}
}

if (-not (Test-Path -LiteralPath $apk -PathType Leaf) -or -not (Test-Path -LiteralPath $checksumFile -PathType Leaf)) { throw 'Release APK and .sha256 must already exist.' }
$digest = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
$checksum = [regex]::Match((Get-Content -LiteralPath $checksumFile -Raw).Trim(), '^([a-fA-F0-9]{64})\s+\*?([^\r\n]+)$')
if (-not $checksum.Success -or $checksum.Groups[1].Value.ToLowerInvariant() -ne $digest -or $checksum.Groups[2].Value -cne (Split-Path -Leaf $apk)) { throw 'Release checksum or filename does not match APK.' }
Write-Output "APK: $apk"
Write-Output "Bytes: $((Get-Item -LiteralPath $apk).Length)"
Write-Output "SHA-256: $digest"

if ($Stage -eq 'Github') {
	$ghCommand = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
	$gh = if ($ghCommand) { $ghCommand.Source } else { Join-Path $env:USERPROFILE 'DevTools/gh/bin/gh.exe' }
	if (-not (Test-Path -LiteralPath $gh -PathType Leaf)) { throw 'GitHub CLI not found in PATH or DevTools/gh/bin.' }
	$notes = Get-Content -LiteralPath (Join-Path $ProjectRoot "docs/release-notes/$Version.md") -Raw
	if ($notes -notmatch '(?m)^SHA-256: <pending>\r?$') { throw 'Release notes must contain the SHA-256 placeholder line.' }
	$notes = [regex]::Replace($notes, '(?m)^SHA-256: <pending>\r?$', "SHA-256: $digest")
	$tempDirectory = Join-Path $ProjectRoot '.local/tmp'
	New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
	$tempNotes = Join-Path $tempDirectory ("release-notes-" + [guid]::NewGuid().ToString('N') + '.md')
	try {
		[System.IO.File]::WriteAllText($tempNotes, $notes, [System.Text.UTF8Encoding]::new($false))
		Push-Location -LiteralPath $ProjectRoot
		try {
			$tag = "v$Version"
			git show-ref --verify --quiet "refs/tags/$tag"
			$tagStatus = $LASTEXITCODE
			if ($tagStatus -eq 1) {
				git tag $tag
				if ($LASTEXITCODE -ne 0) { throw 'Could not create release tag.' }
			} elseif ($tagStatus -ne 0) { throw 'Could not inspect release tag.' }
			git push origin $tag
			if ($LASTEXITCODE -ne 0) { throw 'Could not push release tag.' }
			& $gh release create $tag $apk $checksumFile --title "Somnicard $Version" --notes-file $tempNotes
			if ($LASTEXITCODE -ne 0) { throw 'GitHub Release creation failed.' }
		} finally {
			Pop-Location
		}
	} finally {
		if (Test-Path -LiteralPath $tempNotes) { Remove-Item -LiteralPath $tempNotes }
	}
}

Write-Output 'Server upload is not part of this script; use the server workspace publish script.'
