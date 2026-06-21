# Contributing

欢迎 PR。这是一套把国产模型后端 + 多 Agent 扇出编排 + 审查闭环 + 自动同步拼起来的工作流仓。

## 开发环境

```bash
git clone https://github.com/LeoLin990405/cn-cc-workflow
cd cn-cc-workflow

# 工具 (本地跑闸门用)
brew install shellcheck gitleaks        # 或 apt
pipx install pre-commit && pre-commit install   # 提交即自动扫
```

## 三道闸门（提交前必过）

| 闸门 | 命令 | 查什么 |
|---|---|---|
| 密钥 | `make scan` | 明文密钥指纹 + `ccb.config*` 的 `key=` 必须占位 |
| 脚本 | `make lint` | `bash -n` 语法 + shellcheck（走 `.shellcheckrc`） |
| 测试 | `make test` | cn-plugin 的 node 测试 |
| 全部 | `make ci` | 上面三者串跑（= CI 等价） |

`make help` 看所有目标。CI（`.github/workflows/ci.yml`）跑的就是这三道，本地 `make ci` 绿了 CI 基本就绿。

## 硬规矩

- **真 key 绝不进仓**。见 [SECURITY.md](SECURITY.md)。改 `ccb.config.example` 时 `key=` 只能写 `<PROVIDER_API_KEY>` 占位。
- **启动器改动**：`backends/bin/*-code` 是「瘦头 + 一行 `cc_model_launch`」结构；公共逻辑进 `cc-model-lib.sh`，别在每个 head 里复制。改完 `make lint` 必过。
- **模型升级**：改 `ccb.config.example` + `cc-model-registry.tsv`，别只改文档里的字符串。默认/旗舰档变更要在 PR 里说明理由（适配度/成本需人判断）。
- **shellcheck 误报**：`*-code` 的 `MODELS`/`CC_OPUS` 等被 sourced 的 `cc_model_launch` 跨文件消费，SC2034 在 `.shellcheckrc` 已禁；别为消警告删变量。
- **不引入 Gemini**：第二意见/审查走 Codex 或国产分身（工作流既定约定）。

## 提交规范

- 用 imperative + 类型前缀：`feat:` / `fix:` / `chore:` / `docs:` / `perf:`。
- 一个 PR 一件事。动 `backends/` 启动器逻辑的，附上 `make ci` 通过的证据。
- 面向用户的变更在 [CHANGELOG.md](CHANGELOG.md) 的 `Unreleased` 段加一行。
