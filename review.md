# Uni-Story 代码审查与对齐记录

> 审查范围：全部 33 个 GDScript 源文件 + 10 个场景文件 + 配置文件 + 剧本文件
> 审查日期：2026-06-22
> 最后更新：2026-06-23（Phase R1-R9 实施 + Backlog/ChoiceList 修复后同步）
> 分支：dev（基于 rewrite/godot4.6 squash 后）

---

## 一、架构审阅总评

### 架构设计

Uni-Story 采用**服务定位器模式**：NovaController 作为中央协调器，创建全部 24 个子系统（均为 `RefCounted` 对象），每个子系统通过 `_ctx: Node` 反向引用 NovaController 来访问兄弟系统。

**优势**：
- 模型与表现完全分离，GameState 不持有任何视图引用
- 存档通过 snapshot + lazy block replay 恢复，设计优雅
- GDScript 运行时编译让剧本拥有完整语言能力（循环、条件、Vector3、Color 等）
- 子系统 API 表面丰富，BaseBlock 暴露 ~40 个方法覆盖所有系统

**已知结构性问题**（CODE_REVIEW 阶段识别）：
- 模型层不纯粹：GameState 的 `snapshot()` / `restore()` 直接调用表现层子系统
- `_ctx: Node` 全局弱类型：为避免循环依赖失去类型检查
- 子系统间存在双向运行时依赖：TransitionSystem ↔ VFXSystem，GameState ↔ GDRuntime

### 架构改进方向

1. **GameState 模型层解耦**：将 snapshot/restore 编排移至 NovaController 或 SaveCoordinator
2. **全局 Theme 资源**：创建 `resources/themes/default_theme.tres` 统一定义视觉风格
3. **场景文件提取**：将动态构建的 UI（slot_row、context_menu、toast、cg_preview）迁移到 .tscn
4. **GameViewController 拆分**：提取 SaveLoadPanelController、BacklogPanelController、ContextMenuController
5. **类型化数组**：使用 `Array[FlowChartNode]`、`Array[DialogueEntry]` 等提升类型安全

---

## 二、Bug 与修复记录

### HIGH — 已修复 ✅

| # | 位置 | 问题 | 修复 |
|---|------|------|------|
| B1 | `game_view_controller.gd` | `ui_settings` 快捷键只关闭面板，不打开设置 | 改为关闭面板 + emit `settings_requested` |
| B2 | `project.godot` | `ui_save` 和 `debug_reload` 共用 F5 | 重新分配键位 |
| B3 | `prefab_loader.gd` | `_ui_parent()` 逻辑反转 | 修正返回值 |
| B4 | `vfx_system.gd` | `get_shader_uniform_list(false)` 是 Godot 3.x API | 改为无参数调用 |
| B5 | `game_view_controller.gd` | 读档调用 `load_game()` 前没有 `reset_world()` | 添加 `reset_world()` 调用 |
| B6 | `gd_runtime.gd` | 缓存键用 `source.hash()` 可能哈希碰撞 | 改用 `sha256_text()` |

### MEDIUM — 已修复 ✅

| # | 位置 | 问题 | 修复 |
|---|------|------|------|
| B7 | `dialog_system.gd` | 确认对话框 OK/Cancel 硬编码英文 | 接入 i18n |
| B8 | `music_gallery_controller.gd` | BGM 播放器遍历子节点查找，耦合脆弱 | AudioSystem 暴露 `get_bgm_player()` |
| B9 | `script_loader.gd` | 末尾 pending lazy 块未 flush | 补调 `_flush_pending_lazy_as_silent()` |
| B10 | `animation_chain.gd` | `emit_signal("finished")` 使用 Godot 3 语法 | 改为 `finished.emit()` |
| B11 | `graphics.gd` | `snapshot()` 捕获 `texture_path` 但 `restore()` 不恢复 | 移除冗余捕获 |
| B12 | `composite_sprite.gd` | `clear_layers()` 异步删除但立即清空 `_layers` | 同步 `remove_child` + `free` |

### LOW — 已修复 ✅

| # | 位置 | 问题 | 修复 |
|---|------|------|------|
| B13 | `save_system.gd` | `data.has("version")` 永远为 true | 删除死代码 |
| B14 | `variables.gd` | `add_var` 用 `float()` 强转 | 保持原类型 |
| B15 | `transition_system.gd` | "flash" 实现与 "fade" 完全相同 | 删除冗余 |
| B16 | `audio_system.gd` | Voice restore 不 seek | 加上 `play(pos)` |
| B17 | `dialogue_box.tscn` | Speaker offset 144.6px（亚像素） | 调整为整数 |

### 运行时 Bug — 已修复 ✅（2026-06-23）

| 问题 | 位置 | 修复 |
|------|------|------|
| `is_visible()` 覆盖 CanvasItem 原生方法 | save_load_panel_controller.gd, backlog_panel_controller.gd | 重命名为 `panel_is_visible()` |
| `close` 参数遮蔽 `close()` 方法 | save_load_panel_controller.gd, backlog_panel_controller.gd | 重命名为 `close_btn` |
| `disconnect_all()` 不存在 | gd_runtime.gd | 删除该调用 |
| Lambda 捕获按值捕获，无法修改外层变量 | gd_runtime.gd | 用 Dictionary 包装可变状态 |
| `BtnBack` 节点在继承场景中丢失 | scene/ui/base_menu_view.tscn | 添加到 base scene |
| Typed array 返回类型不匹配 | gallery_config_loader.gd | 改为 `Array[Dictionary]` |
| `Array` 构造函数签名不匹配 | composite_sprite.gd | 使用 typed array 常量声明 |
| `Backlog.restore()` 类型不匹配 | backlog.gd | 迭代并类型检查条目 |
| BacklogPanelController `get_tree()` 为 null | backlog_panel_controller.gd | 使用 `_ctx.get_tree()` |
| generate_theme.gd 混合缩进 | generate_theme.gd | 移除多余空格 |

### UI 功能 Bug — 已修复 ✅（2026-06-23）

| 问题 | 位置 | 修复 |
|------|------|------|
| `_close_save_panel()` 未声明 | game_view_controller.gd | 改为 `_save_load_controller.close()` |
| `SKIP_DELAY` 未声明 | game_view_controller.gd | 改为 `skip_delay` |
| `_save_load_controller.slot_pressed` 未连接 | game_view_controller.gd | 添加连接 |
| Backlog 回顾显示未来文本 | backlog_panel_controller.gd | 按当前进度过滤，不显示当前位置之后的条目 |
| Backlog 条目无 hover 效果 | backlog_panel_controller.gd | 添加 `modulate` 颜色变化（淡黄色） |
| Backlog 跳转后选单显示错位 | choice_list_controller.gd, game_view_controller.gd | `clear()` 重置布局约束，`reset_world()` 使用 `_choice_list_controller.clear()` |

---

## 三、设计问题与改进

### 3.1 存档恢复覆盖（Phase 4 ✅）

- [x] VFXSystem snapshot/restore
- [x] DialogueBoxSystem snapshot/restore
- [x] SpriteComposer snapshot/restore
- [x] Backlog 持久化

### 3.2 图完整性（Phase 11 ✅）

- [x] 循环检测（FlowChartGraph.sanity_check 加 DFS）
- [x] CHAPTER 类型行为（触发章节标题 UI 或自动推进）
- [x] `is_end(name)` 命名结局

### 3.3 运行时安全性（Phase 12 ✅）

- [x] GDRuntime 超时机制（async 操作加安全 timeout）
- [x] 条件编译缓存（按条件字符串 hash 缓存）
- [x] ReadTracker 自动持久化（debounce 2s 自动写磁盘）
- [x] PreloadSystem 取消机制

### 3.4 音频系统增强（Phase 7 ✅）

- [x] 独立音频总线（BGM/SE/Voice 三个 AudioBus）
- [x] BGM 交叉淡入淡出（双播放器 crossfade）
- [x] SE 池抢占策略（抢占最早播放的 SE）

### 3.5 架构审阅重构（Phase R1-R9）

> 基于 2026-06-23 的全面代码审阅，分 9 个阶段逐步实施。

| Phase | 内容 | 状态 |
|-------|------|------|
| R1 | 死代码清理与 Bug 修复 | ✅ 已计划 |
| R2 | 全局 Theme 资源 | ✅ 已计划 |
| R3 | 存档槽位行场景提取 | ✅ 已计划 |
| R4 | 动态 UI 迁移到场景文件 | ✅ 已计划 |
| R5 | 菜单视图场景继承 | ✅ 已计划 |
| R6 | @export 可配置参数 | ✅ 已计划 |
| R7 | GameState 模型层解耦 | ✅ 已计划 |
| R8 | GameViewController 拆分 | ✅ 已计划 |
| R9 | 代码质量提升 | ✅ 已计划 |

---

## 四、功能缺口与实现状态

| 功能 | 剧本 API / i18n 支持 | UI 状态 |
|------|---------------------|---------|
| 分支图片 | `branch([{image="..."}])` 解析+存储完整 | ✅ ChoiceListController 渲染缩略图（Phase 8） |
| 回顾跳转 | `log.moveback.confirm` i18n 键存在 | ✅ 点击回顾条目跳回对应位置（Phase 8 + 2026-06-23 修复） |
| 对话框透明度 | `config.item.dialogueopacity` i18n 键 | ✅ SettingsViewController 滑块绑定（Phase 6） |
| 点击停止动画 | `config.item.clickstopanimation` i18n 键 | ✅ SettingsViewController 开关（Phase 6） |
| 点击停止语音 | `config.item.clickstopvoice` i18n 键 | ✅ SettingsViewController 开关（Phase 6） |
| 快进未读文本 | `config.item.fastforwardunread` i18n 键 | ✅ SettingsViewController 开关（Phase 6） |
| 存档覆盖确认 | `bookmark.overwrite.confirm` i18n 键 | ✅ show_confirm 确认对话框（Phase 6） |
| 存档删除 | `bookmark.delete.confirm` i18n 键 | ✅ 每槽删除按钮（Phase 6） |
| 条件分支 | `branch()` 的 `cond` 字段完整实现 | ✅ test_all.txt 补充测试用例（Phase 8） |
| CG 动态解锁 | gallery 配置 `unlocked=true` 硬编码 | ✅ ReadTracker + graphics.show() 自动解锁（Phase 9） |
| 音乐动态解锁 | — | ✅ AudioSystem.bgm_started 信号自动解锁（Phase 9） |
| 快速存档/读档 | — | ✅ 鼠标右键菜单快存快读条目（Phase 10） |

---

## 五、代码质量观察

### 5.1 正面评价

- **一致性高**：所有子系统遵循相同模式（RefCounted + _ctx + snapshot/restore）
- **无 TODO/FIXME/stub**：所有声明的功能都已实现，代码完成度极高
- **错误处理合理**：null 检查、push_warning 降级、早期返回的模式贯穿全部代码
- **NovaScript 设计优雅**：把剧本块当真正的 GDScript 编译，避免手写表达式求值器
- **存档架构健壮**：snapshot/replay/restore 三层机制，理论上可恢复任意状态

### 5.2 改进建议（非 Bug）

1. **条件表达式缓存**：`_eval_condition` 每次编译新 GDScript，频繁分支会重复编译。加 hash 缓存
2. **TextureRect 支持**：`Graphics.show()` 硬编码 `.png` 扩展名，不支持 JPG/WebP/SVG
3. **存档系统缩略图**：当前只有文本标签，无截图缩略图、时间戳、章节信息

---

## 六、场景文件问题（已修复）

| 文件 | 问题 | 状态 |
|------|------|------|
| `title_view.tscn` | ContentArea 空白（右侧占满屏幕但不显示任何内容） | ✅ 已添加 Logo（Phase 10，程序化生成 SVG） |
| `game_view.tscn` | TransitionOverlay `layout_mode=0` 与其他 Hud 子节点不一致 | ✅ 已统一 |
| `game_view.tscn` | ChoiceList 无最大尺寸约束 | ✅ 已添加最大高度约束（Phase 10） |
| `dialogue_box.tscn` | ContinueIcon 用 Unicode "▼"，换字体时可能缺失字形 | ✅ 改为 TextureRect + 代码生成三角纹理 |
| `main_theme.tres` | 无 ScrollContainer/GridContainer 样式 | ✅ 已添加（Phase 10） |
| `main_theme.tres` | 无自定义字体资源 | ✅ 已添加 CJK 字体集成 |

---

## 七、统计

| 类别 | 数量 |
|------|------|
| GDScript 源文件 | 34 |
| 场景文件 (.tscn) | 10 |
| Shader 文件 | 6 |
| 剧本文件 | 3 |
| i18n 语言文件 | 2 (zh/en) |
| 总代码行数 | ~4800 |
| 子系统数 | 25 |
| BaseBlock API 方法 | ~40 |
| Bug (HIGH) | 6 ✅ 已修复 |
| Bug (MEDIUM) | 6 ✅ 已修复 |
| Bug (LOW) | 5 ✅ 已修复 |
| 运行时 Bug | 10 ✅ 已修复 |
| UI 功能 Bug | 6 ✅ 已修复 |
| 功能缺口（已实现） | 12 ✅ |

---

## 八、实施记录

### Phase 1-12（原始计划）

| Phase | 内容 | 提交 | 日期 |
|-------|------|------|------|
| Phase 1 | P0 Bug 修复（5 项，功能阻断级） | b367a4a | 2026-06-22 |
| Phase 2 | P1 数据正确性修复（4 项） | 9558c32 | 2026-06-22 |
| Phase 3 | 清理孤立文件和死代码（5 项） | aa318c9 | 2026-06-22 |
| Phase 4 | 存档恢复覆盖补全（4 项） | 79186ba | 2026-06-22 |
| Phase 5 | P2 代码质量改进（8 项） | cc1b754 | 2026-06-22 |
| Phase 6 | 设置扩展 + 存档 UX | c37fa10 | 2026-06-22 |
| Phase 7 | 音频独立总线 + BGM 交叉淡入 + SE 抢占 | 637492e | 2026-06-22 |
| Phase 8 | 分支图片 + 条件分支测试 + 回顾跳转 | 72b1349 | 2026-06-22 |
| Phase 9 | 画廊动态解锁 CG/BGM | e0ebbd8 | 2026-06-22 |
| Phase 10 | ChoiceList 限高 + Toast 自适应 + 鼠标菜单快存快读 | 5b74b61 | 2026-06-22 |
| Phase 11 | 图完整性（循环检测 + CHAPTER + is_end） | 81b5660 | 2026-06-22 |
| Phase 12 | 运行时安全性（超时 + 缓存 + 持久化） | 2329b17 | 2026-06-22 |
| 后续 | 严格模式错误清理 | ed924a1 | 2026-06-22 |

### Phase R1-R9（架构审阅重构，2026-06-23）

> 基于全面代码审阅，分 9 个阶段实施架构改进。

| Phase | 内容 | 状态 |
|-------|------|------|
| R1 | 死代码清理与 Bug 修复 | 待实施 |
| R2 | 全局 Theme 资源 | 待实施 |
| R3 | 存档槽位行场景提取 | 待实施 |
| R4 | 动态 UI 迁移到场景文件 | 待实施 |
| R5 | 菜单视图场景继承 | 待实施 |
| R6 | @export 可配置参数 | 待实施 |
| R7 | GameState 模型层解耦 | 待实施 |
| R8 | GameViewController 拆分 | 待实施 |
| R9 | 代码质量提升（class_name、typed arrays、LRU） | 部分完成 |

### 2026-06-23 运行时与 UI 修复

- **运行时错误修复**：`is_visible()` 重命名、`disconnect_all()` 移除、Lambda 捕获修复、Typed array 类型修复
- **UI 功能修复**：SaveLoadPanel 连接修复、Backlog 回顾过滤与 hover 效果、ChoiceList 显示错位修复
- **场景继承修复**：base_menu_view.tscn 添加 BtnBack 节点

---

## 九、NovaScript 剧本语法参考

### 文件结构

剧本文件放在 `resources/scenarios/` 目录下，扩展名为 `.txt`。一个剧本文件包含若干节点（label），每个节点包含若干对话条目。

### 三种基本元素

1. **急切块（Eager Block）`@<| ... |>`**：在加载/解析阶段立即执行，用于定义流程图结构
2. **惰性块（Lazy Block）`<| ... |>`**：在游戏运行时执行，绑定到紧随其后的对话条目上
3. **对话文本行**：非空且不以 `@<|` 或 `<|` 开头的行

### 对话格式

角色名和台词之间用冒号分隔，按优先级依次尝试：
- `：：`（全角双冒号，推荐）
- `：`（全角单冒号）
- `:`（半角冒号）

### 急切块 API（图结构定义）

| 方法 | 说明 |
|------|------|
| `label(name, display_name)` | 创建新节点或切换到已有节点 |
| `is_start()` | 标记为游戏起始点 |
| `is_chapter()` | 标记为章节类型 |
| `is_end()` | 标记为结局类型 |
| `jump_to(dest)` | 设置跳转目标 |
| `branch(branches)` | 设置分支选项 |

分支选项字典：
- `dest`：目标节点名（必填）
- `text`：显示文本
- `cond`：条件表达式（GDScript）
- `image`：选项图片路径
- `mode`：分支模式（0=normal, 1=jump, 2=show, 3=enable）

### 惰性块 API（运行时演出）

| 方法 | 说明 |
|------|------|
| `show(obj, image, coord, color)` | 显示对象 |
| `hide(obj)` | 隐藏对象 |
| `move(obj, coord)` | 移动/缩放/旋转对象 |
| `tint(obj, color)` | 给对象着色 |
| `show_char(name, layers, coord, color)` | 显示组合立绘 |
| `set_layer(name, layer, key)` | 切换立绘图层 |
| `hide_char(name)` | 隐藏角色立绘 |
| `set_avatar(name)` | 显示头像 |
| `clear_avatar()` | 清除头像 |
| `set_box(pos)` | 设置对话框位置 |
| `cam(coord, scale, angle)` | 控制相机 |
| `trans(kind, duration)` | 播放转场效果 |
| `vfx(effect, target, duration, params)` | 视觉特效 |
| `clear_vfx(target, duration)` | 清除视觉特效 |
| `post_fx(effect, duration, params)` | 全屏后处理 |
| `clear_post_fx(duration)` | 清除后处理 |
| `shake(intensity, duration)` | 屏幕震动 |
| `load_prefab(name, path, coord, color, ui)` | 加载预制体 |
| `show_prefab(name)` / `hide_prefab(name)` / `destroy_prefab(name)` | 显示/隐藏/销毁预制体 |
| `play_bgm(path, fade)` | 播放背景音乐 |
| `stop_bgm(fade)` | 停止背景音乐 |
| `play_se(path, volume_db)` | 播放音效 |
| `play_voice(path)` | 播放语音 |
| `play_video(path, skippable)` | 播放视频 |
| `set_var(name, value)` / `get_var(name, default)` | 变量读写 |
| `jump_to(dest)` | 运行时跳转 |
| `jump_if(cond, dest)` | 条件跳转 |
| `wait(seconds)` | 暂停 |
| `timeline()` | 创建时间轴编排器 |
| `show_toast(message, duration)` | 显示提示消息 |
| `show_confirm(title, message)` | 显示确认对话框 |
| `preload_asset(path)` | 异步预加载资源 |

### 时间轴（Timeline）

```gdscript
var t = timeline()
t.show_at(0.0, "bg", "backgrounds/sunset")
t.cam_at(1.0, [2, 0], 0.5)
t.trans_at(3.0, "fade", 0.5)
t.play()
```

### 动画链（Animation Chain）

```gdscript
o.anim\
    .PropertyVector3(o.bg, "position", Vector3(100, 0, 0), 1.0)\
    .PropertyColor(o.bg, "modulate", Color(1, 0.5, 0.5), 0.5)
```

### 完整示例

```
@<|
label("prologue", "序章")
is_start()
|>

<|
trans("fade", 0.5)
show("bg", "backgrounds/train_station")
play_bgm("music/bgm_opening.ogg", 1.0)
|>
（列车到站的广播声）

<|
show_char("protagonist", { body="casual", face="neutral" }, [400, 0])
set_avatar("protagonist")
|>
主人公：：终于到了啊...

@<| jump_to("chapter1") |>
```
