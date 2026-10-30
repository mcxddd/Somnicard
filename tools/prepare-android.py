"""Install the pinned Godot template and the small native credential plugin, idempotently."""
from pathlib import Path
import os, shutil, zipfile

root = Path(__file__).resolve().parent.parent
build = root / 'android/build'
if not (build / 'build.gradle').exists():
    template = Path(os.environ['APPDATA']) / 'Godot/export_templates/4.7.2.stable/android_source.zip'
    build.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(template) as archive:
        archive.extractall(build)
(build / '.gdignore').touch()
(root / 'android/.build_version').write_text('4.7.2.stable', encoding='utf-8')
dest = build / 'src/main/java/com/somnicard/security'
dest.mkdir(parents=True, exist_ok=True)
shutil.copyfile(root / 'native/android/SomnicardVault.java', dest / 'SomnicardVault.java')
shutil.copyfile(root / 'native/android/GodotApp.java', build / 'src/main/java/com/godot/game/GodotApp.java')
manifest = build / 'src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
metadata = '<meta-data android:name="org.godotengine.plugin.v2.SomnicardVault" android:value="com.somnicard.security.SomnicardVault" />'
if metadata not in text:
    text = text.replace('</application>', '    ' + metadata + '\n    </application>')
manifest.write_text(text, encoding='utf-8')
print('Android template and Keystore plugin ready')
