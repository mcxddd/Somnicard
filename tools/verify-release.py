"""Validate a release APK without publishing. Requires local Android build-tools/JDK.
Produces a machine-readable receipt and checksum only after all assertions pass.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import struct
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--build-tools', type=Path, required=True)
    parser.add_argument('--package', required=True, choices=['com.somnicard.game', 'com.somnicard.practice'])
    parser.add_argument('--certificate', required=True, help='Expected public SHA-256 fingerprint; no private key')
    args = parser.parse_args()
    apk = args.apk.resolve()
    assert re.fullmatch(r'somnicard-[\d.]+-release.apk', apk.name)
    certificate = args.certificate.replace(':', '').lower()
    assert re.fullmatch('[a-f0-9]{64}', certificate)
    def run(tool, *values):
        ext = '.bat' if tool == 'apksigner' else '.exe'
        result = subprocess.run([str(args.build_tools / (tool + ext)), *map(str, values)],
            capture_output=True, text=True, encoding='utf-8', errors='replace', check=True, timeout=90)
        return result.stdout
    signature = run('apksigner', 'verify', '--verbose', '--print-certs', apk)
    actual = re.search(r'Signer #1 certificate SHA-256 digest: ([a-f0-9]+)', signature).group(1)
    assert actual == certificate, 'Unexpected signing identity'
    assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
    badging = run('aapt', 'dump', 'badging', apk)
    assert f"package: name='{args.package}'" in badging
    version = re.search(r"versionName='([^']+)'", badging).group(1)
    version_code = int(re.search(r"versionCode='(\d+)'", badging).group(1))
    assert apk.name == f'somnicard-{version}-release.apk'
    assert "sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging
    native_line = re.search(r'^native-code: (.+)$', badging, re.M).group(1)
    assert set(re.findall(r"'([^']+)'", native_line)) == {'arm64-v8a', 'x86_64'}
    permissions = set(re.findall(r"uses-permission: name='([^']+)'", badging))
    assert permissions <= {'android.permission.INTERNET', 'android.permission.VIBRATE'}, permissions
    manifest = run('aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml')
    debug = re.search(r'android:debuggable[^\n]+', manifest)
    assert debug is None or debug.group(0).rstrip().endswith('0x0'), 'APK is debuggable'
    backup = re.search(r'android:allowBackup[^\n]+', manifest)
    assert backup and backup.group(0).rstrip().endswith('0x0'), 'Automatic Android backup must stay disabled'
    run('zipalign', '-c', '-P', '16', '-v', '4', apk)
    native_files = []
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None, 'Corrupt ZIP member'
        names = archive.namelist()
        forbidden = ('assets/tests/', 'assets/docs/', 'assets/tools/', 'assets/.local/', 'assets/site/', 'assets/android-audit')
        assert not any(name.startswith(forbidden) or name.endswith(('.jks', '.keystore', '.pem')) for name in names)
        assert 'assets/project.binary' in names
        assert any('product/academy' in name for name in names)
        for name in names:
            if not name.startswith('lib/') or not name.endswith('.so'): continue
            data = archive.read(name)
            assert data[:5] == b'\x7fELF\x02' and data[5] == 1, 'Expected 64-bit little-endian ELF'
            phoff = struct.unpack_from('<Q', data, 32)[0]
            entsize, count = struct.unpack_from('<HH', data, 54)
            for i in range(count):
                offset = phoff + i * entsize
                if struct.unpack_from('<I', data, offset)[0] == 1:
                    assert struct.unpack_from('<Q', data, offset + 48)[0] >= 16384, name + ' lacks 16K load alignment'
            native_files.append(name)
    assert len(native_files) >= 2
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    receipt = {'version': version, 'versionCode': version_code, 'package': args.package,
        'debuggable': False, 'certificateSha256': certificate, 'sha256': digest,
        'bytes': apk.stat().st_size, 'permissions': sorted(permissions),
        'zip16k': True, 'elf16k': True, 'nativeLibraries': native_files,
        'archiveCrc': 'passed', 'note': 'Static artifact validation; device acceptance is separate.'}
    apk.with_suffix('.verified.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    apk.with_name(apk.name + '.sha256').write_text(f'{digest}  {apk.name}\n', encoding='ascii')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__': main()
