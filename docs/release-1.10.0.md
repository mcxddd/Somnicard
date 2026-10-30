# Somnicard 1.10.0 · 自动获取模型与 CommandCode

AI 配置改为填地址与密钥后自动获取模型。JSON、请求参数名称、思考开关、输出上限和超时控件已移除；游戏负责选择与适配请求格式。对手名字、独立记忆、长期陪练、对局教学和复盘保持原有功能。

## 使用

1. 设置 → AI 服务与陪练，选择预设或填写接口地址，粘贴密钥。
2. 停止输入约 1.2 秒后自动获取列表。已有模型仍可用时保留选择，否则从返回列表选择默认项；可以搜索和更换。免密服务点击“获取模型”。
3. 可点击“测试所选模型”，再保存设置。设置 → 电脑对手，为需要的座位启用在线 AI。

服务目录中的模型不代表账号一定有调用权限；测试会实际请求所选模型。目录获取失败或服务未提供列表时可手动填写模型 ID。自动选用项优先保留已有选择、服务默认型号，再按名称优先选择 flash / mini / haiku / luna 变体；不声称它是最强或最便宜的模型。

## 适配

预设包含 CommandCode、DeepSeek、OpenAI、硅基流动、阿里云百炼及自定义服务。支持带服务前缀、完整请求路径的地址；自定义路径保留，只有裸域名默认补 `/v1`。模型发现使用相同服务的 `/models`，支持 `data`、`models` 和顶层数组，校验、排序、去重，并隐藏明确不适用于当前文字对话的模型。

CommandCode 使用 `https://api.commandcode.ai/provider/v1`。根据目录的 `supported_endpoints` 选择 Chat Completions 或 Anthropic Messages；Claude 的系统提示会分开提交，响应只取文字内容。目录中只有其他类型接口的模型不进入选择列表。当前不单独实现 Responses-only 或 System One 请求。

接口默认输出上限为 4096，决策请求超时 60 秒；列表请求最多 30 秒。已知服务按其兼容参数请求，通用服务优先使用最小请求体和结构化提示。只有服务明确拒绝 JSON、思考或令牌参数时，才在原地址按原模型进行有限兼容重试，最多额外 3 次；认证错误、限流、网络超时不会自动重发。成功配置仅在内存中按地址、模型和密钥摘要缓存。回复仍经过结构和合法动作校验。

改地址或密钥会清理旧目录并取消请求；跨域更换地址会清空旧密钥。离开页面、进入后台或取消设置会取消模型发现，迟到响应不能修改新草稿。密钥继续仅保留本次运行。保存在线对手配置前要求有合法地址和选定模型。

## 参考与验证

交互参考本地 DREAM2IM-RH 的 `fetchModels`：地址与密钥即可获取列表，选择模型后再测试。Somnicard 直接访问填写的服务，模型发现不发送牌局信息。

格式依据：[OpenAI 模型列表](https://developers.openai.com/api/reference/resources/models/methods/list)、[CommandCode Provider API](https://commandcode.ai/docs/provider)、[CommandCode BYOK 自动发现流程](https://commandcode.ai/docs/byok)。2026-10-22 已实际访问 CommandCode 公开目录，当时解析出 94 个可选模型；数量与内容以服务实时返回为准，未使用真实用户密钥调用生成服务。

16 项自动测试套件与完整牌局启动检查通过，其中 AI 套件 236 项检查通过。模拟 HTTP 测试覆盖模型目录 GET、鉴权、去重、搜索、刷新保留选择、自动获取、原始地址保留、取消与过期响应、兼容重试上限、凭据隔离、Messages 文字解析、六人 Chat Completions 及九人 Messages 完整牌局。已检查 360×640 与 390×844 的实际竖屏渲染。真实模型生成、安卓键盘和触摸体验仍待用户配置后测试。

## 安装

[下载 1.10.0 APK](https://mygit.nightricecake.com/downloads/somnicard/somnicard-1.10.0-debug.apk)。版本码 21，沿用原包名和签名，可以覆盖安装。发布校验见 [服务器下载](server-download.md)。

2026-10-23 已发布并从公网完整下载，57,377,626 字节与本地逐字节一致，末尾 1024 字节 Range 206 内容一致。SHA256：`11d833b5aef72cc9fd2bb6188b1a6658af67d377e93eebc13f691796ec95b225`。APK v2/v3 签名、16 KB 对齐、ZIP CRC 与 Android INTERNET 权限验证通过。旧 1.9.0 安装包保留且摘要未变；未修改服务器配置，上传暂存目录已清理。
