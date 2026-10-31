# 发布工程

> **2026-10-31 服务器迁移：** 发版上传使用服务器管理工作区的发布脚本（不在本仓库）。下载地址格式为 `https://somnicard.nightricecake.com/download/<文件名>`，官网首页为 `https://somnicard.nightricecake.com/`。

## 身份与升级

Android 原位更新必须保持包名和签名证书。旧试用版使用 `com.somnicard.practice`，旧证书 SHA-256 为 `d12eb9b861ec51fd4ecef190bc003b2234b3be05babccb8f6df7019360d56c76`。

2.1.0 正式发布采用独立 `com.somnicard.game` 与专用发布签名，可与旧试用版并存。在旧版“设置 → 数据与备份”导出学习与牌局备份，再到正式版相同位置导入；确认记录恢复后再决定是否卸载旧版。设备设置与当前普通牌桌不包含在学习备份里。后续正式版更新须沿用同一正式证书与包名，并递增 versionCode。

参考：[Android 应用签名](https://developer.android.com/studio/publish/app-signing)、[Godot Android 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)。

## 2.1.0 发布记录（2026-10-31）

- 源码已发布到 [GitHub 公开仓库](https://github.com/mcxddd/Somnicard)，使用 MIT 许可；[v2.1.0 Release](https://github.com/mcxddd/Somnicard/releases/tag/v2.1.0) 附正式 APK 和校验文件。
- 官网、GitHub 与本地 APK 的 SHA-256 均为 `ed40594cfe7a7b36834120fca416278086663520bfe2b2319b618bbeef6782f8`，大小 52,809,132 字节；官网尾部 Range 下载已核对。
- 正式签名证书 SHA-256：`0914a27626aa5e6375e925438dcdad64a2502d9cffc9133a799002b8c9509eb2`。后续版本应与此指纹核对，不要重新生成正式密钥。
- 交接记录中的 Release 模拟器验收包含首页、开桌、发牌和下注；尚无 2.1.0 的完整真机验收记录。备份迁移、文件选择、后台恢复、震动和不同手机 GPU 仍需真机验收。
- 本次后续维护仅修复发布工具和文档，不重建或替换已发布 APK，也不移动 `v2.1.0` 标签。

## 本地工具

- `tools/publish-release.ps1 -Stage Build|Github [-Version 2.1.0]`：默认读取 `export_presets.cfg` 的 `version/name`；Build 检查、签名构建并核验，Github 推送版本标签并创建 GitHub Release。
- `tools/release-signing.ps1 -Action Create`：仅用于首次准备正式签名；本项目已有正式密钥，丢失时应恢复备份，不得重新创建。将随机密码通过 Windows 当前用户 DPAPI 保存，在 `%USERPROFILE%/.somnicard/signing` 创建 RSA 3072 位 PKCS#12 密钥，限制目录 ACL，永不覆盖已有文件。
- `tools/release-signing.ps1 -Action Check`：验证保存的密码能够打开密钥，并输出公开证书指纹；不构建或上传 APK。对照上面的正式证书指纹核验。
- `tools/release-signing.ps1 -Action Build`：解密到当前进程内存，通过 Godot 指定环境变量提供签名；内部调用 `tools/build-release.py --identity standalone --engine <Godot>`，结束时清除环境变量。密码不进入命令行或导出配置。
- `tools/build-release.py --identity standalone|upgrade --engine <Godot>`：复制发布白名单到隔离目录，用 `--export-release` 导出，生成源码和 APK 指纹清单。正式发布使用 standalone；upgrade 仅供保留旧包名的流程，由调用方提供原证书环境变量。
- `tools/verify-release.py <APK> --build-tools <SDK build-tools目录> --package com.somnicard.game --certificate <公钥证书SHA-256>`：检查非调试、签名 v2、版本、ABI、最小 SDK、权限、CRC、ZIP 与原生库 16 KB 对齐、开发文件排除；成功才写 `.verified.json` 与 `<APK>.sha256`。

签名目录默认使用 `%USERPROFILE%/.somnicard/signing`，不依赖 AppData 或某个应用的数据目录。需要指定其他已有签名目录时，使用 `-SigningDirectory <目录>` 或环境变量 `SOMNICARD_SIGNING_DIR`。目录内必须有 `somnicard-release.p12` 和当前 Windows 用户可解密的 `password.dpapi`。迁移后先运行 Check，不要用 Create 来解决路径缺失。

Build Tools 固定使用 `%USERPROFILE%/DevTools/Android/Sdk/build-tools/36.0.0`。GitHub CLI 优先使用 PATH 中的 `gh`，否则使用 `%USERPROFILE%/DevTools/gh/bin/gh.exe`；运行 Github 阶段前需完成登录，且 origin 指向目标 GitHub 仓库。发布脚本显式按 UTF-8 读取中文版本说明，兼容 Windows PowerShell 5.1 和 PowerShell 7。

DPAPI 文件与 Windows 身份绑定，不等同于跨机器备份。维护者应另行保存可恢复的加密密钥及密码到离线备份 / 密码管理器；不要将密码粘贴到聊天、网站、Git 或发布日志。尚未建立恢复备份时应明确记录。

`site/` 与 `tools/prepare-site.py` 仍被 `tests/release_tools_test.py` 的站点打包测试使用，因此保留。线上官网在电脑上的服务器管理工作区构建后上传，不使用本仓库的站点生成工具；失效 nginx 配置已移除。

## 发布步骤

1. 准备版本：同步 `project.godot` 的 `config/version`、`export_presets.cfg` 的 `version/name`，递增 `version/code`，填写 `docs/release-notes/<版本>.md`，保留 `SHA-256: <pending>` 占位行。确认正式签名及恢复备份已准备好。
2. 检查 → 构建签名 → 校验：在项目根目录运行以下命令。脚本先运行 `tools/check.ps1`，再运行 `tools/release-signing.ps1 -Action Build`；从生成的 APK 通过 `apksigner verify --verbose --print-certs` 读取并打印证书 SHA-256，随后传给 `verify-release.py`，固定核验包名 `com.somnicard.game`。最终打印 APK 路径、字节数和文件 SHA-256。显式指定的 Build 版本必须与项目和导出配置一致。

   ```powershell
   pwsh -NoProfile -File tools/publish-release.ps1 -Stage Build
   ```

   输出为 `builds/android/somnicard-<版本>-release.apk`、构建清单、核验清单与 `<APK>.sha256`。已存在的同名 APK 会阻止重新构建；不要无意覆盖已发布安装包。脚本读取的证书指纹需由维护者与已保存的正式公钥指纹核对；静态核验不代替身份确认与设备验收。
3. 设备验收：实际 Release 包单独安装运行并核对签名、与试用版并存、备份迁移、输入、文件选择、后台切换和恢复。新功能 Android 测试使用隔离 `com.somnicard.audit`，不得清空生产包；模拟器不替代物理手机的 GPU、音量、震动与系统安装器测试。
4. 上传服务器：使用服务器管理工作区的发布脚本上传已验收的 APK 与校验文件，并生成官网页面。上传后核对文件大小、完整 SHA-256 与尾部 Range 下载；下载地址为 `https://somnicard.nightricecake.com/download/<文件名>`。服务器配置与回滚由该工作区维护。
5. GitHub Release：确认待发布源码已提交并推送，当前 HEAD 就是版本标签应指向的提交，再运行以下命令。脚本要求 APK 和 `.sha256` 已存在且哈希一致；将说明中的占位行替换为真实 SHA-256，临时说明写入 `.local/tmp/`，结束后删除。若本地尚无标签，则执行 `git tag v<版本>`；然后执行 `git push origin v<版本>`，以及 `gh release create v<版本> <APK> <APK>.sha256 --title "Somnicard <版本>" --notes-file <临时说明>`。确认 GitHub Release 附件与服务器文件一致。

   ```powershell
   pwsh -NoProfile -File tools/publish-release.ps1 -Stage Github
   ```

仅上传经过审核的页面、截图、版本元数据、APK 与校验文件，不上传用户记录、API Key 或签名文件。游戏没有自动下载或自更新后台程序，用户通过官网或 GitHub Releases 选择安装更新。

服务器上传不在本发布脚本内，由服务器管理工作区的发布脚本完成。
