# 0.2：从固定格式扩展为可组合输入规则

0.1 主要提供固定 Pattern、ISO 日期和一种小数格式。0.2 围绕报名反馈中的“动态掩码、自定义校验、规则组合”扩展模型，使应用可以声明并组合自己的规则。规则实现、编辑转换和校验仍在 MoonBit 中；宿主层负责事件和文件 IO。

旧入口 `pattern`、`decimal`、`iso_date` 继续保留。新增 API 为显式 MoonBit API，不复制 IMask 的 JavaScript 配置语法；功能与差异见 [范围对照](IMASK-COVERAGE.md)。

## 1. 动态规则会在编辑后重新选择

同一标识字段既接收四位短编码，也接收六位长编码，无需卸载输入框或由应用自行拼接规则：

```moonbit
let mask = @input.dynamic([
  ("short", @input.pattern("##-##").unwrap()),
  ("long", @input.pattern("###-###").unwrap()),
]).unwrap()
let first = @input.Editor::new(mask, initial="1234").unwrap()
println(first.active_mask()) // Some("short")
println(first.display()) // 12-34
let next = first.insert("5").unwrap()
println(next.active_mask()) // Some("long")
println(next.display()) // 123-45
println(next.backspace().unwrap().active_mask()) // Some("short")
```

自动模式优先完整候选，再优先容量较小的候选，最后按声明顺序打破平局。原生 `dispatch` 回调可以按业务前缀明确选择候选名称；返回未知名称会报错。宿主只消费 `active_mask`，不重复实现选择算法。

浏览器／CLI 的声明式配置示例：

```json
{
  "kind": "dynamic",
  "masks": [
    {"name": "short", "kind": "pattern", "pattern": "##-##"},
    {"name": "long", "kind": "pattern", "pattern": "###-###"}
  ]
}
```

## 2. 字符定义与语义校验由使用者扩展

例如十六进制字符不需要新增硬编码掩码类型，可以定义 `H` 并复用 Pattern 的编辑能力：

```moonbit
let hex = @input.definition(
  'H',
  c => c.is_ascii_digit() ||
    (c.to_ascii_uppercase() >= 'A' && c.to_ascii_uppercase() <= 'F'),
  normalize=c => c.to_ascii_uppercase(),
)
let hardware = @input.pattern("HH:HH:HH:HH:HH:HH", definitions=[hex]).unwrap()
println(hardware.format("aabb01234567").unwrap()) // AA:BB:01:23:45:67
```

原生 `custom` 对每个候选值返回编辑状态；`with_validation` 在已有规则上增加业务校验。业务保留码可以标记为无效而继续允许修改：

```moonbit
let base = @input.pattern("AA-####").unwrap()
let checked = @input.with_validation(base, text => {
  if text == "AB0000" {
    @input.Invalid("reserved identifier")
  } else {
    @input.Complete
  }
})
let invalid = @input.Editor::new(checked, initial="AB0000").unwrap()
println(invalid.status()) // Invalid("reserved identifier")
// invalid.value() 返回错误；替换其中的字符后可以重新变为有效。
```

`Complete` 校验结果不绕过底层 Pattern 的未完成状态。校验器应考虑中间输入，不能要求每次输入都已经是最终值。语法错误与语义无效分开：语法错误原子拒绝，语义无效可以显示并修复。

JSON 采用有限、可序列化的规则，不执行用户提供的 JavaScript：

```json
{
  "kind": "validate",
  "rule": {"kind": "regex", "source": "[A-Z][A-Z0-9_]{2,15}"},
  "startsWith": "A",
  "minLength": 3,
  "maxLength": 16
}
```

`with_prepare` 处理输入文本；`with_value` 只转换完整提交值；`Editor::commit(transform)` 显式转换完成值并重新校验。三者职责不同，不会在只读取显示值时悄悄修改旧快照。原生回调必须确定、无副作用，异常由调用方处理。

## 3. 命名区块组合成业务规则

报价字段可由币种枚举、分隔符和精确小数组合。它既可作为一个编辑字段，也可供无界面的导入／格式转换使用：

```moonbit
let quote = @input.composite([
  @input.Block("currency", @input.enumeration(["USD", "EUR"]).unwrap()),
  @input.Literal(" "),
  @input.Block("amount", @input.decimal(precision=2, grouped=false).unwrap()),
]).unwrap()
let editor = @input.Editor::new(quote, initial="USD123.40").unwrap()
println(editor.display()) // USD 123.40
println(editor.raw()) // USD123.40
println(editor.value().unwrap()) // USD 123.40
// editor.fields() 包含 currency=USD、amount=123.40。
```

`Optional(name, mask)` 表示可选区块；`repeat(mask, min, max)` 表示有限重复，允许最后一个区块处于未完成状态。嵌套区块的字段名称带父名称前缀，便于读取。这里的组合完整值包含字面量；应用应按需求读取 `raw`、`value` 或 `fields`，不假设它们相同。

相同组合规则的声明式配置：

```json
{
  "kind": "composite",
  "parts": [
    {"kind": "block", "name": "currency", "rule": {"kind": "enum", "values": ["USD", "EUR"]}},
    {"kind": "literal", "literal": " "},
    {"kind": "block", "name": "amount", "rule": {"kind": "decimal", "precision": 2, "grouped": false}}
  ]
}
```

规则组合有明确容量与搜索上限。相邻变长规则存在多种分区时，模型优先选择能完成整个输入的分区，再保留可编辑的未完成分区。业务应优先使用有明确容量的子规则及无歧义分隔符。

## 更多通用能力与实际边界

- `range` 支持固定宽度范围及显式 autofix；`enumeration` 支持共享前缀和 ASCII 大小写策略。
- `regex` 以 MoonBit NFA 处理完整匹配和可行前缀，不调用宿主正则；不支持的语法明确报错。
- `number` 支持自定义小数点、分组、输入映射、精确字符串上下界、提交补零和归一化；补零在编辑时只作用于完整提交值，避免生成字符改变下一次输入的数值。顶层 JSON number 可通过显式提交或失焦将补零写入编辑内容。数字上下界使用标准点号十进制字符串，不随显示地区改变。
- `date` 支持日期顺序、可打印格式字面量与 ISO 上下界；例如 `DD/MM/YYYY`，完整提交值仍为 `YYYY-MM-DD`。
- `presentation` 增加显示占位符或隐藏字符，保留原始值、提交值、动态分支和命名字段。隐藏仅为视觉效果。直接 Pattern／`iso_date` 可显示下一段生成字面量；其他类型不声称支持该模式。
- `Editor::with_mask` 原子更新规则；`pipe` 无界面转换；选区与光标继续统一采用 UTF-16，不把 Unicode 标量冒充完整字素簇。

业务可以据此实现多规格商品编码、批量标识输入、参数配置、报价、测量值、预约日期等规则。示例展示复用方式，不验证真实身份、支付业务或远端数据。

## 浏览器中的规则更新、事件与提交

`binding.updateOptions(patch)` 将顶层配置补丁合并到原配置，再用新规则验证当前 raw；失败保留原规则和输入，成功后清除旧规则的历史。新旧规则树中包含数字／日期时，包括组合、动态候选和包装规则内的子规则，若更新会改变当前完整提交值，也会拒绝，应先清空或显式转换。它不是深层合并接口：修改嵌套规则时，应提供完整的新 `rule`／`masks`／`parts` 值。工作台应用整份配置时会先验证配置，再清空测试输入；错误配置不会替换已有绑定。

`onChange` 接收每次渲染的快照，包括初始化、编辑结果和规则更新；`onAccept` 在 raw、display、完整值、状态、原因、动态分支或命名字段改变时触发；`onComplete` 在进入完整状态或完整值改变时触发，初始化不会额外发送后两种事件。`state.active` 与 `state.fields` 直接来自 MoonBit 的动态和组合规则。

JSON 的 `prepare` 与 `commit` 可选择固定的 `trim`、`uppercase`、`lowercase` 模式；这不等于从 JSON 执行任意代码。输入框失焦时，仅对完整值执行提交；也可调用 `binding.commit()`。原生 MoonBit 则可以显式传入自己的 `Editor::commit(transform)` 回调。未完成／无效值保持编辑状态，不靠提交操作绕过校验。

有界正则可以用于组合：原生 `regex(source, max_length=16)` 或 JSON `{"kind":"regex","source":"[A-Z]+","maxLength":16}` 的长度上限按 Unicode 标量计数，同时仍受总输入的 UTF-16 上限约束。有限表达式会自动推导最大容量。JSON `validate` 的 `minLength/maxLength` 按 UTF-16 长度检查；两种长度选项不应混淆。

## 0.2.1 的接入加固

原生新增 `Editor::restore(mask, raw, display, start, end)`：依次重建 raw／格式化候选，仅在 raw 和 display 都完全匹配时接受，并验证选区。协议增加可选的前次 display；浏览器默认传递，撤销／重做也保存并重新验证完整快照。它保留已明确输入的组合分区；只保存 raw 的旧接入仍可运行，但无法还原所有歧义分区。新的真实编辑继续遵循规则的分区算法。

数值片段粘贴在合并前使用配置的分隔符归一化，边界和 autofix 在合并后的完整字段上执行；校验、提交值后处理和展示包装规则保留该能力。`with_prepare` 仍先转换整次拟输入再解析，不转发数值片段钩子；Pattern 覆盖仍按原来的槽位计数。日期数字后缀不会再截去原始日期的真实末位。正则可行续写同时受标量和 UTF-16 预算约束，并有独立分析步数上限。具体行为和资源限制见 [API](API.md) 与 [行为边界](BEHAVIOR.md)。

替换后 raw 不变时，保留原有组合分区，避免一次等值替换改变字段含义。原生表单重置会在浏览器执行默认操作前保存选区；默认值不合法时，恢复事件开始时的内容和选区，历史也会保留。

## 复现与重新审核

从 README 的安装和测试命令开始。新增原生测试覆盖自定义定义、动态切换、范围／枚举、命名组合、可选／重复、正则前缀、地区数字、日期边界、显示映射和提交处理；浏览器与协议检查确认声明式入口使用同一核心。

重新报名时可结合本页说明“原来仅有几类固定格式，现已加入可扩展规则与组合模型”，并提供真实仓库提交和可运行示例。未实现或仅部分实现的 IMask 特性应保留在 [对照表](IMASK-COVERAGE.md) 中，避免把功能目标写成已达到的兼容承诺。
