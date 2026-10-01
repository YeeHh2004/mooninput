# MoonInput

[![CI](https://github.com/YeeHh2004/mooninput/actions/workflows/ci.yml/badge.svg)](https://github.com/YeeHh2004/mooninput/actions/workflows/ci.yml)
[![MIT](https://img.shields.io/badge/license-MIT-176b50)](LICENSE)

**MoonBit 原生的结构化输入编辑库。** 处理手机号、日期、小数和业务编号输入中的格式、选区、光标与中间状态，同时输出显示文本和可提交的原始值。

[在线体验](https://yeehh2004.github.io/mooninput/) · [Mooncakes / API](https://mooncakes.io/docs/YeeHh2004/mooninput) · [接入文档](docs/API.md) · [行为边界](docs/BEHAVIOR.md) · [查重依据](docs/SELECTION.md)

## 解决什么问题

在中间插入、删除、粘贴、选择替换，以及输入法组合输入结束后，仍保持正确的值和光标。

- 联系信息：粘贴或编辑分组手机号，提交纯数字字符串。
- 数量与金额：编辑带分组的精确十进制文本，显式拒绝超出配置的小数位，保留 `-`、`.` 等未完成状态。
- 预约与登记：输入公历日期与自定义业务编号，区分未完成、完整有效、完整无效。

规则编译、日期检查、编辑转换、UTF-16 映射和 JSON 协议都使用 MoonBit。网页和 Node CLI 是事件/IO 适配层，没有外部服务或 API 密钥依赖。表单状态库可消费本库输出的值；与已有库的比较见 [SELECTION](docs/SELECTION.md)，不宣称生态绝对空白。

## 安装与最小示例

可复现基线：MoonBit compiler/core **`0.10.14+7d59c7ec9`**；核心支持 **JS、Wasm GC**。用 `moon version --all` 核对；安装与固定版本配置见 [开发说明](docs/DEVELOPMENT.md)。

```sh
moon add YeeHh2004/mooninput@0.1.0
```

在 `moon.pkg` 中加入：

```moonbit
import {
  "YeeHh2004/mooninput" @input,
}
```

```moonbit
let mask = @input.pattern("### #### ####").unwrap()
let editor = @input.Editor::new(mask).unwrap()
let filled = editor.insert("13800138000").unwrap()
println(filled.display()) // 138 0013 8000
println(filled.value().unwrap()) // 13800138000
let edited = filled.select(4, 8).unwrap().insert("9999").unwrap()
println(edited.display()) // 138 9999 8000
println(filled.display()) // 原快照仍为 138 0013 8000
```

示例里的 `unwrap` 用于已知合法数据；实际接入应处理 `Result`。完整可运行例子在 [examples/basic](examples/basic)，独立模块在 [examples/consumer](examples/consumer)。

```sh
moon run examples/basic --target wasm-gc
```

## 核心能力

| 入口 | 行为 |
| --- | --- |
| `pattern("AA-####[/**]")` | 数字、字母、可打印字符、分隔符、单个可选后缀 |
| `decimal(precision=2, signed=true)` | 精确小数字符串、千位分组、符号与中间状态 |
| `iso_date()` | `YYYY-MM-DD` 格式与 0001–9999 年公历检查 |
| `Editor::select / insert` | 选区替换、插入、格式化粘贴 |
| `Editor::backspace / delete_forward` | 删除选区或相邻可编辑字符 |
| `Editor::display / raw / value / status` | 显示值、原始值、完整值与状态 |
| `Editor::reconcile` | 组合输入/自动填充后的归一化与光标恢复 |

`#` 为 ASCII 数字，`A` 为英文字母，`*` 为字母数字，`X` 为可打印 Unicode 标量；字母自动转大写。反斜杠转义规则字符，`[ ]` 仅支持一个末尾可选段。位置统一使用 UTF-16 偏移。详细限制及歧义处理见 [BEHAVIOR](docs/BEHAVIOR.md)。

## 浏览器与 CLI

需要 Node.js 22+ 和上述固定 MoonBit 版本。运行示例不需要 npm 运行时依赖：

```sh
git clone https://github.com/YeeHh2004/mooninput.git
cd mooninput
node scripts/build.mjs
node scripts/serve.mjs
```

打开 **http://127.0.0.1:4173**。三个业务场景和自定义规则工作台使用同一份 MoonBit 编译产物。

```js
import {bindInput} from './adapter.mjs';
const binding = bindInput(document.querySelector('#amount'),
  {kind:'decimal', precision:2}, {
    onChange(state) { console.log(state.value, state.status); },
    onError(error) { console.log(error.message); }
  });
// binding.setValue('1234.50'); binding.undo(); binding.redo();
// 卸载时调用 binding.destroy()。
```

复制 `web/adapter.mjs` 与构建出的 `web/mooninput.mjs` 接入网页时，保留许可证与 notices。使用 `type=text`；`type=number` 不提供所需的文本选区接口。

CLI 由 Node 处理文件和参数，计算由编译后的 MoonBit 执行：

```sh
node cli/mooninput.mjs --date 2026-10-02
node cli/mooninput.mjs --decimal 9007199254740993.10
node cli/mooninput.mjs --pattern "AA-####" ab1234
node cli/mooninput.mjs --replay examples/events.json
```

退出码：`0` 成功，`1` 编辑被拒绝或单值未完成/无效，`2` 参数、文件或规则错误。回放输出每一步状态。

## 验证与发布

```sh
moon fmt --check
moon check --target js
moon check --target wasm-gc
moon test --target js
moon test --target wasm-gc
node scripts/build.mjs
node --test tests/*.test.mjs
node scripts/check-consumer.mjs
node scripts/check-examples.mjs
python scripts/check-mooncake.py
```

Linux/Windows CI 覆盖检查、构建、测试。包含 37 项 MoonBit 测试、独立消费者、12,000 次随机编辑模型对照、1,000 组精确小数往返、4,800 个日期样本和浏览器检查。当前结果见 [Actions](https://github.com/YeeHh2004/mooninput/actions)。

浏览器测试额外需要 `npm install`、`npx playwright install chromium`，再运行 `node tests/browser.mjs`。组合输入采用合成事件测试，不代表所有实体手机/输入法均已验证，见 [验证说明](docs/VERIFICATION.md)。

Mooncakes 分发 MoonBit 核心、协议包、测试、文档和可运行样例；网页、Node CLI 和工具保留在 GitHub。`node scripts/check-consumer.mjs --registry` 从公共注册表安装，并核对核心源码及两个后端的运行结果。

## 来源与许可

原创、AI 辅助实现，**MIT**。参考 IMask 展示的通用输入编辑需求，未复制其源码，也不宣称 API 兼容。完整说明见 [NOTICE](NOTICE.md)。不验证号码是否真实可用，不处理支付，不替代服务端业务校验。

## English

MoonInput is an immutable structured-input editing engine written in MoonBit. It handles pattern masks, exact decimal text, Gregorian date validity, selection replacement, deletion, formatted paste and UTF-16 caret mapping on JavaScript and Wasm GC. A browser adapter adds DOM events, composition deferral and bounded undo/redo; a Node CLI replays edits through the compiled engine. See the English [API](docs/API.md), [behavior contract](docs/BEHAVIOR.md) and [development guide](docs/DEVELOPMENT.md).
