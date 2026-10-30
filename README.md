# Somnicard

面向安卓的竖屏德州扑克练习游戏：本地 / 模型对手、同桌教练、逐手复盘、主题训练与学习课程。使用虚拟筹码，不含现金下注、支付或真人网络桌。

## 当前状态

当前可下载 **[2.0.1 试用 APK](https://mygit.nightricecake.com/downloads/somnicard/somnicard-2.0.1-debug.apk)**。沿用测试版包名与签名，直接覆盖安装，保留本机数据。已验证覆盖升级和公网完整下载。

- [真实 AI 行为测试与修复范围](docs/test-ai-behavior-2.0.1.md)：CommandCode DeepSeek V4.1 Flash 与 GPT-6 Luna 各 50 次请求。
- [三档难度到底怎样工作](docs/ai-difficulty.md)：在线目标提示与本地策略的区别，以及尚未完成的客观标定。

用户决定暂不正式发布；专用正式签名和官网产品页发布延期。课程、主页、帮助、音效、性能设置和后台渲染修复已包含在本次试用包。

- [2.0 版本说明与发布门槛](docs/release-2.0.0.md)
- [本轮测试证据与未覆盖范围](docs/test-product-2.0.0.md)
- [发布、签名与升级流程](docs/release-engineering.md)
- [产品路线](docs/roadmap.md)
- [历史版本记录](docs/version-history-before-2.0.md)

## 游戏内容

- 2–9 人完整无限注德州练习桌，逐个对手选择名字、三档难度与激进程度；50/100/200 BB 深度，固定 5/10 盲注，无前注和抽水。
- 四轮下注、合法加注、全押、边池与平分、摊牌、输赢提示、连续牌局、后台暂停及恢复；筹码 / BB 随时切换。
- 牌桌内悬浮教练与决策分析，按当时已知信息估算权益与范围；结算后可直接复盘本手。
- 历史 ID、搜索、筛选、收藏、备注、逐步回放、关键决策跳转与分支重打；训练先作答再看解释。
- 8 个学习主题、24 个具体决策题，记录课程进度并衔接主题训练；手动导入 / 导出牌局及学习备份。
- 可选兼容模型接口，预设提供商、自动模型列表、同桌不同模型、长期陪练、座位气泡、请求记录和失败恢复。密钥可选 Android Keystore 加密保存。
- 音效、震动、减少动效、四色花色、高对比显示和省电模式；首页提供分类设置、隐私、帮助、许可及主动复制的诊断摘要。

CFR 分析仅覆盖双人河牌抽象范围和有限下注树，不是完整多人 GTO。本地对手档位不映射真人段位；在线模型实际质量须在具体服务上评测。详见 [策略说明](docs/strategy.md) 和 [对手评测](docs/opponents.md)。

## 本地开发

Godot 4.7.2，Windows PowerShell。环境路径见 [开发环境](docs/environment.md)。

```powershell
# 运行游戏
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1
# 全部规则、UI、存档、策略回归与启动检查
powershell -ExecutionPolicy Bypass -File .\tools\check.ps1
# 开发调试 APK；不是正式发行构建
powershell -ExecutionPolicy Bypass -File .\tools\export-android.ps1
```

开发日志、模拟器记录及候选工程存放在忽略的 `.local/`，输出包在 `builds/`。签名密钥不得进入项目目录。

## 代码入口

| 位置 | 职责 |
|---|---|
| `scripts/main.gd` | 导航、牌桌流程、对手任务与存档协调 |
| `scripts/poker/` | 规则、牌型、策略、历史、复盘与训练数据 |
| `scripts/ai/` | 模型适配、对手与教练请求、记忆和密钥 |
| `scripts/product/academy.gd` | 有限、可审核的课程与进度规则 |
| `scripts/ui/` | 竖屏牌桌、首页、课程、设置、教练与帮助 |
| `native/android/` | 加密密钥插件和 Android 渲染生命周期修复 |
| `tests/` | 规则 / UI 回归和隔离安卓测试入口 |
| `tools/` | 构建、资源生成、截屏、测试及发布核验 |
| `site/` | 官网静态源文件与 Somnicard 路由配置参考 |

桌面数据位于 `%APPDATA%/Godot/app_userdata/Somnicard`；Android 数据属于各自安装包。完整备份包含隐藏底牌，请妥善保存。AI 配置、密钥、陪练与当前普通牌桌不包含在学习备份里。游戏不自动上传数据或诊断。
