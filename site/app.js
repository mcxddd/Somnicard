'use strict';
// Metadata is generated only after APK signature, archive and hash validation.
(async () => {
  const status = document.querySelector('#release-state');
  try {
    const response = await fetch('release.json', {cache: 'no-store'});
    if (!response.ok) throw new Error('metadata unavailable');
    const r = await response.json();
    if (r.published !== true || !/^somnicard-[\d.]+(?:-release)?\.apk$/.test(r.file) || !/^[a-f0-9]{64}$/.test(r.sha256) || !Number.isSafeInteger(r.bytes) || r.bytes <= 0) throw new Error('release not verified');
    const link = document.querySelector('#apk');
    link.href = r.file; link.hidden = false;
    document.querySelector('#release-label').textContent = `Somnicard ${r.version} · ${(r.bytes / 1048576).toFixed(1)} MB`;
    document.querySelector('#release-details').textContent = `发布于 ${r.date}。安装包 ${r.bytes.toLocaleString()} 字节。签名证书 SHA-256：${r.certificateSha256}`;
    document.querySelector('#sha').textContent = `文件 SHA-256：${r.sha256}`;
    const checksum = document.querySelector('#checksum'); checksum.href = `${r.file}.sha256`; checksum.hidden = false;
    document.querySelector('#migration').textContent = r.migration;
    document.querySelector('#validation').textContent = r.validation;
    status.textContent = '';
  } catch (_) {
    document.querySelector('#release-label').textContent = '正式安装包正在准备';
    status.textContent = '下载尚未开放，或版本信息暂时无法读取。请稍后刷新本页。';
  }
})();
