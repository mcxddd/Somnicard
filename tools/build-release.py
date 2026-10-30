"""Build a non-debug APK in an isolated project with externally supplied signing.

Credentials must be provided in GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}.
No secret is accepted on the command line or written to export_presets.cfg.
Identity is mandatory: standalone preserves beta side-by-side; upgrade retains its ID.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--identity', choices=['standalone', 'upgrade'], required=True)
    parser.add_argument('--engine', type=Path, required=True)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    for suffix in ['PATH', 'USER', 'PASSWORD']:
        if not os.environ.get('GODOT_ANDROID_KEYSTORE_RELEASE_' + suffix):
            raise SystemExit('Missing signing environment: ' + suffix)
    secret = os.environ['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']
    key_path = Path(os.environ['GODOT_ANDROID_KEYSTORE_RELEASE_PATH']).resolve()
    if not key_path.is_file() or key_path.is_relative_to(ROOT):
        raise SystemExit('Signing keystore must exist outside the project')
    (ROOT / '.local').mkdir(exist_ok=True)
    target = Path(tempfile.mkdtemp(prefix='release-project-', dir=ROOT / '.local'))
    for name in ['scripts', 'scenes', 'assets', 'native']:
        shutil.copytree(ROOT / name, target / name, dirs_exist_ok=True)
    (target / 'tools').mkdir(exist_ok=True)
    shutil.copyfile(ROOT / 'tools/prepare-android.py', target / 'tools/prepare-android.py')
    shutil.copyfile(ROOT / 'project.godot', target / 'project.godot')
    preset = (ROOT / 'export_presets.cfg').read_text(encoding='utf-8')
    package = 'com.somnicard.game' if args.identity == 'standalone' else 'com.somnicard.practice'
    preset = preset.replace('com.somnicard.practice', package)
    preset = preset.replace('README.md"', 'README.md,site/*"')
    (target / 'export_presets.cfg').write_text(preset, encoding='utf-8')
    version = re.search(r'version/name="([\d.]+)"', preset).group(1)
    artifact = ROOT / 'builds/android' / f'somnicard-{version}-release.apk'
    artifact.parent.mkdir(parents=True, exist_ok=True)
    if artifact.exists():
        raise SystemExit('Release file already exists; verify/archive it before a deliberate rebuild')
    engine = args.engine.resolve()
    native = engine.with_name(engine.name.replace('_console.exe', '.exe'))
    if native.exists(): engine = native
    commands = [
        [sys.executable, str(target / 'tools/prepare-android.py')],
        [str(engine), '--headless', '--editor', '--path', str(target), '--import'],
        [str(engine), '--headless', '--path', str(target), '--export-release', 'Android', str(artifact), '--quit'],
    ]
    logs = ROOT / '.local/release-logs'
    logs.mkdir(exist_ok=True)
    for i, command in enumerate(commands):
        log = logs / f'build-{i}.log'
        try:
            with log.open('wb') as output:
                result = subprocess.run(command, cwd=target, stdin=subprocess.DEVNULL,
                    stdout=output, stderr=subprocess.STDOUT, timeout=900,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        finally:
            if log.exists():
                text = log.read_text(encoding='utf-8', errors='replace')
                text = text.replace(secret, '[REDACTED]').replace(str(key_path), '[SIGNING_KEY]')
                log.write_text(text, encoding='utf-8')
        if result.returncode or 'SCRIPT ERROR:' in text or '\nERROR:' in text:
            raise SystemExit('Release build failed; sanitized log: ' + str(log))
    if not artifact.is_file(): raise SystemExit('Export did not produce an APK')
    source = {}
    for folder in ['scripts', 'scenes', 'assets', 'native']:
        for path in (ROOT / folder).rglob('*'):
            if path.is_file() and not path.name.endswith('.import'):
                source[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    receipt = {'version': version, 'identity': args.identity, 'package': package,
        'build_type': 'release', 'source_sha256': source,
        'project_sha256': hashlib.sha256((target / 'project.godot').read_bytes()).hexdigest(),
        'preset_sha256': hashlib.sha256((target / 'export_presets.cfg').read_bytes()).hexdigest(),
        'apk_sha256': hashlib.sha256(artifact.read_bytes()).hexdigest()}
    artifact.with_suffix('.build.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print('RELEASE_EXPORT_OK', artifact, package)
    print('Signature/archive/device verification is still required before publication.')


if __name__ == '__main__': main()
