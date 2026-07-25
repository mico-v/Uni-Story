# Uni-Story Phase 拆分清单

本文把 `PLAN.md` 中的各阶段拆成 issue/commit 粒度，作为开发时的提交边界参考。单个提交应能运行主场景或对应 headless test。

> 最后同步：2026-07-25

状态标记：✅ 已完成 / 🔄 核心完成、仍有明确缺口 / 🔲 未完成

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
- ✅ `ui-theme-base-work`：ThemeManager + base/work 两层核心主题架构，结构样式与作品配色/字体可分层覆盖。
- 🔲 `debug-theme-layer`：增加 debug theme 资源、调试模式切换和对应视觉验收。

## Phase 6：动画系统升级

- ✅ `animation-domains`：区分 PER_DIALOGUE、HOLDING、UI、TEXT 动画域。
- ✅ `animation-chain-semantics`：补 then()/and_anim() 语义和等待策略。
- ✅ `animation-pause-restore`：支持 pause/resume/stop 按域控制，并接入 ViewManager。
- ✅ `holding-animation-groups`：支持命名 holding animation group。
- ✅ `easing-parser`：兼容 Nova 常见 easing/slope 写法（12 种缓动类型）。
- ✅ `more-property-types`：新增 PropertyFloat/PropertyVector2/MoveTo/FadeTo/RotateTo/ScaleTo/TintTo。
- ✅ `animation-integration`：Lazy block stage 与动画等待策略已打通（BaseBlock.await block 语义）。

## 跨 Phase 增量：AutoVoice

- ✅ `auto-voice-profile`：新增 AutoVoiceProfile，配置 canonical speaker/别名、大小写敏感的角色目录、6 位补零宽度、扩展名与 prefix。
- ✅ `canonical-speaker-parser`：支持 `显示名//内部名：：台词`，同一 node 内继承 canonical speaker，新 label 重置映射。
- ✅ `auto-voice-runtime`：实现 on/off/off_all、一次性 delay、skip、prefix/index tuple、pending cue 取消和显式 `say()`/`play_voice()` 覆盖。
- ✅ `auto-voice-save-backlog-auto`：enabled/index/prefix/delay/override/current cue 进入 snapshot/restore；Backlog 保存精确路径，Auto 等待 pending delay 与 voice finished。
- ✅ `auto-voice-tests`：新增 `auto_voice_system_smoke_test.gd`，并扩展 canonical speaker、ch1 playback、checkpoint/save 与资源扫描覆盖。

## Phase 7：VFX / Shader / Transition 系统

- ✅ `shader-registry`：OBJECT_EFFECTS / POST_EFFECTS / TRANSITION_EFFECTS 注册表均已完成，替代 ad-hoc `match` 分支选择 shader。
- ✅ `vfx-domains`：支持对象 VFX、后处理 VFX、转场 VFX 三类。
- ✅ `vfx-parameter-animation`：支持 float/color 参数动画（已有）。
- ✅ `vfx-effect-state`：完成 effect-list bookkeeping、`clear_effect()` 和 snapshot/restore。
- ✅ `shader-layer-stack`：实现真正多 pass compositing（SubViewport 链式合成）。
- ✅ `screen-capture-api`：提供 `capture_screen()` API。
- ✅ `screen-capture-transition`：captured texture 实际传入 dissolve/wipe shader transition。
- ✅ `nova-vfx-subset`：已有 fade、wipe、blur、grayscale、dissolve、glitch、ripple、shake、chromatic、vignette。
- ✅ `shaderproto-generator`：`scripts/tools/shaderproto_gen.py` 支持 JSON 模板，生成 .gdshader 变体。

## Phase 8：资源加载、预加载与内容生产工具

- ✅ `scenario-resource-scan`：`scenario_resource_scan_test.gd` 严格扫描 show/standing/audio/prefab/video、`say(speaker, id)` 与 shader 参数引用，解析无扩展名资源、CG alias 和虚拟 RenderTarget；当前 `referenced=369`、`found=367`、`virtual=2`、`missing=0`。
- ✅ `preload-priority-lru`：PreloadSystem 支持优先级、分类型 LRU、取消、引用计数和进度。
- ✅ `missing-resource-report`：输出缺失资源报告（scenario_resource_scan_test 已覆盖）。
- ✅ `scenario-lint`：新增 `scripts/tools/scenario_lint.py` 公共入口与 Godot 检查实现，支持 text/JSON、输出文件、失败阈值和文件/目录参数；覆盖结构/属性/编译、流程图、资源、canonical speaker 及内容/兼容 warning。默认 28 个剧本为 `errors=0`、`warnings=133`、`referenced=372`、`found=370`、`virtual=2`、`missing=0`。
- ✅ `scenario-lint-smoke`：新增 `scenario_linter_smoke_test.gd`，覆盖有效/损坏 fixture、rule ID、路径/行号、排序、JSON、编译错误子进程与 0/1/2 退出码。
- ✅ `scenario-analysis-ir`：新增不执行 eager code 的共享静态 IR，稳定输出 blocks/nodes/entries/silent entries/edges/events，供统计与后续 visualize 复用。
- ✅ `scenario-stat`：新增 Python/Godot CLI、text/JSON、`--top`、按文件/节点/canonical speaker 与长度分布统计；默认 28 个剧本为 360 blocks、53 nodes、731 dialogues、15434 characters、23 jumps、24 branch options。
- ✅ `scenario-stat-smoke`：覆盖源码坐标、canonical speaker、rich/TODO/空格规范化、silent lazy、flow 作用域、默认基线、Godot/Python CLI 与 0/2 退出码。
- ✅ `scenario-visualize`：迁移 show_branches/visualize，直接消费共享 IR，text/JSON/DOT/Mermaid 输出。
- ✅ `scenario-asset-list`：`scripts/tools/list_resources.py` 支持 bg/bgm/se/cg/character 等 12 种类别，text/JSON/CSV 输出。
- ✅ `standing-import-convention`：`docs/StandingImportGuide.md` 定义目录结构、图层命名、Pose 配置与 Nova 迁移指南。

## Phase 9：小游戏、中断与扩展接口

- ✅ `interrupt-fence-core`：实现 InterruptManager（begin/end_interrupt 协议）。
- ✅ `gameplay-prefab-manager`：PrefabLoader 按 WORLD/UI/PERSISTENT 分类管理生命周期并保留分类快照。
- ✅ `interrupt-input-policy`：中断期间暂停 auto/skip/点击推进。
- ✅ `minigame-checkpoint-policy`：小游戏结束后自动创建 checkpoint。
- ✅ `extension-api-provider`：InterruptManager 注册为 restorable；BaseBlock 暴露中断 API（begin_interrupt/end_interrupt/is_interrupt_active）。
- ✅ `minigame-example`：新增 ExampleMinigame 场景（文字输入 + 变量回传 + teardown 协议）+ `minigame_smoke_test.gd` + `minigame()` 函数实现。

## Phase 10：平台、质量与发布

- ✅ `headless-regression-suite`：20 个 `*_test.gd` 纳入自动发现，当前 20/20 PASS（约 55 秒），覆盖 parser、flow graph、Scenario lint/stat、共享静态 IR、AutoVoice、save/restore、checkpoint replay、资源扫描、主题、预加载、Prefab 与 VFX 等路径。
- ✅ `headless-suite-runner`：新增 `scripts/tests/run_headless_suite.py`，逐个隔离执行 Godot 测试，汇总退出码、超时和脚本错误。
- ✅ `ci-release-quality-gate`：CI 与 Release workflow 均先以 `--fail-on error` 运行 Scenario lint，再运行 headless suite；warning 默认不阻断，Windows/Linux/Android 导出 job 依赖 quality job。
- ✅ `scene-navigation-smoke`：MainSceneSmokeTest 覆盖主场景加载、所有视图注册和子系统初始化。
- ✅ `export-smoke`：`export_smoke_test.gd`：子系统初始化 + ch1 推进 + 存读档 + 视图导航 + ch4 播放。
- ✅ `performance-baseline`：`performance_baseline_test.gd` 测量解析/场景加载/存档/恢复/回跳 5 项耗时并设定上限。
- ✅ `error-recovery`：损坏存档、缺资源、脚本语法错误均已有日志分级。
- ✅ `release-docs`：`PLAN.md`、`README.md`、`Setup.md`、`review.md`、`CLAUDE.md` 与 API/backlog 文档已同步至 2026-07-25 当前事实。

（`sample-work-perfection` 提升至 Phase 13 作为独立阶段推进。）

## Phase 11：协作编剧工具链

- 🔲 `merge-tool`：新增 `scripts/tools/merge.py`，将分角色剧本文件合并为 NovaScript 剧本；支持 `#角色名` 标签归并、`--input-dir`/`--output` 参数。
- 🔲 `split-chara-tool`：新增 `scripts/tools/split_chara.py`，按角色拆分剧本为独立文件，保留原始行号和上下文。
- 🔲 `strip-code-tools`：新增 `strip_code.py`/`strip_code_docx.py`/`strip_code_tex.py`/`strip_code_xlsx.py`，剥离 `<|...|>` 代码块输出纯文本/DOCX/TEX/XLSX。
- 🔲 `soft-hyphens-tool`：新增 `scripts/tools/add_soft_hyphens.py`，在日/中文文本中插入软连字符。
- 🔲 `sample-script-gen`：新增 `scripts/tools/generate_sample_script.py`，从模板生成示例剧本（basic/branching/minigame）。
- 🔲 `merge-tool-tests`：新增 `merge_tool_smoke_test.gd`，验证合并输出可被 ScriptLoader 正确解析。
- 🔲 `strip-tool-tests`：新增 `strip_code_smoke_test.gd`，对 ch1.txt 执行四种剥离验证内容完整。
- 🔲 `phase11-docs`：更新 `PLAN.md`、`review.md`、`PhaseBacklog.md`。

## Phase 12：立绘生产管线与 Editor 集成

- 🔲 `psd-export`：新增 `scripts/tools/standing/export_psd_layers.py`，从 PSD 导出图层为独立 PNG，按 `StandingImportGuide.md` 约定命名。
- 🔲 `psd-merge`：新增 `scripts/tools/standing/merge_psd_layers.py`，按 Pose 配置合并图层，输出与 SpriteComposer 一致的结果。
- 🔲 `pose-export-sort`：新增 `scripts/tools/standing/export_poses.py` 和 `sort_poses.py`。
- 🔲 `standing-editor-plugin`：创建 `addons/standing_editor/` Godot EditorPlugin，Inspector 可视化编辑 offset/scale + 实时预览。
- 🔲 `save-viewer`：新增 `scripts/editor/save_viewer.gd`，Editor 中查看存档 JSON，显示 bookmark 元数据和 checkpoint 状态。
- 🔲 `resource-dashboard`：新增 `scripts/editor/resource_dashboard.gd`，Editor 面板聚合资源扫描结果，缺失项可跳转。
- 🔲 `standing-tool-tests`：新增 `standing_tool_smoke_test.gd`，覆盖 PSD 导出、合并、Pose 排序全链路。
- 🔲 `save-viewer-test`：新增 `save_viewer_smoke_test.gd`，验证解析至少 3 个存档文件。
- 🔲 `phase12-docs`：更新 `PLAN.md`、`review.md`、`PhaseBacklog.md`。

## Phase 13：示例作品与 I18n 内容

- 🔲 `sample-work-script`：编写 ch1-ch3 完整叙事剧本（含分支、至少 2 个结局），覆盖全部核心功能。
- 🔲 `sample-work-assets`：制作配套立绘素材（3+ 角色，2+ Pose）+ StandingProfile + VisualProfile 配置。
- 🔲 `sample-work-voice`：配置 AutoVoice 语音素材（至少 1 个角色完整语音）。
- 🔲 `sample-work-playback-test`：新增 `sample_work_playback_smoke_test.gd`，完整播放 ch1-ch3 到达所有结局。
- 🔲 `sample-work-save-test`：新增 `sample_work_save_load_test.gd`，存档/读档/回跳全流程。
- 🔲 `english-translation`：翻译 ch1-ch3 为英文版，完善 `en.json` UI 字符串。
- 🔲 `i18n-switch-test`：新增 `i18n_switch_smoke_test.gd`，运行时 zh/en 切换验证。
- 🔲 `minigame-click`：新增 ClickMinigame 模板（点击得分）。
- 🔲 `minigame-drag`：新增 DragMinigame 模板（拖拽到目标）。
- 🔲 `minigame-qte`：新增 QTEMinigame 模板（限时按键）。
- 🔲 `minigame-templates-test`：新增 `minigame_templates_smoke_test.gd`，加载运行三种模板。
- 🔲 `phase13-docs`：更新 `PLAN.md`、`review.md`、`PhaseBacklog.md`。

## Phase 14：Shader/VFX 丰富度提升

- 🔲 `shaderproto-templates`：新增 8 个基础 shader 效果 JSON 模板（pixelate/mosaic/kaleidoscope/swirl/radial_blur/zoom_blur/edge_detect/invert）。
- 🔲 `new-shaders`：新增 8 个 `.gdshader` 文件并注册到 VFX registry。
- 🔲 `shader-gen-verify`：`shaderproto_gen.py --all` 成功生成所有变体。
- 🔲 `vfx-lookup-api`：VFXSystem 支持按 uniform 参数查询效果。
- 🔲 `shader-effects-test`：新增 `shader_effects_smoke_test.gd`，加载验证所有 shader 编译通过。
- 🔲 `phase14-docs`：更新 `PLAN.md`、`review.md`、`PhaseBacklog.md`。

## Phase 15：Lua VM 深度兼容与设备验证

- 🔲 `box-tint-impl`：实现 `box_tint()` 完整语义。
- 🔲 `input-api-impl`：实现 `input()`、输入验证回调等完整 API。
- 🔲 `text-formatting-impl`：实现 `skip_mode_custom`、text formatting hooks 等。
- 🔲 `misc-nova-api`：实现 `set_text_speed()`、`get_current_position()` 等剩余 API。
- 🔲 `nova-lua-compat-test`：新增 `nova_lua_compat_smoke_test.gd`，验证 API 不再为 no-op。
- 🔲 `device-smoke-windows`：Windows 真机启动→播放→存读档→退出验证。
- 🔲 `device-smoke-linux`：Linux 真机同上。
- 🔲 `device-smoke-android`：Android 真机同上 + 横屏触控验证。
- 🔲 `perf-optimize`：基于性能基线优化（场景加载/存档恢复/解析），降低 20%。
- 🔲 `release-docs-v2`：更新 README 为完整用户手册、编写 `docs/ReleaseGuide.md`、整理 CHANGELOG。
- 🔲 `phase15-docs`：更新 `PLAN.md`、`review.md`、`PhaseBacklog.md`。

## 已完成任务归档

- ✅ `debug-theme-layer`：debug theme 与调试模式切换（已实现，2026-07-24）
- ✅ `minigame-example`：示例小游戏（已实现，2026-07-25）
- ✅ `export-smoke`：导出产物启动检查（已实现，2026-07-25）
- ✅ `sample-work-perfection`：示例作品完善（提升至 Phase 13）
