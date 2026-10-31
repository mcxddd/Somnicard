# 官网直装发布工程

> **2026-10-31 服务器迁移：** 发版和上传以 `C:\Users\macxd\Documents\kimchiserver\SERVER-USAGE.md` 为准；下载地址格式为 `https://somnicard.nightricecake.com/download/<文件名>`。

## 身份与升级

Android 原位更新必须保持包名和签名证书。当前 1.13 测试版使用 `com.somnicard.practice`，旧证书 SHA-256 为 `d12eb9b861ec51fd4ecef190bc003b2234b3be05babccb8f6df7019360d56c76`。

建议正式版采用独立 `com.somnicard.game` 与专用发布签名，旧版并存，手动备份导入迁移。若用户选择原位更新，则必须沿用旧证书；仅将构建改为 Release 不会改变更新规则。不能删除旧版数据来绕过签名冲突。

依据：[Android 应用签名](https://developer.android.com/studio/publish/app-signing)、[Godot Android 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)。

## 本地工具

- `tools/release-signing.ps1 -Action Create`：只在独立身份获选后执行一次。将随机密码通过 Windows 当前用户 DPAPI 保存，在 `%LOCALAPPDATA%/Somnicard/signing` 创建 RSA 3072 位 PKCS#12 密钥，限制目录 ACL，永不覆盖已有文件。
- `tools/release-signing.ps1 -Action Build`：解密到当前进程内存，通过 Godot 指定环境变量提供签名；结束时清除环境变量。密码不进入命令行或导出配置。
- `tools/build-release.py --identity standalone|upgrade --engine <Godot>`：复制发布白名单到隔离目录，用 `--export-release` 导出，生成源码和 APK 指纹清单。upgrade 路线由调用方提供原证书环境变量，不自动读取或猜测用户密钥。
- `tools/verify-release.py <APK> --build-tools <SDK build-tools目录> --package <包名> --certificate <公钥证书SHA-256>`：检查非调试、签名 v2、版本、ABI、最小 SDK、权限、CRC、ZIP 与原生库 16 KB 对齐、开发文件排除；成功才写 verified.json 与 .sha256。
- `tools/prepare-site.py <已核验APK> --validation '<实际测试范围>'`：由核验元数据生成 `.local/site-release`。下载链接和安装迁移说明直接写入静态 HTML，无运行时脚本、第三方资源或统计请求。

DPAPI 文件与 Windows 身份绑定，不等同于跨机器备份。发布密钥创建后，维护者应另行保存可恢复的加密密钥及密码到其离线备份 / 密码管理器；不要将密码粘贴到聊天、网站、Git 或发布日志。尚未建立恢复备份时需在交付中明确记录。

## 验收与发布

运行完整 `tools/check.ps1`。新功能 Android 测试使用隔离 `com.somnicard.audit`，不得清空生产包。实际 Release 包需单独安装运行并核对签名、迁移、输入、文件选择、后台切换和恢复；模拟器不替代物理手机的 GPU、音量、震动与系统安装器测试。

服务器上传、配置和回滚步骤以顶部服务器使用说明为准。`site/somnicard-downloads.conf` 中的旧路由、服务器路径及原 1Panel/OpenResty 配置参考已过时，不再作为部署依据。

仅上传审核过的页面、截图、版本元数据、APK 与校验文件，不上传源代码、用户记录、API Key 或签名文件。上传后核对文件大小、完整 SHA-256 与尾部 Range 下载；具体操作遵循服务器使用说明。

游戏没有自动下载或自更新后台程序，用户通过官网选择安装更新。
