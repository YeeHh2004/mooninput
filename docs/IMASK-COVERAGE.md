# IMask 功能范围对照

MoonInput 0.2 参考 [IMask 官方指南](https://imask.js.org/guide.html) 的功能分类，以 MoonBit 重新实现结构化输入能力。下表描述本仓库的实际 API、实现入口和边界；**不表示 JavaScript API、配置语法或所有细节与 IMask 兼容，也不宣称已完整替代 IMask。**

所有规则计算在 MoonBit 中执行。浏览器负责事件、选区和历史；JSON 配置不执行 JavaScript 代码。原生 MoonBit 使用回调扩展业务规则，JSON 使用可序列化的声明式配置。核心同时服务无界面的格式转换、命令行和浏览器。

| 功能族 | MoonInput 实现与验证入口 | 当前边界 |
| --- | --- | --- |
| 无界面模型、编辑快照 | `Editor`、`Editor::restore`；[editor.mbt](../editor.mbt)、[snapshot.mbt](../snapshot.mbt)、[acceptance_core_test.mbt](../acceptance_core_test.mbt) | 不可变快照；恢复时严格验证 raw／display／选区；编辑失败保留旧值 |
| Pattern 与自定义字符定义 | `pattern`、`definition`；[pattern.mbt](../pattern.mbt)、[engine_rules_test.mbt](../engine_rules_test.mbt) | `#` 数字、`A` 字母、`*` 字母数字、`X` 可打印标量；语法与 IMask 不同 |
| 可选区段 | Pattern 末尾 `[ ... ]`；`composite` 的 `Optional` | Pattern 字符串仅单个可选后缀；多个／嵌套可选使用组合 API |
| 可复用命名区块与嵌套 | `composite`、`Block`、`Literal`、`Optional`、`Editor::fields`；[engine_rules.mbt](../engine_rules.mbt) | 有限容量和搜索预算；变长相邻区块按可完成的分区解析 |
| 重复区块 | `repeat(mask, min, max)`；[engine_rules_test.mbt](../engine_rules_test.mbt) | 有限重复，最多 32 次；未完成的最后一个区块不算完成次数 |
| 动态掩码 | `dynamic`、原生 `dispatch`、`Editor::active_mask` | 自动模式优先完整、再优先容量较小的候选，最终依声明顺序；与 IMask 的选择算法不相同 |
| 自定义函数掩码 | `custom`；[engine_rules_test.mbt](../engine_rules_test.mbt) | MoonBit 回调返回 `Empty / Incomplete / Complete / Invalid`；回调须确定、无副作用 |
| 组合语义校验 | `with_validation`；JSON `kind: "validate"` | 语法错误拒绝；语义无效值可保留编辑，提交值不可用；不包含跨字段／服务端校验 |
| 输入预处理 | `with_prepare`、`custom(prepare=...)`、`definition(normalize=...)` | 原生回调；JSON 另提供固定 trim／uppercase／lowercase 模式，不执行配置中的脚本 |
| 完成值后处理 | `with_value`、`Editor::commit(transform)`；[presentation_test.mbt](../presentation_test.mbt) | `with_value` 只转换完整值的提交结果；显式 `commit` 转换后重新校验；浏览器也可在失焦时调用已配置的固定转换模式 |
| 正则掩码 | `regex`；[regex_mask.mbt](../regex_mask.mbt)、[regex_mask_test.mbt](../regex_mask_test.mbt) | MoonBit NFA 子集、可行前缀检查；不是 ECMAScript 正则全集，详见下文 |
| 数值范围 | `range(from, to, width=..., autofix=...)` | 固定宽度非负整数、前缀可行性；上限 999999999；小数和负数使用 `number` |
| 枚举 | `enumeration` | 1–64 个有限候选；支持 ASCII 大小写不敏感及配置拼写归一化 |
| 小数、分隔符、边界、补零 | `number`，保留旧入口 `decimal`；[localized.mbt](../localized.mbt) | 十进制字符串保证精度；显式 radix/group separator，不猜地区；编辑时补零只影响完整提交值，顶层 JSON number 的显式 commit／失焦可将补零写入编辑内容；无指数、货币运算或舍入 |
| 日期格式与上下界 | `date(format=..., min=..., max=...)`，保留 `iso_date` | 任意顺序的一个 `YYYY`、`MM`、`DD`，允许可打印字面量；ISO 提交值；无时间、时区或任意第三方 Date 对象 |
| 占位符 | `presentation(placeholder=...)`；[presentation.mbt](../presentation.mbt) | 直接 Pattern／`iso_date` 展示完整字面量布局；其他掩码按容量在现有显示末尾补占位符 |
| 隐藏显示 | `presentation(concealed=...)` | 只隐藏可编辑字符，保留字面量；原始值和提交值仍对调用者可见，不提供加密 |
| 积极显示字面量 | `presentation(eager=true)` | 直接 Pattern／`iso_date` 显示下一段生成字面量；其他类型明确拒绝，不假装支持所有 eager 模式 |
| 覆盖输入／跳过非法字符 | `Editor::insert(overwrite=true, skip_invalid=true)` | 覆盖为同位置替换；不提供 IMask 的 `overwrite: "shift"` 模式；默认仍为整次编辑原子拒绝 |
| 显示值、原始值、完整值 | `display / raw / value / status`；[extensions.mbt](../extensions.mbt) | 完整值为字符串；命名区块通过 `fields` 返回，不返回 JS Number／Date 对象 |
| 固定部分的提交与区块值读取 | `composite` 的 `Literal`、`fields`、`with_value` | 组合完整值包含显示字面量；无 IMask `{...}`／`expose` 同语法开关 |
| 更新规则／释放绑定 | 原生 `Editor::with_mask`；浏览器 `updateOptions`、`destroy` | 规则更新重新验证旧 raw；新旧规则树含数字／日期时保护当前完整提交值；失败保留原配置和状态，成功清除旧规则历史；不承诺 IMask `updateOptions` 的完全相同行为 |
| 纯格式转换 | `pipe(mask, text, unmask=...)` | 显示字符串或完整提交字符串；不提供任意 JS 类型之间的 Pipe 转换 |
| 浏览器输入、历史与表单重置 | [web/adapter.mjs](../web/adapter.mjs)、[浏览器测试](../tests/browser.mjs) | 文本型 input；合成输入法事件和三引擎检查，不代表所有实体键盘已验证 |
| 值改变与完成事件 | `onChange`、`onAccept`、`onComplete`；[扩展浏览器检查](../tests/advanced-browser.mjs) | 接受值改变与进入／改变完整值时触发对应回调；名称和注册方式与 IMask 不同 |
| 框架插件、contenteditable、旧浏览器支持 | 当前不提供 | 不将 React/Vue 等包装层列作已实现的核心能力 |

## 正则范围与资源边界

支持全字符串匹配、捕获／非捕获分组、分支、字符类、反向字符类、点号，以及 `?`、`*`、`+`、`{m}`、`{m,n}`、`{m,}`。可省略全局 `^`／`$`。编辑时检查“当前前缀能否到达一个完整值”，因此 `AB-` 可以继续输入而不要求每次都已完整匹配。`\d`、`\w`、`\s` 与大小写折叠采用文档声明的 ASCII 规则。

反向引用、前后查找、内联标志、懒／占有量词及其余未声明的 ECMAScript 扩展会返回配置错误。实现使用 NFA 状态集合，不调用宿主正则引擎。正则源最多 2048 UTF-16 单元、嵌套 32 层、重复计数 256、编译状态 2048、输入 8192 UTF-16 单元。原生 `regex(max_length=...)` 与 JSON 正则配置的 `maxLength` 另设 Unicode 标量上限（1–8192），同时保留前述 UTF-16 上限；可行前缀必须能在该上限内完成。有限正则会推导容量，无界重复可通过较小的长度上限参与有限组合。组合规则另有更小的容量与解析预算，各构造器会明确拒绝超限配置。

0.2.1 同时检查剩余标量与 UTF-16 容量，只有存在满足两种预算的完整续写时才接受未完成前缀；源文本和输入中的孤立代理项会被拒绝。涉及混合上限的续写分析最多访问 262144 个 NFA 状态步骤，耗尽时返回 `InvalidValue`，不进行无限搜索。

## 对报名反馈的对应修改

1. **动态掩码：** 同一字段可随输入长度或分派条件在规则间切换；编辑、删除和重新设置都经过同一模型，并可读取候选名称。
2. **自定义校验：** 单字符定义、完整前缀状态、语义校验及输入／提交处理均有原生扩展入口；浏览器支持声明式校验规则，不把业务逻辑固化在三个预设中。
3. **规则组合：** 命名区块可嵌套范围、枚举、小数和其他有限容量规则，支持字面量、可选区块与重复，输出字段值；示例见 [0.2 升级说明](UPGRADE-0.2.md)。

检查实际状态时，应以对应提交的测试、[API](API.md) 和 [Actions](https://github.com/YeeHh2004/mooninput/actions) 为准。此表用于说明能力与差异，不代替主办方对通用性和完成度的判断。
