# 三分钟体验与验收导航

MoonInput 0.2 将动态候选、正则、范围、枚举、函数校验与命名区块放进同一套可组合 MoonBit 模型。业务可定义并嵌套自己的规则，模型同时用于浏览器输入、无界面数据规范化和命令行回放。对初审反馈的逐项回应见 [升级说明](UPGRADE-0.2.md)，与 IMask 的具体能力和差异见 [功能对照](IMASK-COVERAGE.md)。

0.2.1 进一步加固快照恢复与历史、嵌套规则更新、数值片段粘贴、日期数字后缀及正则续写边界。`Editor::restore` 与协议的可选 display 经过核心重新验证，保留明确的组合分区；错误快照与会改变完整数值／日期含义的规则更新会被拒绝。

0.2.2 为快照增加经过核心验证的 replay，覆盖隐藏显示下的变长分区；等价规则更新保留字段含义和选区，后来的成功写入优先于延迟重置或旧组合输入，并修复可选区块前缀及嵌套字段命名冲突。

## 直接体验

打开 [在线演示](https://yeehh2004.github.io/mooninput/)：

1. 进入[可组合规则示例](https://yeehh2004.github.io/mooninput/#adv-examples)，在动态编号输入框先输入四位，再添加第五位：分组和当前规则名称变化；删除后候选重新选择。
2. 尝试范围组合时间、正则用户名、自定义十六进制字符、小数点逗号与日期顺序六张卡片；时间返回命名字段，小数提交值保持精确字符串，错误可继续编辑修复。
3. 在 JSON 工作台切换十种预设，或自行修改动态、组合、可选、重复、校验及展示配置。应用合法规则后输入；非法规则会提示并保留旧输入。查看完整引擎状态并尝试撤销／重做。

原来的三个基础场景也保留，便于检查手机号、精度与日期修复。业务回调并未写死在网页：运行 `moon run examples/rules --target wasm-gc`，可验证纯 MoonBit 自定义校验码、递增数字函数规则及其他构造器。

无需配置密钥或后端。离线体验可下载 [Release](https://github.com/YeeHh2004/mooninput/releases/latest)，解压后使用 Node.js 22+ 执行 `node scripts/serve.mjs`。纯 MoonBit 的可运行样例见 [examples/basic](../examples/basic)。

## 与现有生态的关系

Moonform 管理表单字段状态、验证时机和提交；MoonInput 负责字段内部的格式约束编辑、粘贴、选区及光标映射，两者可组合。String_zipper 提供通用文本存储，未承担这里的数字、日期和掩码规则。核心职责与通用撤销库也不同：本项目的历史仅为浏览器字段适配功能，不作为独立历史库申报。

检索范围、对应仓库与保留意见见 [SELECTION](SELECTION.md)。这是一项有边界的查重结果，不承诺未索引或后续出现的项目不存在。

## 逐项复现

| 验收要求 | 仓库证据与操作 |
| --- | --- |
| MoonBit 为主要实现语言，版本达标 | 规则、编辑转换、日期、小数和协议为 `.mbt`；[CI](../.github/workflows/ci.yml) 固定 compiler/core `0.10.14+7d59c7ec9` |
| 公开仓库、有效提交 | [源代码与历史](https://github.com/YeeHh2004/mooninput/commits/main/)；提交对应实际功能、测试与修复 |
| 结构清晰、核心功能完整 | [API](API.md)、[目录说明](DEVELOPMENT.md#structure)、[行为边界](BEHAVIOR.md) |
| README 安装、使用与示例 | [README](../README.md) 的版本化安装命令、MoonBit 代码、浏览器和 CLI 步骤 |
| CI 覆盖检查、构建、测试 | Linux/Windows 执行 moon check/build/test，另有接口、包内容及示例输出检查 |
| 可运行样例 | [基础样例](../examples/basic)、[十类规则与回调](../examples/rules)、[独立消费者](../examples/consumer)、六类扩展示例及 JSON 工作台 |
| 核心路径测试 | MoonBit 测试在 JS／Wasm GC 上执行，另有 Node 检查与独立参考模型；三种浏览器分别执行基础、扩展和验收回归脚本，实际数量与命名证据见 [验证方法](VERIFICATION.md) |
| 发布 Mooncakes | [包与 API](https://mooncakes.io/docs/YeeHh2004/mooninput)；[公开安装工作流](../.github/workflows/registry.yml) 在两个系统实际下载、构建和运行 |
| OSI 许可证与来源 | [MIT](../LICENSE)、[原创与参考说明](../NOTICE.md)、[标准库许可证](../licenses/MoonBit-core-LICENSE) |

最终运行状态以 [Actions](https://github.com/YeeHh2004/mooninput/actions) 对应提交结果为准；该导航说明证据位置，不代替主办方的审核。
