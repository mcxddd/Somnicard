# 资源来源

- 图标：来自 `assets/branding/sleepy-card/`，矢量重绘的 sleepy card logo，由该目录的 `export.ps1` 生成 PNG。运行时使用 `assets/icon.png`、`assets/android/icon-192.png`（由 1024 像素图标使用 Pillow LANCZOS 缩放）、`assets/android/adaptive-foreground.png`、`assets/android/adaptive-background.png`、`assets/android/adaptive-monochrome.png`、`assets/logo-mark.svg` 和 `assets/wordmark.svg`；保留的站点测试素材使用 `site/images/logo-mark.svg` 和 `site/images/favicon.svg`，线上官网在服务器管理工作区构建后上传。
- 启动画面：来自 `assets/branding/sleepy-card/` 的矢量重绘 sleepy card logo，由该目录的 `export.ps1` 生成 `splash.png`，原样复制为运行时使用的 `assets/boot.png`；不人为延长启动等待。[引擎启动图格式说明](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-image)。
- 牌桌、筹码、扑克牌、头像、徽章、按钮和动效：`scripts/ui/` 内程序绘制。无第三方游戏截图或商标素材。
- 提示音：`assets/audio/*.wav`，由 `tools/generate-audio.py` 使用正弦波和固定随机种子的噪声合成，无外部采样。22,050 Hz、单声道、16 位 PCM，共 5 个短音效。
- 保留的站点测试截图：来自本项目 `tools/audit-ui.py` 的实际游戏渲染，经 WebP 编码压缩，未添加不存在的游戏功能。线上官网使用服务器管理工作区的概念插画。
- 引擎及内置第三方依赖：Godot 4.7.2；游戏“帮助与关于 → 引擎与第三方许可”读取引擎许可证、组件版权和许可正文。
- `native/android/GodotApp.java`：基于 Godot Android 模板修改，保留原 MIT 版权声明。

本项目代码与自制美术、音效素材按根目录 MIT 许可发布；Godot 引擎及内置第三方依赖保留各自许可与版权声明。
