"""Run the native Godot executable directly: the Windows console shim can remain open
after a Gradle export. Write to a file so a Gradle daemon cannot keep an output pipe open.
"""
from pathlib import Path
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

root = Path(__file__).resolve().parent.parent
engine = Path(sys.argv[1])
native = engine.with_name(engine.name.replace('_console.exe', '.exe'))
if os.name == 'nt' and native.exists():
    engine = native
target = Path(sys.argv[2]).resolve()
log = root / '.local/android-export-process.log'
log.parent.mkdir(exist_ok=True)
with log.open('wb') as output:
    process = subprocess.Popen([str(engine), '--headless', '--path', str(root),
        '--export-debug', 'Android', str(target), '--quit'], cwd=root,
        stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    try:
        code = process.wait(timeout=600)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        raise SystemExit(f'Export process timed out; inspect {log}')
print(log.read_text(encoding='utf-8', errors='replace'))
if code:
    raise SystemExit(code)
if not target.exists():
    raise SystemExit('Export did not produce the APK')
print('ANDROID_EXPORT_PROCESS_EXIT_OK')
