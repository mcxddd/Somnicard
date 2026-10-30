"""Native touch actions with state assertions in an isolated audit APK. No user data."""
from pathlib import Path
import subprocess,json,time,sys
root=Path(__file__).resolve().parent.parent
serial=sys.argv[1]
assert serial in ['emulator-5554','emulator-5556']
port=int(sys.argv[2]) if len(sys.argv)>2 else 5037
assert port in [5037,5038]
out=root/'.local/android-interactions'/('api36' if serial.endswith('5554') else 'api34')
out.mkdir(parents=True,exist_ok=True)
adb=[str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'),'-H','127.0.0.1','-P',str(port),'-s',serial]
package='com.somnicard.audit'
def call(*args,check=True):
    result=subprocess.run(adb+list(args),stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60)
    if check and result.returncode:
        raise RuntimeError(result.stderr.decode(errors='replace')+result.stdout.decode(errors='replace'))
    return result
call('wait-for-device')
call('install','-r',str(root/'.local/android-interactions/audit.apk'))
call('shell','pm','clear',package)
call('reverse','tcp:18948','tcp:18948')
call('logcat','-c')
call('shell','am','start','-W','-n',package+'/com.godot.game.GodotAppLauncher')
seen=0
last_log_check=0.0
deadline=time.monotonic()+150
while time.monotonic()<deadline:
    result=call('exec-out','run-as',package,'cat','files/interactions.json',check=False)
    if result.returncode or not result.stdout.lstrip().startswith(b'{'):
        time.sleep(.4);continue
    data=json.loads(result.stdout)
    (out/'report.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    if data['failures']: break
    if data['stage']=='complete': break
    if data['sequence']==seen:
        if time.monotonic()-last_log_check>5:
            last_log_check=time.monotonic()
            logs=call('logcat','-d','-s','godot','AndroidRuntime').stdout
            if b'SCRIPT ERROR:' in logs or b'FATAL EXCEPTION' in logs:
                (out/'logcat.txt').write_bytes(logs)
                raise RuntimeError('Runtime error; inspect '+str(out/'logcat.txt'))
        time.sleep(.5);continue
    seen=data['sequence'];deadline=time.monotonic()+150
    print(serial,seen,data['steps'][-1],flush=True)
    for command in data['commands']:
        kind=command['kind']
        if kind=='tap':call('shell','input','tap',*map(str,command['at']))
        elif kind=='swipe':call('shell','input','swipe',*map(str,command['from']+command['to']),'450')
        elif kind=='back':call('shell','input','keyevent','4')
        elif kind=='keys':
            assert all(code in [19,20,66] for code in command['codes'])
            for code in command['codes']:call('shell','input','keyevent',str(code))
        elif kind=='text':
            assert command['value'] in ['touch-007','097']
            call('shell','input','text',command['value'])
        elif kind=='background':
            call('shell','input','keyevent','3');time.sleep(1)
            call('shell','am','start','-W','-n',package+'/com.godot.game.GodotAppLauncher')
        else:raise ValueError(kind)
    time.sleep(.45)
    if any(word in data['steps'][-1] for word in ['all-in','details upward','range grid','searched history','rate-limited','selected model']):
        (out/f'step-{seen:03d}.png').write_bytes(call('exec-out','screencap','-p').stdout)
    call('shell','run-as',package,'touch',f'files/interaction-{seen}')
else:
    raise RuntimeError('Interaction report timed out')
(out/'screen.png').write_bytes(call('exec-out','screencap','-p').stdout)
logs=call('logcat','-d','-s','godot','AndroidRuntime').stdout.decode('utf-8',errors='replace')
(out/'logcat.txt').write_text(logs,encoding='utf-8')
assert not data['failures'],data['failures']
assert data['stage']=='complete'
assert not any(x in logs for x in ['SCRIPT ERROR:','FATAL EXCEPTION','INTERACTION_FAIL:'])
call('shell','am','force-stop',package)
print('ANDROID_INTERACTIONS_OK',serial,data['checks'],'checks',len(data['steps']),'native input steps',flush=True)
