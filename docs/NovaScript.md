# NovaScript 剧本语法手册

NovaScript 是 Uni-Story 视觉小说框架的剧本领域语言。剧本文件（`.txt`）由 `NovaParser` 分词、`ScriptLoader` 构建流程图、`GDRuntime` 在运行时编译执行。

## 文件结构

剧本文件放在 `resources/scenarios/` 目录下，扩展名为 `.txt`。一个剧本文件包含若干 **节点**（label），每个节点包含若干 **对话条目**（text line + 可选的 lazy block）。

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

角色名和台词之间用冒号分隔，按优先级依次尝试：

| 分隔符 | 说明 | 示例 |
|--------|------|------|
| `：：` | 全角双冒号（推荐） | `仁菜：：你好啊` |
| `：` | 全角单冒号 | `仁菜：你好啊` |
| `:` | 半角冒号 | `Alice: Hello` |

如果行中没有冒号，则整行作为旁白文本（speaker 为空）。

---

## 块属性（Block Attributes）

可以在块开头添加属性前缀 `@[key=value; ...]`：

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
- 属性会作为默认值传递给 `branch()` 的选项

---

## 急切块 API（图结构定义）

以下方法在 `@<| ... |>` 中调用，用于定义流程图。

### `label(name, display_name = null)`

创建一个新节点（或切换到已有节点），后续所有内容都属于该节点。

```
@<| label("opening", "序章") |>
```

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

### `is_end()`

标记当前节点为结局类型。到达该节点末尾时游戏结束。

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

选项字典的键：

| 键 | 类型 | 说明 |
|----|------|------|
| `dest` | String | 目标节点名（必填） |
| `text` | String | 显示文本 |
| `mode` | int/String | 分支模式（见下方） |
| `cond` | String | 条件表达式（GDScript） |
| `image` | String | 选项图片路径 |

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

#### `set_box(pos_name = "bottom")`

设置对话框位置/样式。可选值：`"bottom"`、`"center"`、`"top"`、`"hide"`、`"full"`、`"left"`、`"right"`。

```
<| set_box("center") |>
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
