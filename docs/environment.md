# 本机开发环境

检查日期：2026-10-21。

## 已验证工具

| 工具 | 版本 / 路径 |
| --- | --- |
| 操作系统 | Windows 11 x64 |
| Godot 标准版 | 4.7.2.stable.official.ed1daf0bf |
| Godot 目录 | `%USERPROFILE%\DevTools\Godot\4.7.2`（自包含模式，目录内有 `_sc_`） |
| 安卓导出模板 | `%USERPROFILE%\DevTools\Godot\4.7.2\editor_data\export_templates\4.7.2.stable` |
| Java | Temurin OpenJDK 21.0.12.1 |
| JAVA_HOME | `%LOCALAPPDATA%\Programs\Java\jdk-21.0.12.1+1` |
| Android SDK | `%USERPROFILE%\DevTools\Android\Sdk`（用户环境变量 `ANDROID_HOME`） |
| SDK Platform | Android 36 |
| Build Tools | 36.0.0（本次 APK 签名工具） |
| ADB | 37.0.1 |
| Git | 2.55.0.windows.3 |

Godot 压缩包和模板包已比对官方发布的 SHA-512 校验值。仅安装匹配版本的安卓模板文件（debug、release、Gradle source、version）；桌面开发直接通过编辑器运行。下载缓存位于 `%LOCALAPPDATA%\Somnicard\downloads`。

Godot 编辑器设置已自动识别 JDK 和 Android SDK，保存在 `%USERPROFILE%\DevTools\Godot\4.7.2\editor_data\editor_settings-4.7.tres`；安卓调试签名在同目录的 `keystores\debug.keystore`（测试版证书 SHA-256 `d12eb9b8…6c76`）。游戏运行数据（`user://`）不受自包含模式影响，仍在 `%APPDATA%\Godot\app_userdata\Somnicard`。

2026-10-31：工具链从 AppData 迁到 `%USERPROFILE%\DevTools`。原因是 Codex 桌面应用（MSIX）会把对 AppData 的写入重定向到它的私有目录，导致不同软件看到不同的 SDK、模板和签名；DevTools 不受这种重定向影响。用户环境变量 `ANDROID_HOME` 与 PATH 中的 SDK 路径已同步更新。

安卓导出使用内置模板，无需本轮安装 NDK、CMake 或配置 Gradle。未来使用原生插件或自定义 Gradle 构建时再核对所需组件。

## 验证结果

- 资源导入完成，无脚本解析错误。
- 无窗口启动检查通过，测试发牌回调正常。
- 通过实际 OpenGL 渲染生成截图，检查桌面中文与布局正常。
- 调试 APK 导出成功，Godot 的签名校验通过。
- APK：`builds/android/somnicard-debug.apk`，57,025,468 字节（初始环境验证版）。
- 包名：`com.somnicard.practice`；版本：`0.0.1`。
- 最低 API：24；目标 API：36；架构：arm64-v8a、x86_64。
- Manifest 包含主界面的启动别名与 MAIN / LAUNCHER intent。
- 未检测到连接的安卓设备，尚未进行真机安装、触屏或性能验证。

## 下一次开始

1. 运行 README 中的编辑器命令，在 Godot 中按 F5。
2. 当前版本已进入完整双人牌桌，使用跟注/加注等按钮开始练习。
3. 连接安卓手机并授权 USB 调试，安装 APK 验证设备。

## 0.1.0 完整牌局更新

以上 0.0.1 包大小与截图记录属于环境搭建阶段。0.1.0 阶段曾生成 versionCode 2 的调试 APK，57,054,627 字节。该阶段规则测试 8,156 项断言通过（含 270 手、2–9 座位模拟），UI 集成 25 项检查通过，完整牌局启动检查通过。实际渲染已检查翻牌前与摊牌画面；APK 签名校验通过。

## 0.2.0 多人牌桌更新（2026-10-22）

当前 APK 为 versionCode 3 / versionName 0.2.0，57,075,580 字节。已重新导出并通过签名校验，确认包含三个新的 UI 模块，且未包含 tests、tools、docs 或 .local 调试资源。

最后一轮完整检查：270 手规则模拟、8,149 项规则检查、25 项原有 UI 集成检查、24 手牌局的 1,253 项多人 UI 检查以及启动检查均通过。多人 UI 检查数量会随随机发牌和行动次数变化。另已运行收起侧栏的手机布局测试。

已查看实际渲染的选桌页、2/6/9 人桌、16:9 画面和 1600×720 宽屏摊牌画面。新增测试涵盖 BB 单位转换、半池/满池快捷操作、非法加注禁用、暂停/恢复、取消换桌、键盘焦点限制、座位边界及互不重叠。

ADB 仍未检测到安卓设备；APK 可安装，但真机触屏、字体、性能和屏幕安全区尚待设备验证。
