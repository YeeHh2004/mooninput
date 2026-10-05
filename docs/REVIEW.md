# 三分钟体验与验收导航

MoonInput 解决的是多个行业共享的单字段输入编辑问题。电商和进销存需要精确数量、报价；预约和登记需要日期与编号；联系表单需要数字分组、粘贴和中间修改。业务系统提供自己的规则，MoonInput 负责编辑过程中的显示、原始值和选区，不依赖某一行业协议。

## 直接体验

打开 [在线演示](https://yeehh2004.github.io/mooninput/)：

1. 联系信息卡片点“填入示例”，选中中间四位并修改，再“预览提交”：显示保留分组，提交内容是纯数字。多输一位会提示并保留原内容。
2. 数量与金额卡片点“大数示例”，预览提交：`9007199254740993.10` 保持原精度。选中金额输入 `-` 时处于未完成状态，继续输入 `.5` 后提交值为 `-0.5`。
3. 预约与登记卡片点“试试无效日期”，将 `2023` 改成 `2024`：闰日错误解除，再提交日期与编号。每个场景的“重置”恢复默认值并清空本字段历史。

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
| 可运行样例 | [基础样例](../examples/basic)、[独立消费者](../examples/consumer)、在线三个业务场景 |
| 核心路径测试 | 39 项 MoonBit 测试、14 项 Node 测试与生成模型；三种浏览器引擎逐个执行 36 项检查，见 [验证方法](VERIFICATION.md) |
| 发布 Mooncakes | [包与 API](https://mooncakes.io/docs/YeeHh2004/mooninput)；[公开安装工作流](../.github/workflows/registry.yml) 在两个系统实际下载、构建和运行 |
| OSI 许可证与来源 | [MIT](../LICENSE)、[原创与参考说明](../NOTICE.md)、[标准库许可证](../licenses/MoonBit-core-LICENSE) |

最终运行状态以 [Actions](https://github.com/YeeHh2004/mooninput/actions) 对应提交结果为准；该导航说明证据位置，不代替主办方的审核。
