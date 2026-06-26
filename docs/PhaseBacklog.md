# Uni-Story Phase 拆分清单

本文把 `PLAN.md` 中的后续阶段拆成 issue/commit 粒度，作为开发时的提交边界参考。单个提交应能运行主场景或对应 headless test。

## Phase 3：Checkpoint / Bookmark 存档核心

- `checkpoint-manager-core`：新增 CheckpointManager、node record、reached dialogue/end、checkpoint snapshot 数据结构。
- `bookmark-save-format`：SaveSystem 写入 bookmark envelope，保留旧 snapshot 存档读取兼容。
- `save-thumbnail`：GameView 生成 320x180 存档缩略图，写入 `user://saves/thumbnails/` 并存入 bookmark metadata。
- `checkpoint-restore-position`：从最近 position checkpoint 恢复，并回到目标 entry；补回顾跳转 smoke test。
- `checkpoint-tests-docs`：补 SaveSystem/GameState/CheckpointManager 测试，并更新 `PLAN.md`、`docs/CodingStandards.md`。

## Phase 4：章节选择、全局进度与标题体验

- `chapter-select-view`：新增 ChapterSelectView 场景和控制器，按 normal/unlocked/debug start node 展示。
- `chapter-unlock-progress`：用 reached dialogue 解锁章节，支持单 unlocked start 直接开始。
- `title-menu-nova-alignment`：标题菜单补章节选择、Help，并与 Nova 的 start/chapter/help 体验对齐。
- `help-first-hints`：新增 HelpView 和首次进入游戏、首次章节解锁、首次回顾跳转提示。
- `title-audio-hooks`：标题 BGM 接入 AudioSystem，切入游戏时淡出，后续提交补 UI/切换音效。
- `phase4-smoke-tests`：补主场景和章节选择 headless 测试。

## Phase 5：ViewManager 与 UI 产品层成熟化

- `view-state-machine`：ViewManager 增加 Title/UI/Game/InTransition/Alert 状态。
- `transition-input-blocker`：过渡中屏蔽重复输入，修复连续点击导致的视图状态错乱。
- `mobile-landscape-layout`：移动端横屏全屏、viewport expand、GameView 自适应布局和背景/CG cover fit。
- `standing-composer-offsets`：立绘合成读取项目 `StandingProfile` 资源，避免导出包缺 Unity `.asset` sidecar 时脸部图层错位。
- `unified-notification-alert`：Toast/Confirm 迁移到 NotificationView/AlertView。
- `input-mapping-ui`：按键录制、冲突提示、恢复默认、ConfigFile 持久化。
- `save-load-rich-list`：存读档显示缩略图、章节名、时间、当前位置，支持更多槽位。
- `backlog-product-polish`：回顾支持语音重播、跳转确认和未来文本过滤。

## Phase 6：动画系统升级

- `animation-domains`：区分 per_dialogue、holding、ui、text 动画域。
- `animation-chain-semantics`：补 then/and 语义和等待策略。
- `animation-pause-restore`：支持 pause/resume/stop，并接入 ViewManager。
- `holding-animation-groups`：支持命名 holding animation group。
- `easing-parser`：兼容 Nova 常见 easing/slope 写法。
- `animation-tests`：覆盖 `test_anim_hold.txt`、读档和菜单切换恢复。

## Phase 7：VFX / Shader / Transition 系统

- `shader-registry`：建立 effect registry，记录 shader path、默认参数和可动画参数。
- `vfx-domains`：区分对象 VFX、后处理 VFX、转场 VFX。
- `vfx-parameter-animation`：支持 float/color/vector/texture 参数动画。
- `screen-capture-transition`：支持 screen capture/render target 转场。
- `nova-vfx-subset`：迁移 fade、wipe、blur、mono、glitch、shake、ripple、rain 等常用效果。

## Phase 8：资源加载、预加载与内容生产工具

- `scenario-resource-scan`：静态扫描 show/audio/prefab/video/timeline/choice image 引用。
- `preload-priority-lru`：PreloadSystem 支持优先级、取消、LRU 和进度。
- `missing-resource-report`：输出缺失资源报告。
- `scenario-tools-port`：迁移 lint、show_branches、visualize、stat_dialogue_len、list_bg/list_bgm。
- `standing-import-convention`：设计角色/图层/表情/口型/头像路径规则。

## Phase 9：小游戏、中断与扩展接口

- `interrupt-fence-core`：实现 interrupt/fence 协议。
- `gameplay-prefab-manager`：扩展 PrefabLoader 管理 gameplay prefab。
- `interrupt-input-policy`：中断期间暂停自动/快进/点击推进。
- `minigame-checkpoint-policy`：小游戏结束后确保 checkpoint。
- `extension-api-provider`：自定义系统可注册 restorable/preloadable/script API provider。

## Phase 10：平台、质量与发布

- `headless-regression-suite`：串联 parser、flow graph、save/restore、checkpoint replay、resource scan。
- `scene-navigation-smoke`：主场景标题导航、开始游戏、存读档、设置、鉴赏 smoke test。
- `export-smoke`：Windows/Linux/Android 导出产物基础检查。
- `performance-baseline`：记录解析、预加载、存档、回跳耗时。
- `release-docs`：整理快速开始、NovaScript 兼容表、资源规范、扩展系统和发布流程。
