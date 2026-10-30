"""Create an isolated Android test app from the exact game sources, without user data."""
from pathlib import Path
import shutil,hashlib,json,sys
root=Path(__file__).resolve().parent.parent
target=root/'.local/android-audit-project'
target.mkdir(exist_ok=True)
for name in ['scripts','scenes','assets','native']:
    shutil.copytree(root/name,target/name,dirs_exist_ok=True)
(target/'tools').mkdir(exist_ok=True)
for name in ['prepare-android.py','export-android.py']:
    shutil.copyfile(root/'tools'/name,target/'tools'/name)
s=(root/'project.godot').read_text(encoding='utf-8').replace('run/main_scene="res://scenes/main.tscn"','run/main_scene="res://android-audit.tscn"').replace('config/name="Somnicard"','config/name="Somnicard Audit"')
(target/'project.godot').write_text(s,encoding='utf-8')
runner='android_interactions.gd' if '--interactions' in sys.argv else 'android_runner.gd'
(target/'android-audit.gd').write_text((root/'tests'/runner).read_text(encoding='utf-8'),encoding='utf-8')
(target/'android-audit.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://android-audit.gd" id="1"]\n[node name="AndroidAudit" type="Node"]\nscript = ExtResource("1")\n',encoding='utf-8')
s=(root/'export_presets.cfg').read_text(encoding='utf-8').replace('com.somnicard.practice','com.somnicard.audit').replace('package/name="Somnicard"','package/name="Somnicard Audit"')
(target/'export_presets.cfg').write_text(s,encoding='utf-8')
hashes={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'scripts').rglob('*.gd')}
assert all(hashlib.sha256((target/name).read_bytes()).hexdigest()==digest for name,digest in hashes.items())
(root/'.local/android-audit/source-hashes.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
print(target)
