# Uni-Story Phase 拆分清单

本文把 `PLAN.md` 中的各阶段拆成 issue/commit 粒度，作为开发时的提交边界参考。单个提交应能运行主场景或对应 headless test。

状态标记：✅ 核心完成 / 🔲 未完成

## Phase 3：Checkpoint / Bookmark 存档核心

- ✅ `checkpoint-manager-core`：新增 CheckpointManager、node record、reached dialogue/end、checkpoint snapshot 数据结构。
- ✅ `bookmark-save-format`：SaveSystem 写入 bookmark envelope，保留旧 snapshot 存档读取兼容。
- ✅ `save-thumbnail`：GameView 生成 320x180 存档缩略图，写入 `user://saves/thumbnails/` 并存入 bookmark metadata。
- ✅ `checkpoint-restore-position`：从最近 position checkpoint 恢复，并回到目标 entry；补回顾跳转 smoke test。
- ✅ `checkpoint-tests-docs`：补 SaveSystem/GameState/CheckpointManager 测试，并更新 `PLAN.md`、`docs/CodingStandards.md`。

## Phase 4：章节选择、全局进度与标题体验

- ✅ `chapter-select-view`：新增 ChapterSelectView 场景和控制器，按 normal/unlocked/debug start node 展示。
- ✅ `chapter-unlock-progress`：用 reached dialogue 解锁章节，支持单 unlocked start 直接开始。
- ✅ `title-menu-nova-alignment`：标题菜单补章节选择、Help，并与 Nova 的 start/chapter/help 体验对齐。
- ✅ `help-first-hints`：新增 HelpView 和首次进入游戏、首次章节解锁、首次回顾跳转提示。
- ✅ `title-audio-hooks`：标题 BGM 接入 AudioSystem，切入游戏时淡出。
- ✅ `phase4-smoke-tests`：补主场景和章节选择 headless 测试。

## Phase 5：ViewManager 与 UI 产品层成熟化

- ✅ `view-state-machine`：ViewManager 增加 Title/UI/Game/InTransition/Alert 状态。
- ✅ `transition-input-blocker`：过渡中屏蔽重复输入，修复连续点击导致的视图状态错乱。
- ✅ `mobile-landscape-layout`：移动端横屏全屏、viewport expand、GameView 自适应布局和背景/CG cover fit。
- ✅ `standing-composer-offsets`：立绘合成读取项目 `StandingProfile` 资源，避免导出包缺 Unity `.asset` sidecar 时脸部图层错位。
- ✅ `unified-notification-alert`：Toast 使用独立 notification_view.tscn；Confirm 绑定 game_view.tscn ModalLayer 节点。
- ✅ `input-mapping-ui`：按键录制、冲突检测、恢复默认、ConfigFile 持久化。
- ✅ `save-load-rich-list`：存读档显示缩略图、章节名、时间、当前位置。
- ✅ `backlog-product-polish`：回顾支持语音重播、跳转确认、未来文本过滤。
- ✅ `gameview-pause-resume`：切出 GameView 时暂停打字机、语音、动画域，切回时恢复。
- 🔲 `ui-theme-split`：UI 主题资源拆分（默认主题、作品主题、调试主题）。留到后续作品级定制。

## Phase 6：动画系统升级

- ✅ `animation-domains`：区分 PER_DIALOGUE、HOLDING、UI、TEXT 动画域。
- ✅ `animation-chain-semantics`：补 then()/and_anim() 语义和等待策略。
- ✅ `animation-pause-restore`：支持 pause/resume/stop 按域控制，并接入 ViewManager。
- ✅ `holding-animation-groups`：支持命名 holding animation group。
- ✅ `easing-parser`：兼容 Nova 常见 easing/slope 写法（12 种缓动类型）。
- ✅ `more-property-types`：新增 PropertyFloat/PropertyVector2/MoveTo/FadeTo/RotateTo/ScaleTo/TintTo。
- ✅ `animation-integration`：Lazy block stage 与动画等待策略已打通（BaseBlock.await block 语义）。

## Phase 7：VFX / Shader / Transition 系统

- ✅ `shader-registry`：VFXSystem 内建 OBJECT_EFFECTS / POST_EFFECTS / TRANSITION_EFFECTS 注册表。
- ✅ `vfx-domains`：支持对象 VFX、后处理 VFX、转场 VFX 三类。
- ✅ `vfx-parameter-animation`：支持 float/color 参数动画（已有）。
- 🔲 `shader-layer-stack`：Shader layer / material stack 策略。留到后续深度开发。
- 🔲 `screen-capture-transition`：Render target / screen capture 转场。留到后续。
- ✅ `nova-vfx-subset`：已有 fade、wipe、blur、grayscale、dissolve、glitch、ripple、shake、chromatic、vignette。
- 🔲 `shaderproto-generator`：Godot 版 shader 生成器。留到后续。

## Phase 8：资源加载、预加载与内容生产工具

- ✅ `scenario-resource-scan`：新增 `scenario_resource_scan_test.gd`，静态扫描 show/audio/prefab/video 引用并报告缺失。
- 🔲 `preload-priority-lru`：PreloadSystem 支持优先级、取消、LRU 和进度。留到后续。
- ✅ `missing-resource-report`：输出缺失资源报告（scenario_resource_scan_test 已覆盖）。
- 🔲 `scenario-tools-port`：迁移 lint、show_branches、visualize、stat_dialogue_len、list_bg/list_bgm。留到后续。
- 🔲 `standing-import-convention`：设计角色/图层/表情/口型/头像路径规则。留到后续。

## Phase 9：小游戏、中断与扩展接口

- ✅ `interrupt-fence-core`：实现 InterruptManager（begin/end_interrupt 协议）。
- 🔲 `gameplay-prefab-manager`：扩展 PrefabLoader 管理 gameplay prefab。留到后续。
- ✅ `interrupt-input-policy`：中断期间暂停 auto/skip/点击推进。
- ✅ `minigame-checkpoint-policy`：小游戏结束后自动创建 checkpoint。
- ✅ `extension-api-provider`：InterruptManager 注册为 restorable；BaseBlock 暴露中断 API（begin_interrupt/end_interrupt/is_interrupt_active）。
- 🔲 `minigame-example`：增加示例小游戏场景和测试剧本。留到后续。

## Phase 10：平台、质量与发布

- ✅ `headless-regression-suite`：7 个 smoke test + 1 个 resource scan test，覆盖 parser、flow graph、save/restore、checkpoint replay、resource scan。
- ✅ `scene-navigation-smoke`：MainSceneSmokeTest 覆盖主场景加载、所有视图注册和子系统初始化。
- 🔲 `export-smoke`：Windows/Linux/Android 导出产物基础检查。留到后续。
- 🔲 `performance-baseline`：记录解析、预加载、存档、回跳耗时。留到后续。
- ✅ `error-recovery`：损坏存档、缺资源、脚本语法错误均已有日志分级。
- ✅ `release-docs`：README/SETUP/docs 已更新至当前进度。
- 🔲 `sample-work-perfection`：完善示例作品（3 章节、含分支/结局/CG/BGM/回跳/小游戏）。留到后续。

## 后续预留

以下任务标记为留到后续，不阻塞当前引擎就绪状态：

- `ui-theme-split`：UI 主题资源拆分
- `shader-layer-stack`：Shader layer / material stack
- `screen-capture-transition`：Render target 转场
- `shaderproto-generator`：Shader 生成器
- `preload-priority-lru`：PreloadSystem 升级
- `scenario-tools-port`：Nova 工具链迁移
- `standing-import-convention`：立绘导入约定
- `gameplay-prefab-manager`：Gameplay prefab 管理
- `minigame-example`：示例小游戏
- `export-smoke`：导出产物检查
- `performance-baseline`：性能基线
- `sample-work-perfection`：示例作品完善
