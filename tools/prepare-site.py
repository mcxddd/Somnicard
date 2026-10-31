"""Create a static download page from a verified APK, without JS or a build dependency.
Does not upload. Run only after device acceptance, with an honest validation summary.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import html
import json
import re
import shutil

ROOT = Path(__file__).resolve().parent.parent


def main():
    p = argparse.ArgumentParser()
    p.add_argument('apk', type=Path)
    p.add_argument('--validation', required=True)
    args = p.parse_args()
    apk = args.apk.resolve()
    receipt = json.loads(apk.with_suffix('.verified.json').read_text(encoding='utf-8'))
    assert receipt['sha256'] == hashlib.sha256(apk.read_bytes()).hexdigest()
    assert receipt['bytes'] == apk.stat().st_size and receipt['debuggable'] is False
    independent = receipt['package'] == 'com.somnicard.game'
    migration = ('正式版与早期测试版独立安装，旧版不会被删除。在旧版导出备份后，在正式版导入，可迁移牌局、收藏、备注、训练与课程进度。设备设置需重新设置。'
        if independent else '本版可覆盖同签名的早期测试版，保留本机记录。更新前仍建议导出备份；不要卸载旧版。')
    meta = {**receipt, 'published': True, 'file': apk.name,
        'date': datetime.date.today().isoformat(), 'migration': migration, 'validation': args.validation}
    dest = ROOT / '.local/site-release'
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / 'site/images', dest / 'images', dirs_exist_ok=True)
    shutil.copyfile(ROOT / 'site/style.css', dest / 'style.css')
    content = (ROOT / 'site/index.html').read_text(encoding='utf-8')
    content = content.replace('  <script src="app.js" defer></script>\n', '')
    def text(tag, identity, value):
        nonlocal content
        content, count = re.subn(f'(<{tag}\\b[^>]*\\bid="{identity}"[^>]*>).*?(</{tag}>)',
            lambda m: m[1] + html.escape(value) + m[2], content, count=1, flags=re.S)
        assert count == 1, identity
    text('p', 'release-label', f'Somnicard {meta["version"]} · {meta["bytes"] / 1048576:.1f} MB')
    text('p', 'release-state', '')
    text('li', 'migration', migration)
    text('p', 'release-details', f'发布于 {meta["date"]}。安装包 {meta["bytes"]:,} 字节。签名证书 SHA-256：{meta["certificateSha256"]}')
    text('p', 'sha', '文件 SHA-256：' + meta['sha256'])
    text('p', 'validation', args.validation)
    content = content.replace('id="apk" class="button primary" hidden download', f'id="apk" class="button primary" href="{apk.name}" download')
    content = content.replace('id="checksum" hidden', f'id="checksum" href="{apk.name}.sha256"')
    assert '正式安装包正在准备' not in content and '<script' not in content
    (dest / 'index.html').write_text(content, encoding='utf-8')
    (dest / 'release.json').write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding='utf-8')
    shutil.copyfile(apk, dest / apk.name)
    shutil.copyfile(apk.with_name(apk.name + '.sha256'), dest / (apk.name + '.sha256'))
    print('STATIC_SITE_PREPARED', dest)


if __name__ == '__main__': main()
