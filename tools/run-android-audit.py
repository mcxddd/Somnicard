"""Run the isolated audit APK on an already running, explicitly named test emulator."""
from pathlib import Path
import subprocess,json,time,sys
root=Path(__file__).resolve().parent.parent
serial=sys.argv[1]
assert serial in ['emulator-5554','emulator-5556']
folder=root/'.local/android-audit'/('api36' if serial.endswith('5554') else 'api34')
folder.mkdir(exist_ok=True)
port=int(sys.argv[2]) if len(sys.argv)>2 else 5037
assert port in [5037,5038]
adb=[str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'),'-H','127.0.0.1','-P',str(port),'-s',serial]
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
call('reverse','tcp:18948','tcp:18948')
call('logcat','-c')
launch()
def marker(name):
    call('shell','run-as',package,'touch','files/'+name)
up=report('awaiting_model_up')['swipe']
call('shell','input','swipe',*map(str,up),'500')
time.sleep(.5)
marker('model-up')
down=report('awaiting_model_down')['swipe']
call('shell','input','swipe',*map(str,down),'500')
time.sleep(.5)
marker('model-down')
tap=report('awaiting_model_tap')['tap']
call('shell','input','tap',*map(str,tap))
marker('model-tap')
report('awaiting_model_back')
call('shell','input','keyevent','4')
time.sleep(.6)
(folder/'native-after-model-back.png').write_bytes(call('exec-out','screencap','-p').stdout)
marker('model-back')
report('awaiting_category_back')
call('shell','input','keyevent','4')
time.sleep(.6)
marker('category-back')
data=report('awaiting_relaunch')
encrypted=call('exec-out','run-as',package,'cat','no_backup/ai-credentials.v1').stdout
assert len(encrypted)>=28 and b'ANDROID_EMULATOR_DUMMY_ONLY' not in encrypted
launch()
report('awaiting_tamper',timeout=60)
call('shell','am','force-stop',package)
damaged=bytearray(encrypted);damaged[-1]^=1
temp=folder/'tampered-ciphertext.bin';temp.write_bytes(damaged)
remote='/data/local/tmp/somnicard-audit-'+serial.split('-')[1]+'.bin'
call('push',str(temp),remote)
call('shell','chmod','644',remote)
call('shell','run-as',package,'cp',remote,'no_backup/ai-credentials.v1')
call('shell','rm',remote)
launch()
data=report('complete',timeout=60)
assert call('shell','run-as',package,'ls','no_backup/ai-credentials.v1',check=False).returncode!=0
for shot in data['screenshots']:
    name=shot.removeprefix('user://')
    (folder/name).write_bytes(call('exec-out','run-as',package,'cat','files/'+name).stdout)
logs=call('logcat','-d','-s','godot','AndroidRuntime').stdout.decode('utf-8',errors='replace')
(folder/'logcat.txt').write_text(logs,encoding='utf-8')
assert 'SCRIPT ERROR:' not in logs and 'ANDROID_AUDIT_FAIL:' not in logs and 'FATAL EXCEPTION' not in logs
data.update(ciphertext_checked=True,external_tamper_checked=True,deleted_file_checked=True,scripted_test_app=True)
(folder/'report.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
call('shell','am','force-stop',package)
print('ANDROID_ACCEPTANCE_OK',serial,flush=True)
