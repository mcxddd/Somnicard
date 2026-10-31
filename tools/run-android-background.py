"""Foreground recovery screenshots on an owned emulator; never clears production data.

Start the desired home/table screen first. This checks rendered content and saves
logs; it does not prove every control is responsive or cover physical-device GPUs.
Requires Pillow. Example: python tools/run-android-background.py emulator-5554 5038
"""
from pathlib import Path
import hashlib
import io
import os
import json
import subprocess
import sys
import time
from PIL import Image, ImageStat

root = Path(__file__).resolve().parent.parent
serial = sys.argv[1]
assert serial in ['emulator-5554', 'emulator-5556']
port = int(sys.argv[2]) if len(sys.argv) > 2 else 5037
assert port in [5037, 5038]
adb = [str(Path(os.environ.get('ANDROID_HOME', str(Path.home()/'DevTools/Android/Sdk')))/'platform-tools/adb.exe'),
       '-H', '127.0.0.1', '-P', str(port), '-s', serial]
package = sys.argv[3] if len(sys.argv) > 3 else 'com.somnicard.practice'
assert package in ['com.somnicard.practice', 'com.somnicard.game', 'com.somnicard.background']
cycles = int(sys.argv[4]) if len(sys.argv) > 4 else 10
assert 1 <= cycles <= 60
out = root / '.local/android-interactions' / ('api36' if serial.endswith('5554') else 'api34') / time.strftime('background-%Y%m%d-%H%M%S')
out.mkdir(parents=True, exist_ok=False)

def call(*args, check=True):
    result = subprocess.run(adb + list(args), capture_output=True, timeout=45)
    if check:
        result.check_returncode()
    return result

def session_hash():
    result = call('exec-out', 'run-as', package, 'cat', 'files/session.json', check=False)
    return hashlib.sha256(result.stdout).hexdigest() if result.returncode == 0 else None

call('shell', 'am', 'start', '-W', '-n', package + '/com.godot.game.GodotAppLauncher')
time.sleep(2)
before = session_hash()
results = []
call('logcat', '-c')
for index in range(cycles):
    call('shell', 'input', 'keyevent', '3')
    time.sleep(1)
    call('shell', 'am', 'start', '-W', '-n', package + '/com.godot.game.GodotAppLauncher')
    time.sleep(1.5)
    shot = call('exec-out', 'screencap', '-p').stdout
    (out / f'cycle-{index + 1:02d}.png').write_bytes(shot)
    image = Image.open(io.BytesIO(shot)).convert('RGB')
    width, height = image.size
    content = image.crop((width // 10, height // 10, width * 9 // 10, height * 9 // 10))
    deviation = ImageStat.Stat(content).stddev
    rendered = max(deviation) > 5
    results.append({'cycle': index + 1, 'rendered_content': rendered, 'stddev': deviation})
    print(serial, index + 1, 'rendered' if rendered else 'BLANK', flush=True)

logs = call('logcat', '-d').stdout
(out / 'logcat.txt').write_bytes(logs)
report = {'package': package, 'serial': serial, 'cycles': results,
          'session_before': before, 'session_after': session_hash(),
          'egl_bad_surface': logs.count(b'EGL_BAD_SURFACE'),
          'script_or_java_crash': b'SCRIPT ERROR:' in logs or b'FATAL EXCEPTION' in logs}
(out / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(out, flush=True)
assert all(row['rendered_content'] for row in results), 'Blank render; inspect screenshots and EGL logs'
assert not report['script_or_java_crash'], 'Runtime error; inspect logs'
assert report['egl_bad_surface'] == 0, 'Surface lifecycle error; inspect logs'
if before is not None:
    assert before == report['session_after'], 'Saved table changed during background-only cycles'
