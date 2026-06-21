<!-- 一个 PR 一件事。面向用户的变更记得在 CHANGELOG.md 的 Unreleased 加一行。 -->

## 这个 PR 做了什么

<!-- 一两句说清动机 + 改动 -->

## 类型

- [ ] feat（新能力）
- [ ] fix（修 bug）
- [ ] chore / docs / perf
- [ ] 启动器逻辑（`backends/`）
- [ ] 模型升级（`ccb.config.example` + `cc-model-registry.tsv`）

## 自检清单

- [ ] `make ci` 本地通过（scan + lint + test）
- [ ] **没有真 key 进仓**（`ccb.config*` 的 `key=` 全是 `<PLACEHOLDER>`）
- [ ] 动了启动器的话，公共逻辑进了 `cc-model-lib.sh`，没在 head 里复制
- [ ] 面向用户的变更已记 CHANGELOG
- [ ] 没引入 Gemini 依赖

## 备注

<!-- 默认/旗舰档变更请说明理由；其它需要 reviewer 注意的点 -->
