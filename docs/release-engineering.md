# 发布工程

> **2026-10-31 服务器迁移：** 发版上传使用服务器管理工作区的发布脚本（不在本仓库）。下载地址格式为 `https://somnicard.nightricecake.com/download/<文件名>`，官网首页为 `https://somnicard.nightricecake.com/`。

## 身份与升级

Android 原位更新必须保持包名和签名证书。旧试用版使用 `com.somnicard.practice`，旧证书 SHA-256 为 `d12eb9b861ec51fd4ecef190bc003b2234b3be05babccb8f6df7019360d56c76`。

2.1.0 正式发布采用独立 `com.somnicard.game` 与专用发布签名，可与旧试用版并存。在旧版“设置 → 数据与备份”导出学习与牌局备份，再到正式版相同位置导入；确认记录恢复后再决定是否卸载旧版。设备设置与当前普通牌桌不包含在学习备份里。后续正式版更新须沿用同一正式证书与包名，并递增 versionCode。

参考：[Android 应用签名](https://developer.android.com/studio/publish/app-signing)、[Godot Android 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)。

## 2.2.0 发布记录（2026-11-04）

- 包含未单独发布的 2.1.3（按钮规范、新建牌桌、历史筛选、最近表现、显示大小等）。2.2.0 本身：每桌最多 6 人（破坏性修改）、短筹码全押表、100 BB 近似开局表、转牌抽象 CFR、教练读牌、opponent-4、15 BB 桌、复盘筹码动画、打包 Noto Sans CJK SC 子集字体；versionCode 32。
- 官网与 [GitHub v2.2.0 Release](https://github.com/mcxddd/Somnicard/releases/tag/v2.2.0) 的 APK 相同：SHA-256 `2a8f4d3269f29931fb148f4d495615b1267254492df6cbb864371ca46a96ed60`，54,722,426 字节；官网下载地址实际下载后校验一致。签名证书与 2.1.0 相同（`0914a276…09eb2`），可覆盖安装。标签 `v2.2.0` 指向 `581afe1`，构建记录中 268 个源文件的校验值与该提交一致。
- 验收：打包前 26 套回归通过；模拟器从 2.1.3 测试包覆盖升级后保留上次牌桌，15 BB / 6 人桌开局、短筹码教练建议正常，运行日志无脚本错误。
- 第一次模拟器验收发现 Android 上中文标点紧跟英文或数字时显示成方框（2.1.x 起就有，例如“2.5 BB，轮到你行动”）。先后试过系统后备字体和 zh_CN 区域设置都无效，最终打包子集字体作为首个后备字体，并把行高调到与微软雅黑一致，避免标签变高；重建后验收通过。
- 官网同时把“双人桌到九人桌”改为“双人桌到六人桌”；服务器工作区本地提交，未推送。

## 2.1.2 发布记录（2026-11-02）

- 训练室重做、统一界面规范与图标、数据可视化、帮助问答、首次打开引导与新插画；versionCode 30。
- 官网与 [GitHub v2.1.2 Release](https://github.com/mcxddd/Somnicard/releases/tag/v2.1.2) 的 APK 相同：SHA-256 `025af3515a7bde952938a13c843a031ea46d0006548eaba036b4a412edd72c41`，53,639,296 字节。签名证书与 2.1.0 相同（`0914a276…09eb2`），可覆盖安装。
- 验收：打包前 23 套回归通过；模拟器从 2.1.1 覆盖升级后保留上次牌桌、不显示引导；训练室开始练习、作答与结论卡正常；清空数据模拟新安装时出现三页引导，返回键可退出；运行日志无脚本错误。
- 第一次构建后在模拟器上发现训练室首页说明的句号单独换行，缩短文案后重新构建；重建时首次资源导入又偶发失败一次，重试通过。

## 2.1.1 发布记录（2026-10-31）

- 下注金额改用数字键盘、进阶电脑对手升级为 opponent-3、训练室与 main.gd 拆分；versionCode 29。
- 官网与 [GitHub v2.1.1 Release](https://github.com/mcxddd/Somnicard/releases/tag/v2.1.1) 的 APK 相同：SHA-256 `6e52c0805828ca081e856b6337cd9ce5d56dbb0002b63e3575bf3ca60fd2ed84`，52,813,357 字节。签名证书与 2.1.0 相同（`0914a276…09eb2`），可覆盖安装。
- 验收：打包前 23 套回归通过；模拟器从 2.1.0 覆盖升级、存档恢复、开桌与加注面板正常；真机确认金额输入弹出 9 键数字键盘。
- 首次签名构建在隔离工程的首次资源导入步骤偶发返回非零（日志无错误），清理隔离目录后重试通过。若再出现，先重试一次，再看 `.local/release-logs/build-1.log`。

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
