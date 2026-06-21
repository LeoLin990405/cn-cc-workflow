# 任务：国产 CC 分身「读文档 → 学习 → 重建」模型同步

你是 CC 国产分身 fleet 的模型维护 agent。目标：去读每家大模型公司**官方最新文档/发布**，学习其当前模型阵容与接入方式，然后**重建** `~/bin/<provider>-code` 启动器 + `~/bin/cc-model-registry.tsv`，让它们跟上最新。

## 硬规矩（必须遵守）
- **禁用 Gemini**：任何环节不准用 gemini（cc-gemini 行跳过，不研究、不改）。
- **改前必备份**：先 `mkdir -p ~/bin/.cc-launchers-bak.$(date +%Y%m%d-%H%M%S)` 并 `cp ~/bin/*-code ~/bin/cc-model-registry.tsv` 进去。
- **验证门**：任何要写入的模型/端点改动，先用 `curl` 对该 provider 的 Anthropic 端点活体验证（HTTP 200 才算数）。**没过验证的不准写**。
- **key 取法**：`zsh -lic "printf %s \"\$XXX_API_KEY\""`（key 在交互登录 shell 文件：~/.config/cc-model-secrets.env / .zshrc 等，优先级 secrets 文件最高）。绝不打印 key 明文。
- **测试在 CC 会话外**：直接 curl 验证；不要靠 `cc-* -p`（会话内 OAuth 泄漏会假 401）。

## 每个 provider 做什么
对 `~/bin/cc-model-registry.tsv` 里除 cc-gemini/cc-grok/cc-local 外的每个 provider：

1. **读官方文档**：用 WebFetch/WebSearch 读该行 `primary_source` 列的 URL + 搜 "<provider> latest coding models 2026 / Claude Code 接入"。提炼：
   - 当前**全部可用编码/文本模型** ID（排除纯 TTS/ASR/图像/视频/embedding）
   - **旗舰 / 推荐编码模型**是哪个
   - 正确的 **Anthropic 兼容 base_url**（端点变没变）
   - **已下线/废弃**的模型
   - 官方推荐的关键参数（max_output、thinking 开关、特殊 header 等）变化

2. **活体核**：对候选模型逐个 curl `<base_url>/v1/messages`（Anthropic 协议）验证 200。

3. **重建**（只写验证通过的）：
   - `~/bin/<provider>-code` 的 `MODELS=(...)` 数组：加新的、删实测 404/下线的。
   - 端点若变了：改脚本 `ANTHROPIC_BASE_URL` + registry。
   - **MODELS 数组、端点、明显失效项**可以直接改（已备份+已验证）。

4. **只提议不自动改**（写进报告，等人工拍板）：
   - **默认档 / Opus·Sonnet·Haiku 档位映射**的升级——新旗舰是否该当默认、放哪个 tier，要人判断适配性/成本。给出建议 + 理由。

## 结构
- 改完每个 provider 后跑 `bash -n ~/bin/<provider>-code` 确认语法。
- 全改完跑 `cc-sync cli`（保持版本最新）。

## 报告（写到 stdout，会进 ~/Library/Logs/cc-model-research.log）
逐 provider 列：读到的最新模型阵容 / 实测结果 / 已自动应用的改动 / **建议人工定的默认档升级**（带理由）/ 跳过原因。最后给一句总结：哪些 provider 有实质更新、哪些待人工决策。

注意保守：拿不准、文档读不到、验证不过的，**保持原样并报告**，不要瞎改。
