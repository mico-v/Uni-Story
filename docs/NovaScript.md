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
- 常用播放 API 兼容：`play()`、`sound()`、`auto_voice_on/off()`、`set_auto_voice_delay()`、`box_hide_show()` 等。
- 常用 Nova 常量兼容：`pos_c/pos_l/pos_r/pos_cl/pos_cr`、`bg/fg/cg/bgm/bgs/voice`。
- Nova 示例角色名兼容：`ergong`、`gaotian`、`qianye`、`xiben` 可映射到 `resources/Standings/` 下的组合立绘。

当前限制：

- 不执行完整 Lua；`pairs`、`ipairs`、协程、元表、require、任意 Lua 标准库都不属于 Phase 2 范围。
- 只翻译常见 Nova 剧本形态；复杂多行表达式和动态拼接可能需要手动迁移为 GDScript 写法。
- Nova Lua runtime API 尚未完整对齐，`__Nova` 仅有少量兼容替换。
- `anim` / `anim_hold` 当前是“能播放、不崩溃”的兼容代理，不等价于完整 NovaAnimation；复杂并行组、暂停恢复、shader/VFX 参数动画在 Phase 6/7 完善。
- `auto_voice_*` 当前是 API 兼容入口，真实自动语音队列、角色语音编号调度和恢复策略仍待后续实现。
- `is_save_point()` 目前只写入流程图节点标记，完整 checkpoint/bookmark 恢复体系在 Phase 3 实现。
- 章节选择、debug start 展示策略和解锁 UI 在 Phase 4 完成。

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

对目标施加视觉特效。已知效果：`"blur"`、`"grayscale"`。

#### `clear_vfx(target, duration = 0.3)`

移除目标上的视觉特效。

#### `post_fx(effect_name, duration = 0.5, params = {})`

全屏后处理特效。已知效果：`"vignette"`、`"chromatic"`。

#### `clear_post_fx(duration = 0.3)`

移除全屏后处理。

#### `shake(intensity = 10.0, duration = 0.5)`

屏幕震动。

```
<|
vfx("blur", "bg", 0.5)
shake(15.0, 0.3)
post_fx("vignette")
|>
```

### Prefab（预制体）

#### `load_prefab(name, path, coord = null, color = null, ui = false)`

加载一个场景预制体。

#### `show_prefab(name)` / `hide_prefab(name)` / `destroy_prefab(name)`

显示、隐藏、销毁预制体。

```
<|
load_prefab("clock", "prefabs/clock.tscn", [500, 100])
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

#### `play_voice(path)`

播放语音。

```
<|
play_bgm("music/bgm01.ogg", 1.0)
play_se("se/door.ogg")
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

#### `preload_asset(path)`

异步预加载资源文件。

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

兼容代理会优先把简单动作映射到当前运行时，无法完整表达的 NovaAnimation 行为会退化为 no-op 或基础等待。它用于保障 Nova 原剧本可基础播放；成熟动画系统仍按 PLAN 的 Phase 6 继续建设。

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
