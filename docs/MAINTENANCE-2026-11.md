# 2026-11-11 工具链维护记录

本次维护针对 0.2.3 候选版本，只修复官方工具链更新造成的兼容问题，保留现有输入规则和 JS／Wasm GC 两个声明后端。本文记录本地复现结果；GitHub Actions、注册表发布和 Release 的状态须查看对应提交的实际运行结果。

## 实际环境

- Windows x86-64，Node.js `v24.22.1`，Python `3.9.13`。
- 官方 compiler/core：`0.10.20+65efd5b93`，编译器日期 `2026-11-05`。
- `moon`／`moonrun`：`0.1.20261104`，提交 `940aa18`，日期 `2026-11-04`。
- 工具链安装在独立目录，初始化标准库 bundle 后测试；没有覆盖原有安装。

```text
moon 0.1.20261104 (940aa18 2026-11-04)
moonc v0.10.20+65efd5b93 (2026-11-05)
moonrun 0.1.20261104 (940aa18 2026-11-04)
Feature flags enabled: rr_moon_mod,rr_moon_pkg
```

## 发现与修复

1. `moon check --deny-warn` 将旧的 `derive(...)` 写法视为已弃用语法，导致检查失败。使用同版官方 formatter 迁移为 `#derive(...)`，同时接受其 `Int32`、默认参数 `~` 和闭区间模式的规范写法，并重新生成公共接口。这些是现有声明的语法迁移。
2. JSON 协议两处 `String.to_json()` 调用报 `Type String has no method to_json`。改用显式 `Json::string(...)`，现有字符串值与动态规则名仍按 JSON 字符串传递。
3. `scripts/build.mjs` 原来只接受 `0.10.14+7d59c7ec9`，使新版工具链无法实际构建。移除此限制；构建现在打印完整版本输出，并在 `web/build-info.json` 中记录实际 compiler、core、moon 版本、源码提交和引擎 SHA-256。
4. 从本次官方 core 分发刷新 `licenses/NOTICE`；完整 LICENSE 内容与原副本相同。生成的网页／离线发行物从活动工具链的 `MOON_HOME/lib/core` 读取 NOTICE 与 LICENSE，避免使用另一版编译器时继续携带旧 notices。

## 本地验证结果

| 检查 | 结果 |
| --- | --- |
| `moon fmt --check` | 通过 |
| `moon check --target js --deny-warn` | 通过 |
| `moon check --target wasm-gc --deny-warn` | 通过 |
| `moon info` | 通过，公共接口已更新 |
| `moon test --target js --deny-warn` | 125／125 |
| `moon test --target wasm-gc --deny-warn` | 125／125 |
| `moon build --target wasm-gc` | 通过 |
| `node scripts/build.mjs` | JS release 构建通过，记录实际 `0.10.20+65efd5b93` |
| `node --test tests/*.test.mjs` | 33／33，含 12,000 次编辑模型对照、1,000 个精确小数和 4,800 个日期样本 |
| `node scripts/check-examples.mjs` | basic／rules 在两个后端的输出均相符 |
| `node scripts/check-consumer.mjs` | 独立 workspace consumer 两后端各 130／130（125 项库测试和 5 项 consumer 测试），运行输出相符 |
| `python scripts/check-mooncake.py` | 实际待发布 ZIP 检查通过，未上传 |
| Chromium 三套浏览器脚本 | 基础 36／36、扩展 39／39、生命周期验收 27／27，共 102 项 |
| 核心覆盖统计 | 编译器插桩点 1727／1833；这是插桩覆盖率，不代表完整语义覆盖 |

本次本地没有重复安装 Firefox／WebKit，也没有将本地 Windows 结果表述为 Linux 结果。主 CI 仍在 Linux／Windows 检查两个后端，并在 Linux 分别运行 Chromium、Firefox、WebKit；这些结果以新提交的 Actions 为准。`--registry` 消费者检查须在 0.2.3 实际发布后执行，本文不声称已发布或已通过新版本公共安装。

## 持续检查

[主 CI](../.github/workflows/ci.yml) 与[公开包检查](../.github/workflows/registry.yml) 固定本次已验证的完整 compiler/core 版本，便于复现。[兼容 CI](../.github/workflows/compatibility.yml) 每周一及手动触发时使用官方 latest compiler/core，在 Linux／Windows 执行两个后端的检查、构建、测试，以及 Node、示例和独立 consumer；不发布或部署。

常规复现命令见[开发说明](DEVELOPMENT.md)。切换到独立安装时，设置 `MOON_HOME` 并把该目录的 `bin` 放在 PATH 最前，再以 `moon version --all` 核对活动工具链。
