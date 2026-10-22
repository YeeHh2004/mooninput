# MoonInput

[![CI](https://github.com/YeeHh2004/mooninput/actions/workflows/ci.yml/badge.svg)](https://github.com/YeeHh2004/mooninput/actions/workflows/ci.yml)
[![MIT](https://img.shields.io/badge/license-MIT-176b50)](LICENSE)

**MoonBit 原生、可组合的结构化输入编辑库。** 用动态掩码、正则、自定义校验、命名区块和重复规则构建输入约束，统一处理显示值、原始值、完整值、选区与光标。

[在线体验](https://yeehh2004.github.io/mooninput/) · [Mooncakes / API](https://mooncakes.io/docs/YeeHh2004/mooninput) · [0.2 升级说明](docs/UPGRADE-0.2.md) · [IMask 功能范围对照](docs/IMASK-COVERAGE.md) · [接入文档](docs/API.md) · [验收导航](docs/REVIEW.md)

0.2 将原有的固定格式扩展为可复用规则模型：一个字段可随内容切换规则，业务可提供自己的字符定义与校验器，已有规则可以嵌套组合。参考 IMask 的通用功能范围，以 MoonBit 实现；配置语法与 API 有明确差异，完整能力及限制见[对照表](docs/IMASK-COVERAGE.md)。

0.2.1 加固了实际接入路径：快照恢复会同时验证 raw、display 与选区，协议携带可选显示文本以保留组合分区；数值片段粘贴、日期数字后缀、深层规则更新与正则 UTF-16 续写限制均有回归检查。详见 [更新记录](CHANGELOG.md)。

## 可以解决什么问题

- **多规格标识与批量录入：** 动态选择短码／长码，以自定义字符定义、命名区块和有限重复表达业务格式。
- **参数、报价与测量值：** 组合枚举、整数范围和精确小数，配置小数点、分组、上下界，并读取各区块的完整值。
- **账户、表单与配置界面：** 用正则可行前缀及业务回调处理输入中的未完成／无效状态，支持选中替换、粘贴、中间修改和错误修复。
- **预约、登记与数据导入：** 配置日期顺序与范围；同一套规则既可绑定浏览器输入，也可在 MoonBit 或 CLI 中无界面格式转换。

规则编译、动态选择、校验、组合解析、数字／日期处理、编辑转换与 JSON 协议均使用 MoonBit。JavaScript 负责 DOM 事件、字段历史和 Node 文件 IO；没有外部服务、密钥或 JavaScript 规则引擎依赖。

## 安装

可复现基线：MoonBit compiler/core **`0.10.14+7d59c7ec9`**，支持 **JS、Wasm GC**。使用 `moon version --all` 核对版本，固定工具链步骤见[开发说明](docs/DEVELOPMENT.md)。

```sh
moon add YeeHh2004/mooninput@0.2.1
```

在 `moon.pkg` 中导入：

```moonbit
import {
  "YeeHh2004/mooninput" @input,
}
```

## 从规则组合开始

```moonbit
fn main {
  // 输入长度变化时，动态候选会重新选择。
  let identifiers = @input.dynamic([
    ("short", @input.pattern("##-##").unwrap()),
    ("long", @input.pattern("###-###").unwrap()),
  ]).unwrap()
  let short = @input.Editor::new(identifiers, initial="1234").unwrap()
  let longer = short.insert("5").unwrap()
  println(short.display()) // 12-34，旧快照保持可用
  println(longer.display()) // 123-45
  println(longer.active_mask().unwrap()) // long

  // 范围、字面量和命名区块组合成一个可编辑规则。
  let time = @input.composite([
    @input.Block("hour", @input.range(0, 23, width=2).unwrap()),
    @input.Literal(":"),
    @input.Block("minute", @input.range(0, 59, width=2).unwrap()),
  ]).unwrap()
  let value = @input.Editor::new(time, initial="2359").unwrap()
  println(value.display()) // 23:59
  // value.fields() 返回 hour=23、minute=59。

  // 使用者的 MoonBit 回调增加语义校验，无需增加硬编码掩码类型。
  let checksum = @input.with_validation(
    @input.pattern("####").unwrap(),
    raw => {
      if raw.length() < 4 { return @input.Incomplete }
      let mut sum = 0
      for c in raw { sum += c.to_int() - 48 }
      if sum % 10 == 0 {
        @input.Complete
      } else {
        @input.Invalid("checksum must be divisible by ten")
      }
    },
  )
  println(@input.pipe(checksum, "1216", unmask=true).unwrap()) // 1216
}
```

示例的 `unwrap` 面向已知合法配置；实际应用应处理 `Result`。语法错误会拒绝整次编辑，语义无效值可以保留并继续修改，`value()` 仅返回完整有效值。所有位置使用 UTF-16 偏移，覆盖 JS 和 Wasm GC；字符规则按 Unicode 标量工作，不声称完整字素簇导航。

可运行样例 [examples/rules](examples/rules) 展示动态、组合、自定义定义、正则、重复、小数、日期、函数校验与显示配置；[examples/basic](examples/basic) 保留基础输入编辑示例。

```sh
moon run examples/rules --target js
moon run examples/rules --target wasm-gc
moon run examples/basic --target wasm-gc
```

## 核心能力

| 入口 | 复用方式 |
| --- | --- |
| `dynamic`、`active_mask` | 自动或回调分派多个候选，编辑后重新计算当前规则 |
| `composite`、`Block / Literal / Optional`、`fields` | 命名、嵌套和可选区块；返回区块的完整值 |
| `repeat(mask, min, max)` | 有限重复，保留最后一个区块的未完成状态 |
| `pattern`、`definition` | 内置字符槽位、自定义接受／归一化函数、固定分隔符和可选后缀 |
| `custom`、`with_validation / with_prepare / with_value` | 自定义状态、语义校验、输入预处理与完整值后处理 |
| `regex(source, max_length=...)` | MoonBit NFA 正则子集及可行前缀检查；有界规则可参与组合 |
| `range`、`enumeration` | 固定宽度整数范围与 autofix、有限枚举与大小写策略 |
| `number`、`date` | 精确十进制字符串、地区格式与上下界；可配置公历日期顺序与边界 |
| `presentation` | 显示占位符、隐藏可编辑字符；直接 Pattern／`iso_date` 支持 eager 字面量 |
| `Editor`、`pipe` | 不可变编辑、选区替换、删除、覆盖／跳过策略、重新归一化和无界面转换 |

旧入口 `decimal`、`iso_date` 保留。Pattern 中 `#` 为 ASCII 数字，`A` 为英文字母，`*` 为字母数字，`X` 为可打印 Unicode 标量；默认 `A/*` 转大写。多个／嵌套可选区块通过组合 API 表达。

`display()` 是显示文本，`raw()` 是可编辑内容，`value()` 是完整提交字符串；组合值可以包含字面量，数字采用标准点号十进制，配置日期输出 ISO 日期。应按用途读取 `fields()`，不能假设这几种值相同。详细合同、资源限制和未实现项见 [API](docs/API.md)、[行为边界](docs/BEHAVIOR.md) 与 [IMask 范围对照](docs/IMASK-COVERAGE.md)。

## 浏览器体验与接入

[在线演示](https://yeehh2004.github.io/mooninput/) 包括 **6 个扩展规则场景、10 种可修改 JSON 预设**，以及原有 3 个业务演示和 Pattern 工作台。可以直接编辑动态标识、用户名、组合时间、十六进制、地区小数和自定义日期，查看当前分支、区块值及完整引擎状态。JSON 工作台允许嵌套规则；错误配置保留当前输入。

无需安装 MoonBit 的体验方式：下载 [Release](https://github.com/YeeHh2004/mooninput/releases/latest) 的对应版本预编译包，解压后使用 **Node.js 22+** 运行 `node scripts/serve.mjs`。包内附源码、许可证、编译信息和校验和。

从源码构建需要 Node.js 22+ 和上述固定 MoonBit 版本，运行时无需 npm 依赖：

```sh
git clone https://github.com/YeeHh2004/mooninput.git
cd mooninput
node scripts/build.mjs
node scripts/serve.mjs
```

打开 **http://127.0.0.1:4173**。接入自己的页面时复制 `web/adapter.mjs`、构建出的 `web/mooninput.mjs`，并保留许可证与 notices：

```js
import {bindInput} from './adapter.mjs';
const binding = bindInput(document.querySelector('#identifier'), {
  kind:'dynamic',
  masks:[
    {name:'short',kind:'pattern',pattern:'##-##'},
    {name:'long',kind:'pattern',pattern:'###-###'}
  ]
}, {
  onChange(state) { console.log(state.display,state.status,state.active); },
  onAccept(state) { console.log('value changed',state.value); },
  onComplete(state) { console.log('complete',state.value); },
  onError(error) { console.log(error.message); }
});
// binding.setValue('123456'); binding.undo(); binding.redo();
// binding.updateOptions({masks:[/* 完整的新候选数组 */]});
// binding.reset(); binding.commit();
// 卸载时调用 binding.destroy()。
```

使用文本型 input 和 `inputmode`；`type=number/date` 不提供所需的文本选区接口。适配器处理粘贴、组合输入结束、原生回填、撤销／重做和表单重置。`updateOptions` 失败保留原配置和状态，成功后清空旧规则历史；新旧配置包含数字／日期规则时，包括嵌套在组合、动态候选或包装规则中的情形，若更新会改变当前完整提交值，也会拒绝，应先清空或显式转换。JSON 使用声明式规则与固定处理模式；任意业务回调通过原生 MoonBit API 提供。

浏览器快照与历史保留显示文本，能恢复原先明确输入的组合分区。原生调用可使用 `Editor::restore(mask, raw, display, start, end)`；它会重新验证快照，拒绝不匹配的文本或非法选区。等值 raw 替换保留原分区；改变 raw 的编辑仍按已声明的分区规则解析。仅保存 raw 不能唯一还原所有变长组合。原生表单重置失败时也会恢复重置事件开始前的内容和选区。

`number(pad_fraction=true)` 在编辑时仅为完整提交值补零；顶层 JSON 数字绑定在显式 `commit()` 或失焦后将补零写入显示与编辑内容。输入中的生成字符不会提前改变下一次键入的数值。日期配置也可以使用 `YYYY年MM月DD日` 等字面量格式，完整值仍为 ISO 日期。

## CLI 与无界面复用

将下列配置保存为 `config.json`，可在 Node 中使用同一个编译核心：

```json
{
  "kind": "dynamic",
  "masks": [
    {"name": "short", "kind": "pattern", "pattern": "##-##"},
    {"name": "long", "kind": "pattern", "pattern": "###-###"}
  ]
}
```

```sh
node cli/mooninput.mjs --config config.json 123456
node cli/mooninput.mjs --replay examples/events.json
node cli/mooninput.mjs --date 2026-10-15
node cli/mooninput.mjs --decimal 9007199254740993.10
node cli/mooninput.mjs --pattern "AA-####" ab1234
```

`--config` 读取声明式配置，`--replay` 读取配置及逐步编辑操作，输出引擎状态和轨迹。也可在 MoonBit 中直接使用 `pipe`，无须维护编辑器或 DOM。退出码：`0` 成功，`1` 编辑被拒绝或单值未完成／无效，`2` 参数、文件或规则错误。

## 验证与发布

```sh
moon fmt --check
moon check --target js
moon check --target wasm-gc
moon test --target js
moon test --target wasm-gc
moon build --target wasm-gc
node scripts/build.mjs
node --test tests/*.test.mjs
node scripts/check-consumer.mjs
node scripts/check-examples.mjs
python scripts/check-mooncake.py
```

[CI](.github/workflows/ci.yml) 在 Linux／Windows 执行检查、构建和测试，验证独立消费者、两个后端的示例输出与发布包内容。110 项 MoonBit 测试在 JS／Wasm GC 上覆盖动态切换、自定义校验、组合／可选／重复、严格快照恢复、正则前缀与边界、精确数值、日期、显示映射及错误恢复；另有 30 项 Node 测试，含 12,000 次随机编辑模型对照、1,000 组小数往返和 4,800 个日期样本。

浏览器测试需要额外开发依赖；运行下列命令验证 Chromium，将环境变量 `BROWSER_ENGINE` 设为 `firefox` 或 `webkit` 可选择其他引擎：

```sh
npm install
npx playwright install chromium firefox webkit
node tests/browser.mjs
node tests/advanced-browser.mjs
node tests/acceptance-browser.mjs
```

三个浏览器脚本共 91 项检查（基础 36、扩展 39、验收回归 16），CI 在三个引擎分别执行。[验证说明](docs/VERIFICATION.md) 记录复现方式；实际通过数量与证据以 [Actions](https://github.com/YeeHh2004/mooninput/actions) 对应提交为准。合成输入法事件和三种浏览器引擎测试不代表所有实体手机、输入法或辅助技术均已验证。

Mooncakes 分发 MoonBit 核心、协议包、测试、文档和可运行样例；网页、CLI 和开发工具在 GitHub。`node scripts/check-consumer.mjs --registry` 从公共注册表安装，核对源码并在 JS／Wasm GC 上构建运行。发行包与公开包的验证入口见[验收导航](docs/REVIEW.md)。

## 来源与许可

原创、AI 辅助实现，**MIT**。参考 [IMask 官方指南](https://imask.js.org/guide.html) 的通用功能分类，以 MoonBit 实现规则与编辑模型；未复制其源码，不宣称 JavaScript API 兼容或完整替代。来源与标准库许可见 [NOTICE](NOTICE.md)。生态查重范围及已有项目关系见 [SELECTION](docs/SELECTION.md)。

本库处理字段输入及完整值，不替代跨字段、服务端或真实身份验证，也不执行支付。隐藏字符仅改变视觉显示，调用方仍可读取 raw/value。

## English

MoonInput is a composable structured-input editing library written in MoonBit, targeting JavaScript and Wasm GC. It provides dynamic masks, custom definitions and validation callbacks, named composite and repeated blocks, a prefix-aware NFA regex subset, ranges, enums, exact decimal strings, configurable Gregorian dates, presentation options and immutable UTF-16 editing. A browser adapter and Node CLI share the compiled engine. Version 0.2 broadens the original fixed-format scope; the [IMask feature matrix](docs/IMASK-COVERAGE.md) describes implemented behavior and remaining differences without claiming API compatibility.
