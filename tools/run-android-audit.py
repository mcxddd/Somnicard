"""Run the isolated audit APK on an already running, explicitly named test emulator."""
from pathlib import Path
import os,subprocess,json,time,sys
root=Path(__file__).resolve().parent.parent
serial=sys.argv[1]
assert serial in ['emulator-5554','emulator-5556']
folder=root/'.local/android-audit'/('api36' if serial.endswith('5554') else 'api34')
folder.mkdir(exist_ok=True)
port=int(sys.argv[2]) if len(sys.argv)>2 else 5037
assert port in [5037,5038]
adb=[str(Path(os.environ.get('ANDROID_HOME', str(Path.home()/'DevTools/Android/Sdk')))/'platform-tools/adb.exe'),'-H','127.0.0.1','-P',str(port),'-s',serial]
package='com.somnicard.audit'
def call(*args,check=True):
    return subprocess.run(adb+list(args),check=check,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=45)
def launch():
    call('shell','am','force-stop',package)
    call('shell','am','start','-W','-n',package+'/com.godot.game.GodotAppLauncher')
def report(stage,timeout=150):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        result=call('exec-out','run-as',package,'cat','files/android-audit.json',check=False)
        if result.returncode==0 and result.stdout.lstrip().startswith(b'{'):
            data=json.loads(result.stdout)
            if data['stage']==stage:
                (folder/'report.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
                assert not data['failures'],data
                print(serial,stage,data['checks'],'checks',flush=True)
                return data
        time.sleep(1)
    raise RuntimeError(serial+' timed out awaiting '+stage)
call('install','-r',str(root/'.local/android-audit/audit.apk'))
call('shell','pm','clear',package)
call('logcat','-c')
launch()
report('awaiting_export_back')
call('shell','input','keyevent','4')
time.sleep(.6)
call('shell','run-as',package,'touch','files/export-back')
report('awaiting_category_back')
call('shell','input','keyevent','4')
time.sleep(.6)
call('shell','run-as',package,'touch','files/category-back')
data=report('complete')
for shot in data['screenshots']:
    name=shot.removeprefix('user://')
    (folder/name).write_bytes(call('exec-out','run-as',package,'cat','files/'+name).stdout)
logs=call('logcat','-d','-s','godot','AndroidRuntime').stdout.decode('utf-8',errors='replace')
(folder/'logcat.txt').write_text(logs,encoding='utf-8')
assert 'SCRIPT ERROR:' not in logs and 'ANDROID_AUDIT_FAIL:' not in logs and 'FATAL EXCEPTION' not in logs
data.update(scripted_test_app=True)
(folder/'report.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
call('shell','am','force-stop',package)
print('ANDROID_ACCEPTANCE_OK',serial,flush=True)
