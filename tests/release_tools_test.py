"""Static-site packaging tests use synthetic fixtures only; nothing is published."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('prepare_site', ROOT / 'tools/prepare-site.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SitePackaging(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='somnicard-site-test-')
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'site', self.root / 'site')
        self.apk = self.root / 'somnicard-2.0.0-release.apk'
        self.apk.write_bytes(b'TEST FIXTURE ONLY - NOT AN APK')
        self.meta = {'sha256': hashlib.sha256(self.apk.read_bytes()).hexdigest(),
            'bytes': self.apk.stat().st_size, 'debuggable': False,
            'version': '2.0.0', 'package': 'com.somnicard.game',
            'certificateSha256': '0' * 64}
        self.apk.with_name(self.apk.name + '.sha256').write_text(self.meta['sha256'])

    def tearDown(self): self.temp.cleanup()

    def build(self):
        self.apk.with_suffix('.verified.json').write_text(json.dumps(self.meta), encoding='utf-8')
        with patch.object(module, 'ROOT', self.root), patch.object(sys, 'argv', ['prepare-site', str(self.apk), '--validation', '仅为测试 <fixture>']):
            module.main()
        return (self.root / '.local/site-release/index.html').read_text(encoding='utf-8')

    def test_standalone_and_no_javascript_requirement(self):
        page = self.build()
        self.assertNotIn('<script', page)
        self.assertIn('href="somnicard-2.0.0-release.apk" download', page)
        self.assertIn('正式版与早期测试版独立安装', page)
        self.assertIn(self.meta['sha256'], page)
        self.assertIn('&lt;fixture&gt;', page)
        self.assertNotIn('正在读取版本', page)
        self.assertFalse((self.root / '.local/site-release/somnicard-downloads.conf').exists())

    def test_upgrade_has_appropriate_instructions(self):
        self.meta['package'] = 'com.somnicard.practice'
        self.assertIn('本版可覆盖同签名的早期测试版', self.build())

    def test_modified_apk_is_rejected(self):
        self.apk.write_bytes(b'TAMPERED FIXTURE')
        with self.assertRaises(AssertionError): self.build()

    def test_debug_receipt_is_rejected(self):
        self.meta['debuggable'] = True
        with self.assertRaises(AssertionError): self.build()


if __name__ == '__main__': unittest.main()
