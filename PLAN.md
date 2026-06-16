# Nova2 重写开发计划（对齐 issue #1）

## 0. 架构决策

issue #1 规定：**框架用 C#，演出脚本用 GDScript，保留原 NovaScript 格式**。
`master` 分支已按此实现（NovaController/GameState/ScriptLoader/NovaParser/
GDRuntime + gdscript runtime），但 `rewrite/godot4.6` 分支曾把整套 C# 架构换成
一个 1177 行的手写字符串解释器（旧 `GameRoot.gd`）。

本次重写在 **纯 GDScript** 路线下，恢复了开发者本来的设计思想：
**把每个演出脚本块当作真正的 GDScript 编译运行**，而不是用正则/子串手工解析。
本机没有 .NET，无法编译 C#，因此用 GDScript 复刻 C# 核心；接口与职责与 master
对齐，未来装好 .NET 后可逐步迁回 C#。

核心洞察：`GDScript.source_code` + `reload()` + `.new()` 可以在运行时编译
GDScript。于是 `o.anim.X().Y()` 链式调用、`Vector3(...)`、`Color(...)`、字典等
全部交给 GDScript 编译器，手写解释器彻底删除。

## 1. 已完成（本分支，新架构）

### 运行时（scripts/runtime/）
- `base_block.gd`：所有演出脚本块的基类，暴露 label/jump_to/branch/is_*、
  show/hide/move/tint、set_box、play_bgm/se/voice、cam、trans、wait 等 API。
- `gd_runtime.gd`：把每个 `<|...|>` / `@<|...|>` 块包成 `extends BaseBlock`
  的类，编译、实例化、注入 `_ctx`、调用 `run()`。带编译缓存。
- `graphics.gd`：show/hide/move/tint，支持按名字或节点引用定位对象。
- `animation_system.gd` + `animation_chain.gd`：`o.anim` 链式动画，
  链内顺序、跨语句并行（基于 Godot Tween）。
- `audio_system.gd`：BGM（依赖导入设置的 loop point）、SE 池、Voice。
- `camera_system.gd`：通过变换 world 容器实现逻辑相机（移动/缩放/旋转）。
- `transition_system.gd`：fade / fade_in / flash 全屏转场。
- `dialogue_box_system.gd`：`set_box` 预设（bottom/top/center/left/right/full/hide）。

### 核心模型（scripts/core/）
- `nova_parser.gd`：把剧本切成 eager / lazy / text 块。
- `script_loader.gd`：跑 eager 块构建 FlowChartGraph；lazy 块存源码（不执行）。
- `flow_chart_node.gd` / `flow_chart_graph.gd` / `dialogue_entry.gd`：数据模型。
- `object_manager.gd`：`o`（对象）/`c`（常量）字典。
- `game_state.gd`：**纯模型**，遍历流程图、执行 lazy 块、发信号；不持有视图引用，
  保证相同输入产生相同状态（可重放，利于存档/跳转/快进）。

### 控制器与视图
- `NovaController.gd`：唯一的 Node 中枢，创建并持有所有子系统（满足规范
  “所有 Singleton 从 NovaController 初始化”），用代码构建 HUD/world 场景树，
  把模型信号桥接到视图。
- `scene/game.tscn`：精简为只挂 NovaController 的根节点。

### 验证（通过 Godot MCP 实机运行）
- 标题界面 + 章节选择（6 个章节全部正确解析）。
- 对话播放、说话人解析（`角色：：内容`）。
- lazy `show()` 实机加载贴图。
- 动画链：顺序与并行，position/scale/rotation/modulate 终值正确。
- 相机：`cam([200,0,1.2])` → world 位移 (-200,0)、缩放 1.2，复位正确。
- 转场：flash 触发。
- 分支 + 跳转：选项渲染、选择后跳转到目标节点。

## 2. 路线图进度（对照 issue #1）

演出系统（开发者要求“先做完再做 UI”）：
- [x] NovaScript parser（真 GDScript 编译）
- [x] 基本 GameState（标题、对话框、选项）
- [x] 演出脚本（真执行，非 print）
- [x] AssetLoader（贴图按 resource_root + folder 解析）
- [x] 图片（前后端分离：脚本操作 model，视图随信号刷新）
- [x] 动画系统（o.anim，Tween）
- [x] CameraController（逻辑相机）
- [x] 转场
- [x] BGM / 音效 / 语音（API 完成，待音频素材接入演示）
- [x] 立绘合成系统（多图层立绘：body/clothes/face/mouth/effect，可单独换层）
- [x] 头像（对话框内肖像，随说话人显示/切换）
- [x] 对话框文字动画（逐字 visible_ratio，点击快进，结束图标）
- [x] 变量（set_var/get_var/add_var + jump_if 运行时条件跳转）
- [x] VFX（对象 shader：blur/grayscale/dissolve；震屏；shader 转场：dissolve/wipe；全屏后处理：chromatic/vignette）
- [x] 自动播放与快进模式（Auto 定时推进 + Skip 跳过已读，ReadTracker 持久化已读记录，存读档集成）
- [ ] 加载场景（PrefabLoader）
- [ ] TimelineController
- [ ] 视频
- [ ] 脚本热加载

UI / 系统（演出做完后）：
- [x] 存档系统（每槽一个 JSON 文件，model 快照 + 重放；user://saves/）
- [x] 存档界面（6 槽存/读档面板）
- [x] 文本回顾界面（Backlog，回顾按钮，滚动历史）
- [x] I18n 本地化（zh/en 双语字典，所有可见 UI 文案已接入 `_t()`，locale 回退链路）
- [ ] ViewManager
- [ ] 预加载系统 / 随意缩放窗口 / 对话框完整功能 / 鼠标菜单 / 警告框 / 通知框
- [ ] 设置界面 / 快捷键 / 图片鉴赏 / 音乐鉴赏 / 手柄支持 / 立绘裁剪工具

## 3. 下一步建议顺序
1. **ViewManager**：统一标题/游戏/存档/设置等视图切换。
2. **设置界面 + 快捷键**：文字速度、音量、跳过已读等。
3. **加载场景（PrefabLoader）**。
4. **脚本热加载**：编辑剧本后免重启刷新流程图。

## 4. 测试剧本
- `test_runtime.txt`：自检（show/cam/trans/branch/jump）。
- `test_animation.txt`：动画链顺序/并行。
- `test_char.txt`：立绘合成、换表情、头像。
- `test_var.txt`：变量运算与 jump_if 条件跳转。
- `ch1/ch2/plan_demo/demo_full`：综合演示。

## 5. 已实现的演出脚本 API（BaseBlock）
- 流程：`label` `jump_to` `jump_if` `branch` `is_start/is_unlocked_start/is_end/...`
- 图像：`show` `hide` `move` `tint`
- 立绘：`show_char` `set_layer` `hide_char`；头像：`set_avatar` `clear_avatar`
- 动画：`o.anim.PropertyVector3(...).PropertyColor(...)`（链=顺序，分语句=并行）
- 音频：`play_bgm` `stop_bgm` `play_se` `play_voice`
- 镜头/转场：`cam` `trans`；对话框：`set_box`
- 变量：`set_var` `get_var` `has_var` `add_var`；其它：`wait` `print`
