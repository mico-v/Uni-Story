# NovaScript 剧本语法手册

NovaScript 是 Uni-Story 视觉小说框架的剧本领域语言。剧本文件（`.txt`）由 `NovaParser` 分词、`ScriptLoader` 构建流程图、`GDRuntime` 在运行时编译执行。

Phase 2 开始，Uni-Story 增加了 Nova 上游常用语法的兼容翻译层。它会把一部分 Lua 风格 NovaScript 转换到 GDScript runtime 上执行，因此工程仍然是 GDScript-first；当前没有内嵌完整 Lua VM，也不承诺所有 Nova Lua API 等价。

## 文件结构

当前默认剧本使用 Nova 上游内容，放在 `resources/scenarios/` 目录下，扩展名为 `.txt`。从 Nova 上游导入的参考脚本和素材直接放在 `resources/` 根目录下：

- `resources/scenarios/`：Nova 原始中文剧本，也是 `NovaController` 默认加载的剧本目录。
- `resources/Lua/`：Nova 原始 Lua 脚本，仅作为迁移参考，不作为运行时 Lua VM 直接执行。
- `resources/Backgrounds/`、`resources/BGM/`、`resources/Standings/` 等：从 Nova `Assets/Resources` 增量导入的图片、音频、视频和 JSON 资源。
- 同目录下的旧 demo 剧本（如 `main.txt`、`plan_demo.txt`、`test_all.txt`）保留，但不在默认加载清单中。

一个剧本文件包含若干 **节点**（label），每个节点包含若干 **对话条目**（text line + 可选的 lazy block）。

```
@<|
label("chapter1", "第一章")
is_start()
|>
<|
show("bg", "backgrounds/school")
play_bgm("music/bgm01.ogg")
|>
旁白文本

角色名：：角色台词

<|
trans("fade", 0.5)
|>
场景切换后的文本
@<| jump_to("chapter2") |>
```

---

## 剧本静态检查

在提交或发布剧本前，使用公共 Python 入口运行 Scenario lint：

```bash
# 默认检查 resources/scenarios/ 下的 28 个主剧本
python scripts/tools/scenario_lint.py

# 输出 JSON 报告
python scripts/tools/scenario_lint.py --format json --output scenario-lint.json

# warning 也视为失败，并只检查指定文件/目录
python scripts/tools/scenario_lint.py --fail-on warning resources/scenarios/ch1.txt
```

命令会自动调用 Godot 检查实现。可用 `--godot PATH` 指定 Godot，`--project PATH` 指定项目根目录，`--format text|json` 和 `--output PATH` 控制报告；末尾可传多个文件或目录。需要针对性排查时，也可用 `--no-compile`、`--no-resources` 或 `--no-no-op` 暂停对应检查。

主要规则包括：

- 块配对、属性头、NovaScript 翻译后的 GDScript 和条件表达式编译。
- label 前对白、重复 label、缺少 start、空/未知 jump 与 branch target、动态目标和不可达节点。
- 背景、立绘、CG alias、branch image、音频、`say()`、Prefab、视频与虚拟 RenderTarget 资源。
- `显示名//内部名` canonical speaker 格式、同节点映射冲突和 AutoVoiceProfile 中未配置的 speaker。
- TODO、非法控制字符、角色对白中文引号与半角标点、`anim_hold_begin/end` 配对、jump-mode branch 缺少无条件 fallback。
- 已知 no-op API 与被兼容层丢弃的调用/结果。

结构、编译、无效流程目标、缺失资源和 canonical speaker 等确定性问题报告为 error；内容风格、不可达节点、`anim_hold`、fallback 和兼容陷阱通常报告为 warning。文本诊断格式稳定为：

```text
path:line:column: severity [rule-id] message
```

`--fail-on error|warning|never` 控制退出 1 的最低诊断级别，默认是 `error`，因此 warning 会显示但不阻断 CI/Release。退出码 0 表示未达到失败阈值，1 表示存在达到阈值的诊断，2 表示命令参数、Godot 启动或报告生成失败。

当前默认 corpus 的基线为 `files=28`、`errors=0`、`warnings=133`、`referenced=372`、`found=370`、`virtual=2`、`missing=0`。独立 `scenario_resource_scan_test.gd` 的严格回归仍为 `referenced=369`、`found=367`、`virtual=2`、`missing=0`；lint 多出的 3 个已找到引用来自 branch image 扫描。

## 剧本对白统计

Scenario stat 使用与未来 visualize 共用的静态 IR，对剧本源文件做对白与流程 inventory：

```bash
# 默认统计 resources/scenarios/ 下的 28 个主剧本
python scripts/tools/scenario_stat.py

# 只输出汇总/分组，不输出最长对白列表
python scripts/tools/scenario_stat.py --top 0

# 指定文件并写入 JSON
python scripts/tools/scenario_stat.py --format json --output scenario-stat.json resources/scenarios/ch1.txt
```

公共 CLI 支持 `--godot PATH`、`--project PATH`、`--format text|json`、`--output PATH`、`--top N` 和多个文件/目录。`--top` 默认 10，`0` 表示不生成 `longest` 条目。退出码只有 0（成功）和 2（参数、输入、分析、Godot 或报告生成失败），没有 lint 的诊断阈值退出码 1。

统计语义：

- 这是全量 source inventory，不是某条分支的单次通关时长估算。
- `scenario_analysis.gd` 生成 `blocks/nodes/entries/silent_entries/edges/events`；eager block 只翻译供参考，绝不执行。
- label 前对白按 `ScriptLoader` 语义视为分析错误，不计入 runtime entry。
- 配对 rich tag 与 `（TODO：…）` 注记会从计长文本中移除，连续 ASCII 空格折叠为一个；长度单位为 `unicode_codepoints`。
- `显示名//内部名` 的 canonical speaker 映射在当前 node 内继承，遇到下一条 `label()` 重置。
- JSON schema v1 包含 `summary`、`length_histogram`、`by_file`、`by_node`、`by_speaker` 与 `longest`，排序稳定，可供编辑器或后续可视化工具消费。

当前默认基线为 `files=28`、`blocks=360 (106 eager/254 lazy)`、`nodes=53 (23 local; 23 normal/9 chapter/21 end)`、`dialogues=731`、`spoken=111`、`narration=620`、`characters=15434`、`empty=2`、`min=0`、`max=179`、`mean=21.113543`、`p50=14`、`p90=47`、`p95=62`、`silent_entries=1`、`runtime_entries=732`、`jumps=23`、`branch_options=24`、`transitions=47`。`speakers=8` 是 canonical speaker 分组数，不等于静态角色数；另有 9 个 display speaker 和 1 条 dynamic speaker entry。

---

## 三种基本元素

### 1. 急切块（Eager Block）`@<| ... |>`

在 **加载/解析阶段** 立即执行，用于定义流程图结构。

```
@<| label("node_name", "显示名称") |>
```

多行写法：
```
@<|
label("node_name", "显示名称")
is_start()
is_chapter()
|>
```

### 2. 惰性块（Lazy Block）`<| ... |>`

在 **游戏运行时** 执行，绑定到紧随其后的对话条目上。用于控制演出效果。

```
<|
show("bg", "cg/sunset")
cam([2, 0])
trans("fade", 0.4)
|>
这是对话文本
```

一个惰性块绑定到它后面最近的一条对话文本。如果没有对话文本（后面直接是另一个块或节点结尾），则该块作为 **静默条目** 执行——只运行演出代码，不等待用户点击。

多个连续的惰性块如果没有对话文本间隔，每个都会成为独立的静默条目，按顺序执行。

### 3. 对话文本行

非空且不以 `@<|` 或 `<|` 开头的行就是对话文本。每一行是一个独立的对话条目。

```
这是一句旁白
这是第二句旁白
角色名：：这是角色台词
另一个角色：：这是另一个角色的台词
```

---

## 注释

支持 `#` 和 `//` 两种整行注释（不支持行内注释）：

```
# 这是注释
// 这也是注释
这不是注释，这是对话文本
```

---

## 对话格式

角色名和台词之间使用双冒号分隔：

| 分隔符 | 说明 | 示例 |
|--------|------|------|
| `：：` | 全角双冒号（推荐） | `仁菜：：你好啊` |
| `::` | 半角双冒号 | `Alice::Hello` |

单个 `：` 或 `:` 不再被当作角色分隔符，因为 Nova 原始剧本中经常把普通冒号写在旁白里。如果行中没有双冒号，则整行作为旁白文本（speaker 为空）。

### 显示名与 canonical speaker

Nova 的 `显示名//内部名` 写法可把 UI 上看到的名字与运行时角色身份分开：

```text
？？？//张浅野：：时机到了。
？？？：：这是同一角色的下一句。
```

第一句显示为 `？？？`，但 `DialogueEntry.character_name` 保存 canonical speaker `张浅野`。同一 flow-chart node 内，后续只写 `？？？` 时会继承该内部名；遇到新 `label` 后映射重置。AutoVoice、角色级配置和其它需要稳定身份的系统使用 canonical speaker，UI 与 Backlog 仍显示 `？？？`。这里的 `//` 位于 speaker 与双冒号之间，不是整行注释。

---

## 块属性（Block Attributes）

可以在块开头添加属性前缀：

- `@[key=value; ...]@<| ... |>`：带属性的 eager block。
- `@[key=value; ...]<| ... |>`：带属性的 lazy block。
- `[key = value]<| ... |>`：兼容 Nova 上游写法，常用于 lazy block stage。

```
@[mode=jump; cond="has_var('flag')"]@<|
branch([
    { dest="path_a", text="路线 A" },
    { dest="path_b", text="路线 B" },
])
|>
```

属性规则：
- 用分号分隔的键值对
- 值可以用双引号、单引号包裹，或不加引号
- `mode`、`cond`、`image` 会作为默认值传递给 `branch()` 的选项
- lazy block 的 `stage` 支持 `default`、`before_checkpoint`、`after_dialogue`

Stage 示例：

```
[stage = before_checkpoint]<|
v_seen = true
|>
<|
show("bg", "backgrounds/room")
|>
[stage = after_dialogue]<|
gv_last_line = "room_intro"
|>
角色：：这句话会先执行 before_checkpoint 和 default，显示后再执行 after_dialogue。
```

---

## Nova 上游兼容基线

兼容层位于 `scripts/core/nova_script_compat.gd`。加载剧本时，`ScriptLoader` 会按文件名建立命名空间，并把 Nova 常用 Lua 风格写法转换为当前 GDScript block。

已支持的 Phase 2 子集：

- `label 'name'`、`jump_to 'name'`、`is_end 'name'` 简写。
- `l_` 开头的局部 label，按文件名转换为 `file:label`，避免不同剧本文件互相冲突。
- `is_save_point()` 节点标记。
- `is_start()`、`is_unlocked_start()`、`is_chapter()`、`is_debug()` 的基础分类。
- `branch { ... }` 转为 `branch([ ... ])`。
- branch `cond = 'v_flag < 2'` 字符串条件。
- branch `cond = function() return v_flag > 1 end` 的简单 return 表达式条件。
- `image = {'red_pill', {-500, 0, 0.5}}` 转为数组形式，保留图片名和坐标 tuple。
- Lua 风格 `if ... then` / `elseif ... then` / `else` / `end` 的简单控制流。
- Lua 风格对象方法调用，如 `anim:move(...)`、`anim:trans_fade(...)`，会翻译为 GDScript 方法调用并交给兼容代理处理。
- 简单 Lua callback `function(...) ... end` 会被抽取为顺序执行的 GDScript 语句，用于兼容 Nova 常见转场包装块。
- Lua table `{ ... }` 会按上下文转换为 GDScript Array/Dictionary。
- `nil` 转为 `null`。
- `v_` 变量、`gv_` 全局变量、普通临时变量赋值和读取。
- 文本插值 `{{var_name}}`，可读取 `v_`、`gv_` 和当前 block 临时变量。
- 上游 `[stage = before_checkpoint]<| ... |>` / `[stage = after_dialogue]<| ... |>` lazy action。
- 常用播放 API 兼容：`play()`、`sound()`、`box_hide_show()`、`say()`、`auto_voice_on/off/off_all()`、`set_auto_voice_delay()`、`auto_voice_skip()` 均已有实际运行时映射。
- 常用 Nova 常量兼容：`pos_c/pos_l/pos_r/pos_cl/pos_cr`、`bg/fg/cg/bgm/bgs/voice`。
- Nova 示例角色名兼容：`ergong`、`gaotian`、`qianye`、`xiben` 可映射到 `resources/Standings/` 下的组合立绘。

当前限制：

- 不执行完整 Lua；`pairs`、`ipairs`、协程、元表、require、任意 Lua 标准库都不属于 Phase 2 范围。
- 只翻译常见 Nova 剧本形态；复杂多行表达式和动态拼接可能需要手动迁移为 GDScript 写法。
- Nova Lua runtime API 尚未完整对齐，`__Nova` 仅有少量兼容替换。
- `anim` / `anim_hold` 当前兼容代理已可用；完整动画系统（域/pause/resume/easing）已通过 AnimationSystem 实现。
- `box_tint()`、`avatar_show()`、`anim_hold_begin/end()`、`minigame()`、部分输入/快进/自动播放和文本排版方法也仍是兼容 no-op；“可编译调用”不等于语义已实现。
- 通用中断/fence 协议已实现：`begin_interrupt()` / `end_interrupt()` 可暂停对话推进并在结束后自动 checkpoint；这不代表 `minigame()` 便捷加载器已实现。
- 存读档 UI 已支持缩略图、章节名、时间和当前位置显示。
- 回顾面板已支持语音重播和跳转确认。

---

## 急切块 API（图结构定义）

以下方法在 `@<| ... |>` 中调用，用于定义流程图。

### `label(name, display_name = null)`

创建一个新节点（或切换到已有节点），后续所有内容都属于该节点。

```
@<| label("opening", "序章") |>
```

兼容 Nova 简写：

```
@<| label 'opening' |>
```

如果 label 以 `l_` 开头，会被视为当前文件内的局部 label。例如 `resources/scenarios/test_branch.txt` 里的 `l_a` 会解析为 `test_branch:a`。

### `is_start()`

标记当前节点为游戏起始点。`New Game` 会从第一个 `is_start` 节点开始。

```
@<|
label("main", "主线")
is_start()
|>
```

### `is_unlocked_start()`

标记当前节点为可选择的起始点（章节选择模式下可见）。

### `is_chapter()`

标记当前节点为章节类型。

### `is_save_point()`

标记当前节点为存档检查点。Phase 2 先写入 `FlowChartNode.is_save_point`，Phase 3 会接入完整 checkpoint/bookmark 恢复体系。

### `is_end(end_name = null)`

标记当前节点为结局类型。到达该节点末尾时游戏结束。

可以传入结局名：

```
@<| is_end("good_end") |>
@<| is_end 'good_end' |>
```

### `is_debug()`

标记当前节点为调试专用。

### `jump_to(dest)`

设置当前节点的跳转目标。当节点内所有对话播放完毕后，自动跳转到目标节点。

```
@<| jump_to("chapter2") |>
```

### `branch(branches)`

设置当前节点的分支选项。每个选项是一个字典：

```
@<|
branch([
    { dest="opt_a", text="选择 A" },
    { dest="opt_b", text="选择 B" },
    { dest="opt_c", text="隐藏选项", cond="get_var('flag') == true" },
])
|>
```

兼容 Nova 上游的 table 风格：

```
@<|
branch {
    { dest = 'l_a', text = '选择 A' },
    { dest = 'l_b', text = '选择 B', cond = 'v_flag < 2' },
    { dest = 'l_c', text = '选择 C', cond = function()
        return v_flag > 1
    end },
}
|>
```

选项字典的键：

| 键 | 类型 | 说明 |
|----|------|------|
| `dest` | String | 目标节点名（必填） |
| `text` | String | 显示文本 |
| `mode` | int/String | 分支模式（见下方） |
| `cond` | String | 条件表达式（GDScript） |
| `image` | String/Array | 选项图片路径，或 Nova tuple `[name, [x, y, scale]]` |

Nova 上游写法 `image = {'red_pill', {-500, 0, 0.5}}` 会保留为数组数据，供 UI 分支视图后续渲染。

**分支模式：**

| 值 | 名称 | 行为 |
|----|------|------|
| 0 / `"normal"` | NORMAL | 标准选项，用户必须选一个 |
| 1 / `"jump"` | JUMP | 自动跳转（不显示给用户） |
| 2 / `"show"` | SHOW | 仅展示（装饰性） |
| 3 / `"enable"` | ENABLE | 条件启用（条件不满足时置灰） |

---

## 惰性块 API（运行时演出）

以下方法在 `<| ... |>` 中调用，在游戏运行时执行。

### 快捷属性

| 属性 | 说明 | 示例 |
|------|------|------|
| `o` | 已注册的场景对象字典 | `o.bg`、`o.fg`、`o.anim` |
| `c` | 常量字典 | `c.resource_root` |
| `nova` | NovaController 本身 | 高级用途 |

### 图像显示

#### `show(obj, image_path, coord = null, color = null)`

显示一个对象（背景、前景、角色等）。

```
<|
show("bg", "backgrounds/school")
show("fg", "foregrounds/sakura", [100, 50, 0.8])
|>
```

`obj` 可以是字符串名称（如 `"bg"`）或对象引用（如 `o.bg`）。

`coord` 是一个数组，格式为 `[x, y, scale, ?, angle]`，其中 `null` 表示保持当前值不变。

#### `hide(obj)`

隐藏一个对象。

```
<| hide("bg") |>
<| hide(o.fg) |>
```

#### `move(obj, coord, scale = null, angle = null)`

移动、缩放、旋转对象。`coord` 中的 `null` 表示该轴不变。

```
<|
move("fg", [200, 100, 0.5])        # 移动并缩放
move("fg", [null, null, null, null, 45])  # 只旋转 45 度
move("fg", [0, 0, 0.2, 0, 0])     # 复位
|>
```

#### `tint(obj, color)`

给对象着色。`color` 为 `[r, g, b]` 或 `[r, g, b, a]`，值域 0-1。

```
<|
tint("fg", [1, 0, 0])        # 红色
tint("fg", [1, 1, 1])        # 复原
|>
```

### 角色立绘

#### `show_char(char_name, layers = {}, coord = null, color = null)`

显示组合立绘。`layers` 是图层字典。

```
<| show_char("renna", { body="uniform", face="smile" }, [400, 0]) |>
```

#### `set_layer(char_name, layer, key = "")`

切换立绘的单个图层（如表情）。

```
<| set_layer("renna", "face", "angry") |>
```

#### `hide_char(char_name)`

隐藏角色立绘。

### 头像

#### `set_avatar(char_name, key = "")`

在对话框显示角色头像。

#### `clear_avatar()`

清除头像。

### 对话框

#### `set_box(pos_name = "bottom", alignment = null, clear = false)`

设置对话框位置/样式。可选值：`"bottom"`、`"center"`、`"top"`、`"hide"`、`"full"`、`"left"`、`"right"`。

```
<| set_box("center") |>
<| set_box("center", "center") |>
<| set_box("hide") |>
<| set_box() |>
```

### 相机

#### `cam(coord, scale = null, angle = null)`

控制相机位置、缩放、旋转。`coord` 格式 `[x, y, scale, ?, rotation]`，旋转可以是欧拉角数组 `[rx, ry, rz]`。

```
<|
cam([5, 5])                           # 平移
cam([0, 0, null, null, [0, 30, 0]])   # 旋转
cam([0, 0, null, null, 0])            # 复位
|>
```

### 转场

#### `trans(kind = "fade", duration = 0.5)`

播放屏幕转场效果。可选类型：`"fade"`、`"flash"`、`"dissolve"`、`"wipe"`。

```
<|
trans("fade", 0.4)
trans("flash", 0.3)
|>
```

### 视觉特效

#### `vfx(effect_name, target, duration = 0.5, params = {})`

对目标施加视觉特效。对象效果完整列表：

- `"blur"`：参数 `amount`。
- `"grayscale"`：参数 `amount`。
- `"dissolve"`：参数 `threshold`。
- `"glitch"`：参数 `intensity`、`speed`。
- `"ripple"`：参数 `amount`、`speed`。

兼容别名 `mono` / `colorless` / `gray` / `grey` 会映射到 `grayscale`，`lens_blur` / `radial_blur` 会映射到 `blur`。

同一目标最多记录 3 个 effect，但当前并非真正的多 pass 材质合成：实际只渲染栈顶材质，其余层用于状态、清理和存档恢复。

#### `clear_vfx(target, duration = 0.3)`

移除目标上的全部视觉特效。

#### `clear_effect(effect_name, target, duration = 0.3)`

只从目标的 effect 记录中移除指定名称；若仍有其他 effect，则重新显示剩余栈顶材质。

#### `post_fx(effect_name, duration = 0.5, params = {})`

全屏后处理特效。完整列表：

- `"chromatic"`：参数 `amount`。
- `"vignette"`：参数 `intensity`。
- `"grayscale"`：参数 `amount`。
- `"blur"`：参数 `amount`。
- `"glitch"`：参数 `intensity`、`speed`。

#### `clear_post_fx(duration = 0.3)`

移除全屏后处理。

#### `shake(intensity = 10.0, duration = 0.5)`

屏幕震动。

#### `capture_screen()`

实验性接口。读取当前 viewport 并返回 `ImageTexture`；headless renderer 或无法读取 viewport 时返回 `null`。

#### `capture_transition(effect_name, duration = 0.5)`

实验性捕获转场，目前接受 `"dissolve"` 或 `"wipe"`。当前实现会先调用 `capture_screen()`，但捕获纹理尚未绑定到转场 shader，也没有参与最终画面合成；非 headless 环境中实际播放的仍是普通 overlay shader 进度动画，不能把它视为已完成的前后帧转场。

```
<|
vfx("blur", "bg", 0.5)
vfx("glitch", "bg", 0.2, {"intensity": 0.35, "speed": 3.0})
clear_effect("blur", "bg", 0.2)
shake(15.0, 0.3)
post_fx("vignette")
capture_transition("dissolve", 0.6) # 实验性，捕获纹理暂未参与合成
|>
```

### Prefab（预制体）

#### `load_prefab(name, path, coord = null, color = null, category = PrefabLoader.PrefabCategory.WORLD)`

加载一个场景预制体，并按生命周期分为三类：

- `PrefabLoader.PrefabCategory.WORLD`：世界对象；章节跳转或 world reset 时清理。
- `PrefabLoader.PrefabCategory.UI`：HUD/UI 对象；离开 GameView 或 display cleanup 时清理。
- `PrefabLoader.PrefabCategory.PERSISTENT`：跨节点保留，只在显式销毁或强制全清理时移除。

为兼容旧脚本，最后一个参数仍接受 bool：`true` 等价于 UI，`false` 等价于 WORLD。

#### `load_ui_prefab(name, path, coord = null, color = null)`

以 UI 分类加载，等价于向 `load_prefab()` 传入 `PrefabCategory.UI`。

#### `load_persistent_prefab(name, path, coord = null, color = null)`

以 PERSISTENT 分类加载，适合需要跨节点保留的运行时对象。

#### `show_prefab(name)` / `hide_prefab(name)` / `destroy_prefab(name)`

显示、隐藏、销毁预制体。

引擎/工具代码还可通过 `PrefabLoader` 使用 `destroy_all(force = false)`、`destroy_by_category(category)`、`has_prefab(name)`、`get_prefab(name)`、`get_prefabs_by_category(category)` 和 `get_prefab_category(name)`；这些不是当前 `BaseBlock` 的同名快捷函数。

```
<|
load_prefab("clock", "prefabs/clock.tscn", [500, 100])
load_ui_prefab("hud_fx", "prefabs/hud_fx")
load_persistent_prefab("weather", "prefabs/rain")
|>
一段时间后...
<|
destroy_prefab("clock")
|>
```

### 音频

#### `play_bgm(path, fade = 0.0)`

播放背景音乐，可设置淡入时间。

#### `stop_bgm(fade = 0.0)`

停止背景音乐，可设置淡出时间。

#### `play_se(path, volume_db = 0.0)`

播放音效。

#### `play_voice(path, override_auto_voice = true)`

立即播放显式语音路径，并把该路径附到下一条 Backlog 记录。默认同时覆盖下一条自动语音，避免显式语音与 AutoVoice 串音。传入 `false` 时仍以显式 cue 为实际播放内容，但会消费符合条件的 AutoVoice 编号与一次性 delay，使后续编号保持对齐。

#### `say(speaker, voice_id, delay = 0.0, override_auto_voice = true)`

按 AutoVoiceProfile 中的 speaker 目录解析语音编号，并把 cue 绑定到紧随其后的对白。默认覆盖该对白的自动 cue；`delay` 为非阻塞播放延迟。`override_auto_voice=false` 使用与 `play_voice()` 相同的“显式播放、自动状态照常消费”策略。

```
<|
play_bgm("music/bgm01.ogg", 1.0)
play_se("se/door.ogg")
say("王二宫", "004001", 1.0)
|>
```

#### Nova 兼容音频 API

`play(kind, name, volume = null)` 会把 Nova 的 `bgm`、`bgs`、`voice` 等类型映射到当前 Godot 音频系统；`sound(name, volume = null)` 是 `play_se()` 的兼容入口。

```
<|
play(bgm, "prelude")
play(bgs, "rain")
sound("flap", 0.5)
|>
```

#### 自动语音 AutoVoice

项目级配置位于 `resources/auto_voice_profile.tres`。`AutoVoiceProfile` 负责 canonical speaker/别名、角色语音目录、文件扩展名和补零宽度；默认宽度为 6，扩展名为 `.ogg`：

| canonical speaker | 可用别名 | 目录 |
|-------------------|----------|------|
| `王二宫` | `ergong` / `Ergong` | `Voices/Ergong` |
| `张浅野` | `qianye` / `Qianye` | `Voices/Qianye` |
| `孙西本` | `xiben` / `Xiben` | `Voices/Xiben` |
| `陈高天` | `gaotian` / `Gaotian` | `Voices/Gaotian` |

目录和文件名大小写会在 Linux 导出中严格区分。例如索引 `1001` 会解析为 `Voices/Ergong/001001.ogg`。现有 ch1-ch4 使用的 42 个自动语音资源均遵循该规则。

可用 API：

- `auto_voice_on(speaker, start_id = null)`：启用 speaker，并可设置下一条索引。重新启用但省略索引时保留当前计数。
- `auto_voice_off(speaker = "")`：关闭指定 speaker；空字符串等同于关闭全部。
- `auto_voice_off_all()`：关闭全部自动语音。
- `set_auto_voice_delay(seconds)`：设置下一条符合条件的自动 cue 的一次性非阻塞延迟。
- `auto_voice_skip()`：覆盖下一条自动 cue，不递增 speaker 索引，也不消费待用 delay。

`start_id` 也兼容 Nova 的 prefix/index 组合。数组形式为 `[prefix, index]`，Dictionary 形式为 `{ "prefix": value, "index": value }`；最终文件名为 `prefix + 六位索引 + 扩展名`。

```gdscript
<|
auto_voice_on("王二宫", 001001)
auto_voice_on("张浅野", ["", 002001])
set_auto_voice_delay(2.0)
|>
王二宫：：这一句在两秒后播放 Voices/Ergong/001001.ogg。

<|
# 显式 say 默认覆盖本句自动 cue
say("王二宫", "004001")
|>
王二宫：：这一句使用显式指定的语音。
```

运行规则：

- 只有 enabled 且 canonical speaker 匹配的对白才消费索引；旁白、未知角色与已关闭角色不消费索引或 delay。
- 一次性 delay 在下一条合格自动 cue 被准备时消费并归零。进入下一句会取消上一句尚未开始的 delayed cue，防止串音。
- 显式 `say()` / `play_voice()` 默认覆盖下一条自动 cue；自动索引与待用 delay 保持不变，后续自动对白继续正常使用。
- 自动 cue 的精确路径会写入同一条 Backlog，回顾面板可直接重播。
- Auto 模式在打字结束后先等待 pending delay，再等待 Voice 播放结束，最后才计算阅读延迟并推进。
- AutoVoiceSystem 已注册为 restorable，保存 enabled/index/prefix、下一次 delay、override 状态与当前 cue。读档/回跳先静默 replay，再恢复 AutoVoice 并只调度目标对白，不重播跳过的历史语音，也不会重复消费编号。

### 变量

#### `set_var(name, value)` / `get_var(name, default = null)` / `has_var(name)` / `add_var(name, delta)`

故事变量的读写操作。变量在存档中持久化。

```
<|
set_var("affection", 0)
add_var("affection", 1)
|>

# 条件判断用 jump_if
<| jump_if(get_var("affection") > 5, "good_end") |>
```

#### Nova 变量兼容：`v_` / `gv_` / 临时变量

Phase 2 支持 Nova 上游常见的变量前缀：

```
<|
v_name = "啊啊啊"
v_count = 3
gv_route_unlocked = true
temp_value = 4.56
|>

旁白：：变量可以显示在文本中：{{v_name}} {{v_count}} {{temp_value}}
```

规则：

- `v_` 开头的变量写入当前 playthrough 变量表，会进入普通存档快照。
- `gv_` 开头的变量写入全局变量表，保存到 `user://global_variables.json`。
- 普通赋值如 `temp_value = 4.56` 写入临时变量表，可用于当前运行期间的表达式和文本插值。
- 表达式里的 `v_foo` / `gv_bar` 会自动翻译为变量读取。
- 文本和 speaker 支持 `{{name}}` 插值，查找顺序为 `gv_`、`v_`、临时变量、普通变量。

示例：

```
<|
v_flag = 1
gv_seen_intro = true
name = "仁菜"
|>
{{name}}：：flag={{v_flag}} global={{gv_seen_intro}}
```

### 流程控制（惰性块中）

#### `jump_to(dest)`

在运行时立即跳转到目标节点。

#### `jump_if(cond, dest)`

条件跳转——当 `cond` 为 true 时跳转。

```
<| jump_if(get_var("route") == "A", "route_a_scene") |>
```

### 其他

#### `wait(seconds)`

暂停指定秒数。

#### `timeline()`

创建时间轴编排器（见下方详细说明）。

#### `play_video(path, skippable = true)`

播放视频文件（.ogv / .webm），用户可点击跳过。

#### `show_toast(message, duration = 2.0)`

显示顶部提示消息。

#### `show_confirm(title, message)`

显示确认对话框，返回 bool 结果。

#### `preload_asset(path, type = "", priority = 0)`

异步预加载资源文件。`path` 可为 `res://` / `user://` 完整路径，或相对当前 `resource_root` 的路径。

- `type` 可为 `"image"`、`"audio"`、`"prefab"`、`"other"`；空字符串会按扩展名自动判断。
- `priority`：`1` 为 HIGH，`0` 为 NORMAL，`-1` 为 LOW；较高优先级会先轮询。
- 重复预加载同一路径会增加引用计数，而不是重复创建缓存项。

#### `cancel_preload(path)`

减少对应资源的引用计数；计数降到 0 时，从 pending/cache 中移除。

#### `cancel_all_preloads()`

取消全部 pending preload，并清空各类型缓存。该剧本 API 对应底层 `PreloadSystem.cancel_all()`。

```gdscript
<|
preload_asset("characters/renna/body.png", "image", 1)
preload_asset("BGM/prelude.ogg", "audio", 0)
cancel_preload("BGM/prelude.ogg")
# cancel_all_preloads()
|>
```

---

## 时间轴（Timeline）

Timeline 是一个基于时间轨道的演出编排器，用于协调多个定时事件。

```
<|
var t = timeline()
t.show_at(0.0, "bg", "backgrounds/sunset")
t.show_at(0.5, "char_a", "characters/a_smile", [400, 0])
t.cam_at(1.0, [2, 0], 0.5)
t.se_at(1.5, "se/chime.ogg")
t.trans_at(3.0, "fade", 0.5)
t.play()
|>
```

| 方法 | 签名 | 说明 |
|------|------|------|
| `at` | `at(time, callable) -> Timeline` | 在指定时间执行回调 |
| `show_at` | `show_at(time, obj, image, coord) -> Timeline` | 定时显示对象 |
| `hide_at` | `hide_at(time, obj) -> Timeline` | 定时隐藏对象 |
| `cam_at` | `cam_at(time, coord, duration) -> Timeline` | 定时移动相机 |
| `trans_at` | `trans_at(time, name, duration) -> Timeline` | 定时转场 |
| `se_at` | `se_at(time, file) -> Timeline` | 定时播放音效 |
| `wait_at` | `wait_at(time) -> Timeline` | 时间标记（无操作） |
| `play` | `play() -> Timeline` | 启动所有轨道 |
| `stop` | `stop() -> void` | 停止所有轨道 |

所有 `*_at` 方法返回 Timeline 自身，支持链式调用。

---

## 动画链（Animation Chain）

通过 `o.anim` 可以构建连续动画：

```
<|
o.anim\
    .PropertyVector3(o.bg, "position", Vector3(100, 0, 0), 1.0)\
    .PropertyColor(o.bg, "modulate", Color(1, 0.5, 0.5), 0.5)
|>
```

反斜杠 `\` 用于 GDScript 行续接。`o.anim` 的方法返回 AnimationChain，GDRuntime 会自动 await 其完成。

### Nova `anim` / `anim_hold` 兼容代理

Phase 2 已提供轻量兼容代理，支持 Nova 原剧本中常见的链式写法，例如：

```
<|
anim:trans_fade(cam, function()
    show("bg", "room")
    show("ergong", "normal", pos_c)
end, 2)
anim:volume(bgs, 0.2, 3)
anim:move("ergong", pos_l)
anim:fade_out(bgm, 2)
|>
```

### 动画域与命名 Holding 组（Phase 6）

`AnimationSystem` 支持以下动画域：

| 域 | 枚举值 | 说明 |
|----|--------|------|
| PER_DIALOGUE | 0 | 对白期间动画，切出 GameView 时暂停 |
| HOLDING | 1 | 持续循环动画，通过 `o.anim.holding("group_name")` 创建 |
| UI | 2 | UI 动画 |
| TEXT | 3 | 文字效果动画 |

```gdscript
# Holding animation with named group:
<|
o.anim.holding("ambient")\
    .MoveTo(o.bg, Vector2(10, 0), 2.0)
|>

# Stop a specific holding group:
<|
_ctx.animation.stop_holding_group("ambient")
|>
```

### 缓动解析器

`AnimationSystem.parse_easing("inOutCubic")` 支持 Nova 风格缓动字符串，返回 Godot Tween 枚举。支持的类型：Linear、Sine、Quint、Quart、Quad、Expo、Elastic、Cubic、Circ、Bounce、Back、Spring。前缀：`in`、`out`、`inOut`、`outIn`。

---

## 中断 / 小游戏 API（Phase 9）

中断协议允许小游戏或外部系统接管 VN 控制，完成后无缝恢复。

```gdscript
# 开始中断（暂停对话推进、auto/skip 模式）：
<| var interrupt_id = begin_interrupt() |>

# ... 小游戏逻辑 ...

# 结束中断（创建 checkpoint，恢复对话）：
<| end_interrupt(interrupt_id) |>

# 检查是否处于中断状态：
<| if is_interrupt_active(): ... |>
```

| 方法 | 签名 | 说明 |
|------|------|------|
| `begin_interrupt` | `begin_interrupt() -> int` | 开始中断，返回中断 ID |
| `end_interrupt` | `end_interrupt(interrupt_id: int) -> void` | 结束中断，自动 checkpoint |
| `is_interrupt_active` | `is_interrupt_active() -> bool` | 查询中断状态 |

中断期间：
- 点击/键盘推进被阻止
- Auto/Skip 模式被暂停
- `end_interrupt()` 会自动调用 `CheckpointManager.create_checkpoint()` 保存状态

---

## 完整示例

```
# ===== 序章 =====

@<|
label("prologue", "序章")
is_start()
|>

<|
set_box()
trans("fade", 0.5)
show("bg", "backgrounds/train_station")
play_bgm("music/bgm_opening.ogg", 1.0)
|>
（列车到站的广播声）

<|
show_char("protagonist", { body="casual", face="neutral" }, [400, 0, 0.9])
set_avatar("protagonist")
|>
主人公：：终于到了啊...

<|
set_layer("protagonist", "face", "surprised")
shake(5.0, 0.3)
play_se("se/surprise.ogg")
|>
主人公：：这里怎么一个人都没有？！

# 设置变量
<|
set_var("met_heroine", false)
|>

<|
trans("fade", 0.3)
show("bg", "backgrounds/street")
|>
沿着站台走了一段路，远处传来了脚步声。

# 分支选择
选项：要上前查看吗？
@<|
branch([
    { dest="meet_heroine", text="上前查看" },
    { dest="ignore", text="继续走路" },
])
|>

# ===== 路线 A =====

@<| label("meet_heroine", "遇见女主角") |>
<|
set_var("met_heroine", true)
show_char("heroine", { body="uniform", face="shy" }, [500, 0, 0.85])
set_avatar("heroine")
trans("fade", 0.3)
|>
少女：：那个...请问...

<| set_layer("heroine", "face", "smile") |>
少女：：你知道这个车站在哪里可以出去吗？

@<| jump_to("common_after_meet") |>

# ===== 路线 B =====

@<| label("ignore", "无视") |>
<| clear_avatar() |>
主人公：：算了，不管了。

@<| jump_to("common_after_meet") |>

# ===== 汇合 =====

@<| label("common_after_meet", "汇合") |>
<|
trans("fade", 0.5)
play_bgm("music/bgm_daily.ogg", 0.5)
|>
故事继续...

@<| is_end() |>
```

---

## 流程图结构

剧本解析后形成一个有向图（FlowChartGraph）：

- **节点**（FlowChartNode）：由 `label()` 创建，包含有序的对话条目列表
- **跳转**（jump_to）：节点间的无条件跳转边
- **分支**（branch）：用户可选的多条跳转边

**运行时流程：**

1. 从 `is_start` 节点开始
2. 按顺序播放每个对话条目（先执行 lazy block 的演出代码，再显示文本等待点击）
3. 所有条目播放完毕后检查跳转/分支
4. 如果有 `jump_to`，自动跳转
5. 如果有 `branch`，显示选项让用户选择
6. 如果都没有且标记了 `is_end`，游戏结束
