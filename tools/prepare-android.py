"""Install the pinned Godot template and remove the retired security plugin, idempotently."""
from pathlib import Path
import os, re, shutil, zipfile

root = Path(__file__).resolve().parent.parent
build = root / 'android/build'
if not (build / 'build.gradle').exists():
    template = Path(os.environ['APPDATA']) / 'Godot/export_templates/4.7.2.stable/android_source.zip'
    build.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(template) as archive:
        archive.extractall(build)
(build / '.gdignore').touch()
(root / 'android/.build_version').write_text('4.7.2.stable', encoding='utf-8')
for source in (build / 'src/main/java/com/somnicard/security').glob('*.java'):
    source.unlink()
shutil.copyfile(root / 'native/android/GodotApp.java', build / 'src/main/java/com/godot/game/GodotApp.java')
manifest = build / 'src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
text = re.sub(r'\s*<meta-data\b(?=[^>]*android:value="com\.somnicard\.security\.)[^>]*/>', '', text)
manifest.write_text(text, encoding='utf-8')
print('Android template ready')
