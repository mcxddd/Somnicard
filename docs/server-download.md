# 手机浏览器下载

## 当前试用版 2.0.1

[直接下载 2.0.1 试用 APK](https://mygit.nightricecake.com/downloads/somnicard/somnicard-2.0.1-debug.apk)。覆盖安装即可，勿卸载旧版；保留现有数据。

2026-10-24：提供 2.0.1（versionCode 27，63,147,804 字节），修复 AI 公开观察事实遗漏、过期对白与 CommandCode DeepSeek 参数识别。23 套全游戏回归通过，最后参数修正追加 AI 331 项、行为 21 项检查通过。真实请求各 50 次的范围与限制见 [AI 行为测试](test-ai-behavior-2.0.1.md)，最后的 DeepSeek 参数修正未追加实连。Android 14 覆盖安装保留全部 8 个旧存档文件，冷启动无脚本/Java 错误；未做本版实体手机验收。签名沿用，ZIP CRC、ZIP/ELF 16 KB 对齐通过。公网完整下载逐字节一致，HEAD 200、尾部 Range 206 一致。SHA256 `1f7df0bc080661057b9b340c8311ca46e97b20345a7eb6787b9deadeece26ba1`。只添加 APK 与校验文件，旧 2.0.0 未变，未改服务器配置或服务，临时上传目录已清理。回执为 `builds/android/somnicard-2.0.1-server-validation.json`。

## 2.0.0 试用记录

2026-10-23：按用户要求暂不正式发布，提供 2.0.0 试用 APK（versionCode 26，63,145,224 字节）。沿用 com.somnicard.practice 与原测试签名，Android 14 实际覆盖安装成功，安装前后原牌桌存档摘要相同。公网完整下载逐字节一致，HEAD 200、尾部 Range 206 一致，ZIP CRC 与 ZIP / ELF 16 KB 对齐通过。SHA256 `4ea47e7399724079eb2583801093f9b3f5f238e819336d2b2fb548c757fbbffa`。仅添加 APK 与校验文件，旧 1.13.0 保留，未改配置、服务或 DNS。正式签名及官网产品页发布延期；不需要用户先决定正式身份就能试用。

## 之前的版本

安装包已发布到用户现有 kimchi 服务器，通过 HTTPS 直接下载，不需要登录。

- [Somnicard 1.13.0 调试 APK](https://mygit.nightricecake.com/downloads/somnicard/somnicard-1.13.0-debug.apk)
- [SHA256 校验文件](https://mygit.nightricecake.com/downloads/somnicard/somnicard-1.13.0-debug.apk.sha256)

版本号 1.13.0，versionCode 25，文件大小 63,081,542 字节（约 60.1 MiB）。这是支持可选在线 AI 的练习版的调试安装包，不是应用商店正式发布版。

SHA256：`3868dc2ca706b1628b6ced178f738bec16ae955c86076fb354f2d971a46f7159`

2026-10-23 验证：从公网完整下载并逐字节比对一致；HTTPS HEAD 返回 200，内容类型为 Android APK，附件下载与 Range 206 正常。本次仅增加版本文件，未修改服务器配置。已完成 Android 14 / 16 模拟器验收；实体手机体验仍由用户后续确认。

1.4.0 已于 2026-10-22 发布：公网完整下载 57,209,689 字节，SHA256 一致；末尾 1024 字节续传返回 206 且一致。沿用同一签名，versionCode 升至 9。仅添加两个新版本静态文件，1.3.0 保留；未改网关、服务或 DNS。用户已确认 1.3.0 安装成功，1.4.0 尚待用户手机体验。新回执为 `builds/android/somnicard-1.4.0-server-validation.json`。

1.4.1 于 2026-10-22 发布：公网完整下载 57,213,946 字节与本地一致；末尾 1024 字节 Range 206 内容一致。v2/v3 签名与旧版一致、16 KB 对齐、ZIP 完整性通过，versionCode 10。保留 1.3.0 / 1.4.0 文件，未更改服务器配置。验证回执为 `builds/android/somnicard-1.4.1-server-validation.json`。

1.4.2 于 2026-10-22 发布：公网完整下载 57,213,946 字节与本地逐字节一致；末尾 1024 字节 Range 206 一致。v2/v3 签名沿用、16 KB 对齐及 ZIP CRC 验证通过，versionCode 11。保留 1.4.1 原文件且摘要未变，未修改服务器配置。回执为 `builds/android/somnicard-1.4.2-server-validation.json`。

1.4.3 于 2026-10-22 发布：金额美术更新，versionCode 12。公网完整下载 57,222,625 字节与本地逐字节一致；末尾 1024 字节 Range 206 一致。签名沿用、16 KB 对齐、ZIP CRC 通过；1.4.2 摘要未变，未修改服务器配置。回执为 `builds/android/somnicard-1.4.3-server-validation.json`。

1.4.4 于 2026-10-22 发布：教学手势修复、具体决策讲解与历史组合筛选，versionCode 13。公网完整下载 57,235,251 字节逐字节一致；末尾 1024 字节 Range 206 一致。签名沿用、16 KB 对齐、ZIP CRC 通过；1.4.3 摘要未变，未修改服务器配置或重启。临时上传目录已清理。回执为 `builds/android/somnicard-1.4.4-server-validation.json`。

1.5.0 于 2026-10-22 发布：复盘标记、主题训练、可继续对战的重打分支、个人报告与本地备份，versionCode 14。公网完整下载 57,285,236 字节逐字节一致；末尾 1024 字节 Range 206 一致。签名沿用、16 KB 对齐、ZIP CRC 通过；1.4.4 摘要未变，未改配置或重启。临时上传目录已清理。回执为 `builds/android/somnicard-1.5.0-server-validation.json`。

1.6.0 于 2026-10-22 发布：独立对手难度 / 风格配置、三档策略重构和可复测牌力报告，versionCode 15。公网完整下载 57,302,157 字节逐字节一致；末尾 1024 字节 Range 206 一致。签名沿用、16 KB 对齐及 ZIP CRC 通过；1.5.0 摘要未变，未改配置或重启，临时上传目录已清理。回执为 `builds/android/somnicard-1.6.0-server-validation.json`。

1.6.1 于 2026-10-22 发布：座位配置按钮重复累积与旧目标残留修复，versionCode 16。公网完整下载 57,302,157 字节逐字节一致，末尾 1024 字节 Range 206 一致；签名沿用、16 KB 对齐和 ZIP CRC 通过。旧 1.6.0 摘要未变，未改配置或重启，临时上传目录已清理。回执为 `builds/android/somnicard-1.6.1-server-validation.json`。

1.6.2 于 2026-10-22 发布：对手范围图滑动误选修复、选中占比固定显示，versionCode 17。公网完整下载 57,306,253 字节逐字节一致，末尾 1024 字节 Range 206 一致；签名沿用、16 KB 对齐和 ZIP CRC 通过。旧 1.6.1 摘要未变，未改配置或重启，临时上传目录已清理。回执为 `builds/android/somnicard-1.6.2-server-validation.json`。

1.7.0 于 2026-10-22 发布：独立主界面、设置分类、训练分栏与导航重构，versionCode 18。公网完整下载 57,314,761 字节逐字节一致，末尾 1024 字节 Range 206 一致；签名沿用、16 KB 对齐和 ZIP CRC 通过。旧 1.6.2 摘要未变，未改配置或重启，临时上传目录已清理。回执为 `builds/android/somnicard-1.7.0-server-validation.json`。

1.8.0 于 2026-10-22 发布：在线 AI 对手、独立会话记忆、长期陪练、桌边发言与错误恢复，versionCode 19。公网完整下载 57,352,404 字节逐字节一致，末尾 1024 字节 Range 206 一致；签名沿用、16 KB 对齐和 ZIP CRC 通过。Android INTERNET 权限已开启，只有主动测试或在线座位才请求服务。旧 1.7.0 摘要未变，未改配置或重启，临时上传目录已清理。回执为 `builds/android/somnicard-1.8.0-server-validation.json`。真实模型服务与安卓体验尚待用户配置后确认。

1.9.0 于 2026-10-22 发布：河牌面对下注与一次再加注求解、模型 EV 对照、决策教学、提供商预设与模型关联昵称，versionCode 20。公网完整下载 57,369,279 字节逐字节一致，末尾 1024 字节 Range 206 一致；签名沿用、16 KB 对齐和 ZIP CRC 通过，16 项测试套件及启动检查通过。旧 1.8.0 摘要未变，未改配置或重启，临时上传目录已清理。回执为 `builds/android/somnicard-1.9.0-server-validation.json`。真实模型服务与安卓体验仍待用户配置后确认。

1.10.0 于 2026-10-23 发布：AI 配置自动获取与搜索模型、移除技术参数开关、CommandCode 预设及 Messages 自动适配，versionCode 21。公网完整下载 57,377,626 字节逐字节一致，末尾 1024 字节 Range 206 一致；签名沿用、16 KB 对齐、ZIP CRC 通过，16 项测试套件及启动检查通过，其中 AI 专项 236 项检查通过。旧 1.9.0 摘要未变，未改配置或重启，临时上传目录已清理。回执为 `builds/android/somnicard-1.10.0-server-validation.json`。真实模型生成与安卓体验仍待用户配置后确认。

2026-10-23 更新 1.11.0：多模型同桌、独立 AI 教练、系统密钥保护、关键决策训练、分批牌力评测及精细河牌抽象。仅添加 APK 与 SHA256 文件。公网完整下载 63,056,736 字节逐字节一致，末尾 1024 字节 Range 206 一致；1.10.0 摘要未变。Gradle 原生插件构建沿用同一签名证书，v2 签名、ZIP 16 KB 对齐、ELF 加载段 16 KB 对齐、ZIP CRC 通过。17 个测试套件及启动检查通过，AI 专项 312 项、新版专项 27 项。完成本地 21,312 手牌与六个河牌抽象的独立 LP 核对。未改配置或重启；临时上传目录已清理。真实服务评测与安卓密钥读写 / 触摸仍未真机验收。 回执为 `builds/android/somnicard-1.11.0-server-validation.json`。

2026-10-23 更新 1.11.1：全游戏回归后修复训练室紧凑多人桌下注遮挡，versionCode 23。19 个测试套件与启动检查全部通过，共 170,473 项断言；新增压力测试完成 2,795 手、12,537 次动作与 1,530 次中途恢复，检查 16 个实际渲染场景。公网完整下载 63,058,316 字节与本地逐字节一致，末尾 1024 字节 Range 206 一致；1.11.0 摘要未变。沿用签名证书，v2 签名、ZIP / ELF 16 KB 对齐、ZIP CRC 与原生插件检查通过。仅添加 APK 与 SHA256 文件，未改配置或重启，临时上传目录已清理。未进行真机与真实模型调用测试。 回执为 `builds/android/somnicard-1.11.1-server-validation.json`，覆盖范围见 [全游戏测试记录](test-audit-1.11.1.md)。

2026-10-23 更新 1.12.0：本地对手名字与改名、当前牌局对白、安卓返回及设置软键盘避让修复，versionCode 24。20 个自动测试套件与启动检查通过，安卓修复后追加新版 43 项、导航 224 项、跨功能 1,606 项回归。官方 Android 14 / 16 模拟器各 441 项验收通过，实际验证覆盖更新、安卓返回、后台恢复、软键盘输入与原生 Keystore 的保存 / 重启读取 / 篡改拒绝 / 删除。公网完整下载 63,063,011 字节逐字节一致，末尾 1024 字节 Range 206 一致；1.11.1 摘要未变。同一证书 v2 签名、ZIP / ELF 16 KB 对齐、ZIP CRC 与原生插件核验通过。仅添加 APK 与 SHA256 文件，未改配置或重启，临时上传目录已清理。实体手机与真实外部模型的质量 / 牌力仍未测试。 回执为 `builds/android/somnicard-1.12.0-server-validation.json` 与 `somnicard-1.12.0-android-validation.json`，范围见 [安卓验收](test-android-1.12.0.md)。

## 后续维护

### 下载到末尾停住的排查记录

2026-10-22，用户报告安卓 Edge 显示已下载 57.19 MB / 57.19 MB，但任务未完成。重新从公网下载原链接，57,188,573 字节与本地安装包逐字节一致；末尾 65,536 字节和最后一个字节的 Range 请求均返回 206，内容一致。使用 `?download=20261022-02` 的新链接首次返回 Cloudflare MISS，完整下载约 15.9 秒，SHA256 一致。验证回执位于 `.local/server-release/download-stall-check.json`。

目前未复现手机 Edge 的卡住现象，也未确定原因；以上结果不能代替手机端验证。建议先检查 Edge 下载列表有无提示，再取消卡住的任务并使用新链接重试；如仍卡住，可用另一浏览器下载同一链接，帮助区分浏览器与网络路径问题。本次未改动服务器或安全设置。

服务器操作前读取 `C:\Users\macxd\Documents\kimchiserver\AGENTS.md`，其中记录当前生产密钥使用方式。旧 `Host kimchi` 配置引用的是另一把不可用密钥；不要读取、打印或复制任何私钥内容。

- 文件：`/opt/1panel/www/sites/mygit/downloads/somnicard/`。
- OpenResty 配置：`/opt/1panel/www/sites/mygit/proxy/somnicard-downloads.conf`。
- 配置回滚备份：`/var/backups/somnicard-download-20261022-015057/`。
- 原有 `mygit.conf`、`root.conf` 保持不变；本次无需修改 DNS、Tunnel 或部署额外容器。
- 下次发布使用新的版本文件名，先上传暂存文件并验证 SHA256，再原子放入公开目录，最后完整公网下载核对。不要覆盖同名历史版本；Cloudflare 缓存响应可能长于源站缓存时间。
- 此目录只保存可公开发布的安装包与校验文件，不放源码、存档、密钥或其他用户数据。

本次验证回执保存在 `builds/android/somnicard-1.3.0-server-validation.json`，不进入 APK。

2026-10-23 更新 1.13.0：模型触摸选择与搜索、生成截断有限重试、脱敏请求历史、座位对白气泡及 Android 16 重复返回修复，versionCode 25。21 套回归与启动检查通过，共 171,384 项断言；Android 14 / 16 各 468 项检查通过，两个系统覆盖安装后原存档摘要不变。公网完整下载 63,081,542 字节逐字节一致，末尾 1024 字节 Range 206 一致；1.12.0 摘要未变。签名沿用、ZIP / ELF 16 KB 对齐、ZIP CRC 通过。仅添加 APK 与 SHA256 文件，未改配置或重启，临时上传目录已清理。未验证实体手机及真实外部模型。 回执：`builds/android/somnicard-1.13.0-server-validation.json`。
