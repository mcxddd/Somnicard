# 资源来源

- 图标：`assets/icon.svg`，项目内原创矢量图形。
- 启动画面：`tools/generate-boot.gd` 将上述图标转换为引擎要求的 PNG；不人为延长启动等待。[引擎启动图格式说明](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-image)。
- 牌桌、筹码、扑克牌、头像、徽章、按钮和动效：`scripts/ui/` 内程序绘制。无第三方游戏截图或商标素材。
- 提示音：`assets/audio/*.wav`，由 `tools/generate-audio.py` 使用正弦波和固定随机种子的噪声合成，无外部采样。22,050 Hz、单声道、16 位 PCM，共 5 个短音效。
- 官网截图：来自本项目 `tools/audit-ui.py` 的实际游戏渲染，经 WebP 编码压缩，未添加不存在的游戏功能。
- 引擎及内置第三方依赖：Godot 4.7.2；游戏“帮助与关于 → 引擎与第三方许可”读取引擎许可证、组件版权和许可正文。
- `native/android/GodotApp.java`：基于 Godot Android 模板修改，保留原 MIT 版权声明；原生凭据插件为本项目代码。

本清单记录来源，不替用户决定整个项目的开源或商业授权方式。
