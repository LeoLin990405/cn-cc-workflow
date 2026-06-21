# Security Policy

## 密钥处理（本仓核心安全约束）

这个工作流编排多个国产模型 provider，**会接触 API key**。仓库的硬约束：

- **真 key 绝不进仓**。只存在 `~/.config/cc-model-secrets.env`（被启动器读取，最高优先级）或你项目本地的 `.ccb/ccb.config`（被 `.gitignore` 忽略）。
- 仓里只跟踪 `orchestration/ccb/ccb.config.example`，其 `key=` 字段一律是 `<PROVIDER_API_KEY>` 占位。
- `.gitignore` 忽略 `**/.ccb/ccb.config`、`*secrets*.env`、`.env*`。
- 每次提交/推送经三道闸门：
  1. `scripts/scan-secrets.sh` — 明文密钥指纹（`sk-`/`tp-`/zhipu 格式）+ `ccb.config*` 的 `key=` 必须是占位。
  2. `gitleaks`（`.gitleaks.toml`）— 全 git 历史扫描。
  3. CI 的 `secret-scan` job 二者都跑，红了不许合。
- 本地启用：`pipx install pre-commit && pre-commit install`，提交即自动扫。

### 万一 key 泄漏了

1. 立刻去对应 provider 控制台**吊销/轮换**该 key。
2. 用 `git filter-repo` 或 BFG 清理历史，force-push。
3. 不要只删一个 commit —— key 一旦推到公开仓即视为已泄漏，必须轮换。

## 漏洞上报

发现安全问题（密钥泄漏路径、注入、权限绕过等），请**不要开公开 issue**。
通过 GitHub Security Advisory（仓库 Security → Report a vulnerability）私下上报，
或邮件联系仓库所有者。会尽快响应。

## 支持范围

这是个人维护的工作流工具仓，best-effort 维护，无 SLA。
