# Uni-Story 代码审查报告

> 审查范围：全部 33 个 GDScript 源文件 + 10 个场景文件 + 配置文件 + 剧本文件
> 审查日期：2026-06-22
> 最后更新：2026-06-22（Phase 6-10 实施后同步）
> 分支：dev（基于 rewrite/godot4.6 squash 后）

---

## 一、架构总览

框架采用"模型-重放"架构：剧本在加载时通过 eager 块构建确定性的 FlowChartGraph（模型），lazy 块存储源码在执行时编译运行（表现层）。25 个子系统全部遵循 `class_name X extends RefCounted` + `_ctx: Node` 模式，通过 NovaController 服务定位器互相访问。

**优势**：
- 模型与表现完全分离，GameState 不持有任何视图引用
- 存档通过 snapshot + lazy block replay 恢复，设计优雅
- GDScript 运行时编译让剧本拥有完整语言能力（循环、条件、Vector3、Color 等）
- 子系统 API 表面丰富，BaseBlock 暴露 ~40 个方法覆盖所有系统

---

## 二、Bug（按严重程度排序）

### HIGH

| # | 位置 | 问题 | 影响 |
|---|------|------|------|
| B1 | `game_view_controller.gd` L261-265 | `ui_settings` 快捷键 (F1) 只关闭面板，不打开设置 | 按键无响应 |
| B2 | `project.godot` + `shortcut_manager.gd` | `ui_save` 和 `debug_reload` 共用 F5 | 调试模式下 F5 同时触发存档和热重载 |
| B3 | `prefab_loader.gd` L222-236 | `_ui_parent()` 逻辑反转：找到 GameView 时返回 null | UI 预制体永远无法加载 |
| B4 | `vfx_system.gd` L140 | `get_shader_uniform_list(false)` 是 Godot 3.x API，4.6 无此参数 | 可能运行时崩溃 |
| B5 | `game_view_controller.gd` `_on_slot_pressed` | 游戏内读档调用 `load_game()` 之前没有调 `reset_world()` | 读档后残留旧场景状态（prefab/视频/音频） |
| B6 | `gd_runtime.gd` L32 | 缓存键用 `source.hash()`（32位整数），大型项目可能哈希碰撞 | 错误块被执行 |

### MEDIUM

| # | 位置 | 问题 | 影响 |
|---|------|------|------|
| B7 | `dialog_system.gd` L144-152 | 确认对话框 OK/Cancel 按钮硬编码英文，未接入 i18n | 切换语言后按钮仍显示英文 |
| B8 | `music_gallery_controller.gd` L35-41 | BGM 播放器通过遍历子节点按名字查找，耦合脆弱 | AudioSystem 改名则自动连播失效 |
| B9 | `script_loader.gd` L35 | 最后一个文件末尾的 pending lazy 块未 flush | 尾部 lazy 块静默丢失 |
| B10 | `animation_chain.gd` L92 | `emit_signal("finished")` 使用 Godot 3 语法 | 风格不一致，4.x 推荐 `finished.emit()` |
| B11 | `graphics.gd` L126-170 | `snapshot()` 捕获 `texture_path` 但 `restore()` 不恢复 | 快照数据冗余，可能误导开发者 |
| B12 | `composite_sprite.gd` L52-54 | `clear_layers()` 用 `queue_free` 异步删除但立即清空 `_layers` | 同帧内引用层会悬空 |

### LOW

| # | 位置 | 问题 | 影响 |
|---|------|------|------|
| B13 | `save_system.gd` L35-36 | `data.has("version")` 永远为 true（刚赋值） | 死代码 |
| B14 | `variables.gd` L30 | `add_var` 用 `float()` 强转，整数变浮点 | 类型意外变化 |
| B15 | `transition_system.gd` L39-47 | "flash" 实现与 "fade" 完全相同 | 冗余代码 |
| B16 | `audio_system.gd` L110-119 | Voice restore 不 seek 到保存的播放位置（BGM 会 seek） | 语音位置丢失 |
| B17 | `dialogue_box.tscn` L27 | Speaker offset 144.6px（亚像素），可能渲染模糊 | 轻微视觉瑕疵 |

---

## 三、设计问题

### 3.1 存档恢复覆盖不完整

当前 `snapshot()` 收集 5 个子系统：animation, audio, prefab_loader, camera, graphics。

**缺失的子系统**：
- **VFXSystem**：无 snapshot/restore，活跃 shader 效果（blur/grayscale/后处理）存读档后丢失
- **DialogueBoxSystem**：对话框位置不存档，`set_box("center")` 后存档恢复位置取决于 replay 窗口
- **SpriteComposer**：立绘图层不存档，依赖 lazy block replay 重建，但只覆盖当前节点
- **TransitionSystem**：转场中存档会丢失 overlay 状态

**影响**：存档正确性完全依赖剧本作者在 lazy 块中正确设置所有表现状态。跨节点的 VFX/立绘状态在读档后会丢失。

### 3.2 图完整性

- **无循环检测**：`FlowChartGraph.sanity_check()` 验证跳转目标存在，但不检测 A→B→A 的无限循环。`advance()` 会永久挂起
- **CHAPTER 类型无行为**：`is_chapter()` 设置节点类型为 CHAPTER，但 GameState 和所有 ViewController 都不区分 CHAPTER 和 NORMAL
- **`is_debug` 标志无行为**：标记了但无代码过滤或高亮
- **`is_end(name)` 忽略 name 参数**：不支持命名结局（用于画廊解锁追踪等）

### 3.3 运行时安全性

- **GDRuntime 无超时机制**：死循环或永不完成的 Tween 会永久挂起故事
- **`_eval_condition` 编译失败静默返回 false**：隐藏剧本作者的条件表达式错误
- **`_eval_condition` 命名空间碰撞**：条件表达式中变量名若与 BaseBlock 方法名冲突（如 `show`），会调用方法而非读变量
- **PreloadSystem 无取消机制**：预加载请求无法取消，玩家切走后仍在加载
- **ReadTracker 不自动持久化**：`mark_read()` 更新内存但不写磁盘，崩溃则丢失已读记录

### 3.4 信号与死代码

| 信号 | 位置 | 状态 |
|------|------|------|
| `game_state.node_changed` | game_state.gd | 定义并 emit 但无消费者 |
| `game_state.game_started` | game_state.gd | 定义并 emit 但无消费者 |
| `debug_unlock` (KEY_U) | project.godot | 定义输入动作但无 `_unhandled_input` 处理 |

| 文件 | 状态 |
|------|------|
| `scripts/ui/chapter_select_view_controller.gd.uid` | 孤立 .uid 文件，对应 .gd 已删除 |
| `scene/ui/dialogue_entry.tscn` | 无脚本或场景引用 |
| `REVIEW_REGRESSION_FILES` / `REVIEW_SANITY_FILES` | NovaController 引用的剧本路径不存在（被 @export 门控，默认不加载） |

---

## 四、功能缺口（场景系统支持但 UI 未暴露）

| 功能 | 剧本 API / i18n 支持 | UI 状态 |
|------|---------------------|---------|
| 分支图片 | `branch([{image="..."}])` 解析+存储完整 | ✅ ChoiceListController 渲染缩略图（Phase 8） |
| 回顾跳转 | `log.moveback.confirm` i18n 键存在 | ✅ 点击回顾条目跳回对应位置（Phase 8） |
| 对话框透明度 | `config.item.dialogueopacity` i18n 键 | ✅ SettingsViewController 滑块绑定（Phase 6） |
| 点击停止动画 | `config.item.clickstopanimation` i18n 键 | ✅ SettingsViewController 开关（Phase 6） |
| 点击停止语音 | `config.item.clickstopvoice` i18n 键 | ✅ SettingsViewController 开关（Phase 6） |
| 快进未读文本 | `config.item.fastforwardunread` i18n 键 | ✅ SettingsViewController 开关（Phase 6） |
| 角色独立音量 | `config.item.charactervolume.*` i18n 键 | 无每角色音量控制 |
| 操作帮助 | `title.menu.help` i18n 键 | 标题界面无帮助按钮 |
| 存档覆盖确认 | `bookmark.overwrite.confirm` i18n 键 | ✅ show_confirm 确认对话框（Phase 6） |
| 存档删除 | `bookmark.delete.confirm` i18n 键 | ✅ 每槽删除按钮（Phase 6） |
| 条件分支 | `branch()` 的 `cond` 字段完整实现 | ✅ test_all.txt 补充测试用例（Phase 8） |
| `stop_bgm` | BaseBlock API 已实现 | 无任何剧本使用 |
| `show_toast` / `show_confirm` | BaseBlock API 已实现 | 仅在 GameViewController 内部使用，剧本中无示例 |
| CG 动态解锁 | gallery 配置 `unlocked=true` 硬编码 | ✅ ReadTracker + graphics.show() 自动解锁（Phase 9） |
| 音乐动态解锁 | — | ✅ AudioSystem.bgm_started 信号自动解锁（Phase 9） |
| 快速存档/读档 | — | ✅ 鼠标右键菜单快存快读条目（Phase 10） |

---

## 五、代码质量观察

### 5.1 正面评价

- **一致性高**：所有子系统遵循相同模式（RefCounted + _ctx + snapshot/restore），学习一个新系统即可理解全部
- **无 TODO/FIXME/stub**：所有声明的功能都已实现，代码完成度极高
- **错误处理合理**：null 检查、push_warning 降级、早期返回的模式贯穿全部代码
- **NovaScript 设计优雅**：把剧本块当真正的 GDScript 编译，避免手写表达式求值器
- **存档架构健壮**：snapshot/replay/restore 三层机制，理论上可恢复任意状态

### 5.2 改进建议（非 Bug）

1. **条件表达式缓存**：`_eval_condition` 每次编译新 GDScript，频繁分支会重复编译相同条件。加 hash 缓存
2. **~~BGM 交叉淡入淡出~~**：✅ 已实现双播放器 crossfade（Phase 7）
3. **~~SE 池耗尽策略~~**：✅ 已改为抢占最早播放的 SE（Phase 7）
4. **~~AudioSystem 音频总线~~**：✅ 已创建 BGM/SE/Voice 独立总线路由到 Master（Phase 7）
5. **TextureRect 支持**：`Graphics.show()` 硬编码 `.png` 扩展名，不支持 JPG/WebP/SVG
6. **Backlog 持久化**：文本回顾历史不存入存档，读档后回顾面板为空
7. **~~Gallery 动态解锁~~**：✅ CG/BGM 已接入 ReadTracker 和 AudioSystem 信号（Phase 9）

---

## 六、场景文件问题

| 文件 | 问题 |
|------|------|
| `title_view.tscn` | ContentArea 空白（右侧占满屏幕但不显示任何内容，可放 logo 或动画背景） |
| `game_view.tscn` | TransitionOverlay `layout_mode=0` 与其他 Hud 子节点不一致 |
| `game_view.tscn` | ~~ChoiceList 无最大尺寸约束~~ | ✅ 已添加最大高度约束（6 项 + ScrollContainer）（Phase 10） |
| `dialogue_box.tscn` | ContinueIcon 用 Unicode "▼"，换字体时可能缺失字形 |
| `main_theme.tres` | 无 ScrollContainer/GridContainer 样式，CG 画廊网格和滚动条用默认样式 |
| `main_theme.tres` | 无自定义字体资源，CJK 覆盖依赖平台默认字体 |

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
| Bug (HIGH) | 6 |
| Bug (MEDIUM) | 6 |
| Bug (LOW) | 5 |
| 功能缺口（未实现） | 4 |
| 功能缺口（已实现） | 12 |
| 设计问题 | 4 大类 |
| 死代码/孤立文件 | 5 |

---

## 八、Phase 6-10 实施记录

| Phase | 内容 | 提交 | 日期 |
|-------|------|------|------|
| Phase 6 | 设置扩展 + 存档 UX | c37fa10 | 2026-06-22 |
| Phase 7 | 音频独立总线 + BGM 交叉淡入 + SE 抢占 | 637492e | 2026-06-22 |
| Phase 8 | 分支图片 + 条件分支测试 + 回顾跳转 | 72b1349 | 2026-06-22 |
| Phase 9 | 画廊动态解锁 CG/BGM | e0ebbd8 | 2026-06-22 |
| Phase 10 | ChoiceList 限高 + Toast 自适应 + 鼠标菜单快存快读 | 5b74b61 | 2026-06-22 |
| 后续修复 | 严格模式错误清理（get_bus_layout/shadowed var/confusable decl/unused param） | ed924a1 | 2026-06-22 |
