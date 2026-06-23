# Uni-Story 开发计划

> 当前分支：dev | 引擎：Godot 4.6 | 子系统：25

---

**按照PLAN开发，项目进度记录进review.md，随时根据进度同步文档，推进开发，优化策略**

## 一、已完成功能

### 核心引擎
- NovaScript 解析器（eager/lazy/text 块 + 属性语法）
- GDRuntime（运行时 GDScript 编译执行 + 缓存）
- FlowChartGraph（流程图 + 分支 + 跳转 + 条件求值）
- GameState（状态机 + snapshot/restore + lazy block replay）
- SaveSystem（6 槽 + 自动存档 + JSON 持久化）
- Variables（变量存取 + 条件跳转 jump_if）
- I18n（zh/en 双语 + locale 回退 + 剧本路径本地化）
- Backlog（200 条滚动历史）
- ReadTracker（已读记录持久化 + Skip 模式集成 + CG/音乐画廊解锁追踪）
- ObjectManager（对象/常量注册 + 冻结语义）
- ShortcutManager（快捷键自定义 + ConfigFile 持久化）
- HotReload（文件轮询 + debounce + 自动重新解析）
- PreloadSystem（ResourceLoader 异步后台加载）
- ViewManager（视图注册/切换/过渡动画）

### 运行时子系统
- Graphics（show/hide/move/tint + 名字解析）
- AudioSystem（独立 BGM/SE/Voice 总线 + 交叉淡入淡出 + SE 抢占策略）
- CameraSystem（逻辑 2D 相机：移动/缩放/旋转）
- AnimationSystem + AnimationChain（o.anim 链式 Tween）
- TransitionSystem（fade/flash/fade_out/fade_in）
- DialogueBoxSystem（7 种锚点预设 + 透明度控制）
- VFXSystem（对象 shader + 震屏 + 全屏后处理 + shader 转场）
- SpriteComposer + CompositeSprite（多图层立绘）
- AvatarSystem（对话框内肖像）
- PrefabLoader（.tscn 运行时加载 + ObjectManager 注册 + snapshot）
- VideoSystem（全屏播放 + 跳过）
- Timeline（轨道式调度器）
- DialogSystem（Toast + Confirm）

### UI 层
- NovaController（瘦协调器 ~480 行 + 画廊解锁管理 + 4 项 gameplay 设置分发）
- GameViewController（对话/打字机/选项/自动/快进/存读档面板/回顾跳转/鼠标菜单快存快读 ~1060 行）
- TitleViewController（GALGAME 左侧列表菜单）
- SettingsViewController（文字速度/音量/全屏/语言/字体/快捷键 + gameplay 设置 + snapshot/apply_i18n）
- SaveLoadController（独立存读档视图 + 侧栏）
- CgGalleryController（缩略图网格 + 全屏预览 + 动态解锁）
- MusicGalleryController（曲目列表 + 三种播放模式 + BGM 信号集成）
- ChoiceListController（分支选项渲染 + 图片缩略图 + 最大高度约束）

### CI/CD
- GitHub Actions workflow（tag 触发，Win/Linux/Android 并行编译 + Release）
- Export presets（Windows x86_64 / Linux x86_64 / Android arm64）

---

## 二、Bug 修复（优先级从高到低）

### P0 — 功能阻断（Phase 1 ✅）

- [x] **B1 F1 设置快捷键失效**：`ui_settings` 处理只关闭面板不打开设置。改为：关闭面板 + emit `settings_requested`
- [x] **B3 `_ui_parent()` 逻辑反转**：PrefabLoader 的 UI 挂载方法找到 GameView 时返回 null，UI 预制体无法加载
- [x] **B4 VFXSystem API 过期**：`get_shader_uniform_list(false)` 在 Godot 4.6 可能报错，改为无参数调用
- [x] **B5 游戏内读档残留**：`_on_slot_pressed` 的 load 路径调 `load_game()` 前需先 `reset_world()`
- [x] **B2 F5 快捷键冲突**：`ui_save` 和 `debug_reload` 共用 F5，重新分配键位

### P1 — 数据正确性（Phase 2 ✅）

- [x] **B6 GDRuntime 哈希碰撞**：`source.hash()` 改 `source.sha256_text()` 或全字符串缓存
- [x] **B9 尾部 lazy 块丢失**：`script_loader.gd` 的 `load_all()` 末尾补调 `_flush_pending_lazy_as_silent()`
- [x] **B7 确认对话框未 i18n**：`dialog_system.gd` OK/Cancel 按钮接入 `_t("alert.confirm")` / `_t("alert.cancel")`
- [x] **B12 CompositeSprite 层悬空引用**：`clear_layers()` 改为同步 `remove_child` + `free`，或等一帧后再清空 `_layers`

### P2 — 代码质量（Phase 5 ✅）

- [x] **B8 MusicGallery BGM 发现脆弱**：改为 AudioSystem 暴露 `get_bgm_player()` 方法
- [x] **B10 AnimationChain 信号语法**：`emit_signal("finished")` 改为 `finished.emit()`
- [x] **B11 Graphics snapshot 冗余**：移除 `texture_path` 捕获（restore 不使用）或在 restore 中恢复纹理
- [x] **B13 SaveSystem 死代码**：删除 `data.has("version")` 永远为 true 的检查
- [x] **B14 Variables 类型偏移**：`add_var` 保持原类型（整数加整数仍为整数）
- [x] **B15 TransitionSystem "flash" 重复**：删除与 "fade" 相同的实现，或让 flash 有不同的视觉行为
- [x] **B16 Voice restore 缺 seek**：AudioSystem voice restore 加上 `play(pos)` 与 BGM 对齐

---

## 三、架构改进

### 3.1 存档恢复覆盖（Phase 4 ✅）

- [x] **VFXSystem snapshot/restore**：捕获活跃的 shader 参数和 uniform 值，restore 时重新应用
- [x] **DialogueBoxSystem snapshot/restore**：保存当前预设名（bottom/center/etc.），restore 时重新定位
- [x] **SpriteComposer snapshot/restore**：捕获每个角色名的图层状态，restore 时重建
- [x] **Backlog 持久化**：存入存档 JSON，读档后回顾面板保留历史

### 3.2 图完整性（Phase 11 ✅ — `81b5660`）

- [x] **循环检测**：`FlowChartGraph.sanity_check()` 加 DFS 检测 A→B→A 路径，报告为 error
- [x] **CHAPTER 类型行为**：让 CHAPTER 节点触发章节标题 UI 或自动推进（不等待点击）
- [x] **`is_end(name)` 命名结局**：存储结局名称，供画廊解锁和成就系统查询

### 3.3 运行时安全性（Phase 12 ✅ — `2329b17`）

- [x] **GDRuntime 超时机制**：async 操作加安全 timeout（默认 30s），超时 push_error 并继续
- [x] **条件编译缓存**：`_eval_condition` 按条件字符串 hash 缓存编译结果
- [x] **ReadTracker 自动持久化**：`mark_read()` 加 debounce（2s），自动写磁盘
- [x] **PreloadSystem 取消机制**：加 `cancel_preload(path)` 方法

### 3.4 音频系统增强（Phase 7 ✅）

- [x] **独立音频总线**：创建 BGM/SE/Voice 三个 AudioBus，分别路由
- [x] **BGM 交叉淡入淡出**：fade 改为同时淡出旧 + 淡入新，消除静默间隙
- [x] **SE 池抢占策略**：改为抢占播放时间最长或优先级最低的 SE 播放器

---

## 四、功能补完（场景系统已支持但 UI 未暴露）

### 4.1 设置界面扩展（Phase 6 ✅）

- [x] **对话框透明度滑块**：i18n 键 `config.item.dialogueopacity` 已有，实现 DialogueBoxSystem.modulate 绑定
- [x] **点击停止动画开关**：`config.item.clickstopanimation` — 点击时如果动画还在播放则先完成动画再推进
- [x] **点击停止语音开关**：`config.item.clickstopvoice` — 点击时停止当前语音
- [x] **快进未读开关**：`config.item.fastforwardunread` — 控制 Skip 模式是否跳过未读文本

### 4.2 存档体验（Phase 6 ✅）

- [x] **存档覆盖确认**：使用 i18n 键 `bookmark.overwrite.confirm`
- [x] **读档确认**：使用 i18n 键 `bookmark.load.confirm`
- [x] **存档删除功能**：使用 i18n 键 `bookmark.delete.confirm`

### 4.3 分支与选项（Phase 8 ✅）

- [x] **分支图片**：ChoiceListController 渲染选项的 `image` 字段为缩略图
- [x] **条件分支验证**：在 `test_all.txt` 中补充条件分支测试用例
- [x] **回顾跳转**：点击回顾条目跳回对应位置（使用 `log.moveback.confirm`）

### 4.4 画廊与解锁（Phase 9 ✅）

- [x] **CG 动态解锁**：基于 ReadTracker 或自定义事件触发解锁
- [x] **音乐动态解锁**：播放过一次的 BGM 自动解锁

---

## 五、UI/UX 改进

- [ ] **重新设计对话框和按钮元素UI**：按钮改为无边框，字体底色带渐变背景。对话框也是需要符合现代galgame的渐变色框。主题颜色采用亮色系，淡粉色白色淡蓝色等色系。（对话框 StyleBoxFlat 覆盖 + 亮色主题已实现 `5ab07da`，精修需美术资源）

- [x] **标题界面 ContentArea**：右侧放置 Logo 图片（SVG 生成 `5ab07da`，替换为正式美术资源可后续更新）
- [x] **ChoiceList 最大尺寸**：约束最大高度，超出时 ScrollContainer（Phase 10 ✅）
- [x] **Toast 视口自适应**：位置从绝对像素改为视口百分比（Phase 10 ✅）
- [x] **主主题补全**：ScrollContainer/GridContainer 样式、CJK 字体集成（`5ab07da`）
- [x] **ContinueIcon**：从 Unicode "▼" 改为 TextureRect + 代码生成三角纹理（`5ab07da`）
- [x] **鼠标菜单补充**：添加快速存档 / 快速读档条目（Phase 10 ✅）
- [x] **右键菜单设置快捷键**：F1 设置快捷键连接到 `settings_requested`（Phase 1 ✅）

---

## 六、清理（Phase 3 ✅）

- [x] 删除 `scripts/ui/chapter_select_view_controller.gd.uid`（孤立文件）
- [x] 删除 `scene/ui/dialogue_entry.tscn`（未引用场景）
- [x] 删除 NovaController 中 `REVIEW_REGRESSION_FILES` / `REVIEW_SANITY_FILES` 常量（对应文件不存在）
- [x] 清理 `debug_unlock` (KEY_U) 输入动作或实现其功能
- [x] 清理 `game_state.node_changed` / `game_state.game_started` 未消费信号（连接消费者或删除）

---

## 七、实施顺序（全部完成）

1. ~~**P0 Bug 修复**（5 项，功能阻断级）~~ ✅ Phase 1 — `b367a4a`
2. ~~**P1 数据正确性修复**（4 项）~~ ✅ Phase 2 — `9558c32`
3. ~~**清理孤立文件和死代码**（5 项）~~ ✅ Phase 3 — `aa318c9`
4. ~~**存档恢复覆盖补全**（4 项）~~ ✅ Phase 4 — `79186ba`
5. ~~**P2 代码质量改进**（8 项）~~ ✅ Phase 5 — `cc1b754`
6. ~~**设置界面扩展 + 存档体验**（7 项）~~ ✅ Phase 6 — `c37fa10`
7. ~~**音频系统增强**（3 项）~~ ✅ Phase 7 — `637492e`
8. ~~**分支图片 + 条件分支验证**（3 项）~~ ✅ Phase 8 — `72b1349`
9. ~~**画廊动态解锁**（2 项）~~ ✅ Phase 9 — `e0ebbd8`
10. ~~**UI/UX 改进**（7 项）~~ ✅ Phase 10 — `5b74b61`
11. ~~**图完整性**（3 项）~~ ✅ Phase 11 — `81b5660`
12. ~~**运行时安全性**（4 项）~~ ✅ Phase 12 — `2329b17`

### 剩余未完成

- **五、对话框/按钮 UI 精修**（1 项）：需要正式美术资源替换程序化生成的 StyleBoxFlat

---

## 八、架构审阅重构计划（基于 CODE_REVIEW.md）

> 基于 2026-06-23 的全面代码审阅，分 9 个阶段逐步实施。
> 每阶段独立提交并经 Godot MCP 编译验证（rescan→wait→clear→run_scene→wait→get_errors→stop_scene）。
> 进度记录在 review.md 的"九、架构审阅重构记录"章节。

### Phase R1: 死代码清理与 Bug 修复
- [ ] 删除 NovaController._register_objects() 空方法及调用
- [ ] 删除 hot_reload.gd 中 _refresh_chapters() 死代码调用
- [ ] 删除 prefab_loader.gd 中 get_game_vc() 死代码 fallback
- [ ] 修复 gd_runtime.gd run_block_async() 超时处理（移除死分支，重置 _running_async，停止 timer）
- [ ] 连接 Variables.changed 信号到 _cond_cache 清空
- [ ] 添加存档版本号校验
- **Commit**: `fix: remove dead code, fix GDRuntime timeout, add cond_cache invalidation and save version check`

### Phase R2: 全局 Theme 资源
- [ ] 创建 resources/themes/default_theme.tres（暗色 GALGAME 风格）
- [ ] 应用到 game.tscn 根节点
- **Commit**: `feat: add global dark GALGAME theme resource`

### Phase R3: 存档槽位行场景提取
- [ ] 创建 scene/ui/slot_row.tscn
- [ ] 统一 _open_save_panel 和 _refresh_save_slots 逻辑
- **Commit**: `refactor: extract save slot row to scene, eliminate duplication`

### Phase R4: 动态 UI 迁移到场景文件
- [ ] 创建 context_menu.tscn, toast.tscn, cg_preview_overlay.tscn
- [ ] 迁移对应控制器代码
- **Commit**: `refactor: migrate dynamic UI (context menu, toast, CG preview) to scene files`

### Phase R5: 菜单视图场景继承
- [ ] 创建 base_menu_view.tscn
- [ ] 5 个菜单视图继承重构
- **Commit**: `refactor: use scene inheritance for menu views, eliminate sidebar duplication`

### Phase R6: @export 可配置参数
- [ ] NovaController, SaveSystem, GameViewController, AudioSystem 等添加 @export
- **Commit**: `feat: add @export parameters for designer-configurable values`

### Phase R7: GameState 模型层解耦
- [ ] snapshot/restore 编排移至 NovaController
- [ ] GameState 只管自身状态
- **Commit**: `refactor: decouple GameState from presentation layer, move snapshot/restore orchestration to NovaController`

### Phase R8: GameViewController 拆分
- [ ] 提取 SaveLoadPanelController, BacklogPanelController, ContextMenuController
- **Commit**: `refactor: split GameViewController into SaveLoadPanel, BacklogPanel, and ContextMenu controllers`

### Phase R9: 代码质量提升
- [ ] class_name NovaController, 类型化数组, @onready 统一, PreloadSystem LRU, 解析器修复
- **Commit**: `refactor: code quality improvements (class_name, typed arrays, @onready, LRU, parser fix)`
