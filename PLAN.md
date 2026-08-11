# Uni-Story 成熟化开发计划

> 当前目标：使用 Godot 4.6 + GDScript，学习 Nova 的架构设计，逐步建设成熟、可维护、可扩展的视觉小说游戏引擎。  
> 参考工程：`Nova/` Unity + C# + Lua(ToLua#)  
> 当前工程：Godot + GDScript-first，不引入 Unity/C# 依赖，不把 Lua VM 作为默认运行时。  
> 日期：2026-06-24 · 最后更新：2026-08-11（Phase 0-18 全部完成，精简已完成清单，v1.0.0-rc1）

---

## 一、项目定位

Uni-Story 的目标不是简单复刻 Nova 的 Unity 实现，而是在 Godot/GDScript 生态中吸收 Nova 的成熟架构：

- 学习 Nova 的流程图、检查点存档、回跳、章节解锁、资源预加载、动画分组、UI 视图管理和工具链设计。
- 保持 Godot 原生开发体验：GDScript、`.tscn` 场景、`Resource`、`ConfigFile`、`ResourceLoader`、Godot export pipeline。
- 建立可做真实作品的视觉小说引擎，而不是只跑 demo 的运行时原型。

架构方向：

| 层级 | 目标职责 | Godot 实现方向 |
|------|----------|----------------|
| 组合根 | 统一装配子系统、场景、配置 | `NovaController.gd` 作为 Composition Root |
| 脚本前端 | 解析 NovaScript 风格剧本 | 保持 GDScript runtime，补 NovaScript 兼容语义 |
| 流程核心 | 节点、分支、章节、结局、回跳 | `FlowChartGraph` + `GameState` + `CheckpointManager` |
| 表现运行时 | 图像、立绘、动画、音频、镜头、VFX、视频、Prefab | Runtime 子系统，可存档、可暂停、可恢复 |
| UI 产品层 | 标题、章节、游戏、设置、存读档、回顾、鉴赏、帮助、通知、输入映射 | `.tscn` 场景 + 控制器 |
| 工具链 | 剧本 lint、静态 IR、对白统计、分支可视化、资源扫描、立绘工具、shader 生成、协作编剧工具 | Godot/Python 工具并行 |

---

## 二、当前基线

已具备一套可运行的 GDScript 视觉小说框架，Phase 0-10 均已达到「核心完成」基线：

- NovaScript eager/lazy/text 块解析 + GDScript 动态编译。
- 流程图、分支、跳转、条件分支、命名结局、局部 label。
- 变量系统（`v_` / `gv_` 兼容）、I18n、ReadTracker、Backlog（语音路径记录）。
- 图像显示/隐藏/移动/染色、StandingProfile 驱动立绘合成、头像切换。
- 动画系统：4 种动画域、pause/resume/stop 按域控制、命名 holding 组、12 种 easing 类型。
- 音频系统：BGM 交叉淡入淡出、SE 池化、Voice 播放、独立音量总线。
- AutoVoiceProfile/AutoVoiceSystem：按 canonical speaker 将 `显示名//内部名` 对话映射到角色语音目录，生成 6 位编号，支持一次性 delay、显式 `say()` 覆盖、Auto 等待、Backlog 语音路径以及 checkpoint/save 恢复。
- 镜头移动/缩放/旋转、转场（fade/flash/dissolve/wipe）、屏幕震动。
- VFX：OBJECT/POST/TRANSITION effect registry（40/37/6）、effect-list 状态记录、`clear_effect()`、快照恢复、SubViewport 多 pass 合成、`capture_screen()` 与 `transition_with_capture()` 转场纹理消费。84 个 `.gdshader` + 49 个 shaderproto 模板。
- Prefab 加载按 WORLD/UI/PERSISTENT 分类管理生命周期，另有视频播放与 Timeline 编排。
- PreloadSystem 支持优先级、分类型 LRU、取消、引用计数和进度查询。
- ThemeManager 已完成 base/work 两层核心主题架构；debug theme 已实现。
- Checkpoint/Bookmark 双层存档模型、缩略图截图、reached dialogue/end 追踪。
- 标题菜单（9 入口）、章节选择、Help、设置、CG/音乐鉴赏、存读档。
- 输入映射（按键录制 + 冲突检测）、Toast 通知、Confirm 确认框。
- InterruptManager（小游戏中断/恢复协议）+ ExampleMinigame（文字输入 + 变量回传 + teardown 协议）+ `minigame()` 函数。
- 移动端横屏自适应、触控操作。
- Scenario lint 已提供公共入口 `python scripts/tools/scenario_lint.py`，覆盖结构/属性、编译、流程图、资源、canonical speaker 与常见内容/兼容陷阱；默认 28 个主剧本为 `errors=0`、`warnings=133`、`referenced=372`、`found=370`、`virtual=2`、`missing=0`。
- Scenario stat 已提供公共入口 `python scripts/tools/scenario_stat.py`，复用不执行 eager code 的 `scenario_analysis.gd` 共享 IR；默认基线为 360 blocks（106 eager/254 lazy）、53 nodes、731 dialogues、15434 characters、23 jumps、24 branch options、1 silent entry。
- Scenario visualize 已提供 text/JSON/DOT/Mermaid 输出，消费共享 IR，21 项 smoke test 覆盖。
- 资源列表工具 `list_resources.py` 支持 12 种类别输出。
- shaderproto 生成器 `shaderproto_gen.py` 支持 JSON 模板生成 .gdshader 变体。
- 32 个 headless 测试通过（约 55 秒，CI Linux 实测约 93 秒），由 `scripts/tests/run_headless_suite.py` 聚合执行。
- CI（`ci.yml`）：push/PR 仅运行 Scenario lint（warning 默认不阻断）+ headless quality gate；Windows/Linux/Android 三端导出由 `workflow_dispatch` 手动触发，并依赖 quality job。Release（`release.yml`）：打 tag 或手动触发时跑同一门禁后导出三端并发布。
- Godot export presets + GitHub Actions 发布基础。
- 性能基线 headless 测试覆盖解析/场景加载/存档/恢复/回跳耗时。
- 导出产物启动 smoke test（`export_smoke_test.gd`：子系统初始化 + ch1 推进 + 存读档 + 视图导航 + ch4 播放）。

主要短板（Phase 10 基线快照，Phase 11-18 已逐步解决；当前状态见"六、当前状态"）：

- **工具链完整性**（差距 81%）：Nova 有 27 个 Python 工具围绕「协作编剧工作流」设计——合并/拆分/剥离代码/可视化分支；Uni-Story 当前有 7 个工具侧重工程质量，但缺少 merge、split_chara、strip_code 家族、add_soft_hyphens、generate_sample_script 等面向内容创作者的工具。
- **立绘生产管线**：Nova 有 PSD 导出/图层合并/姿态排序 4 个工具；Uni-Story 仅有导入约定文档，无自动化工具。
- **Editor 集成**（差距 97%）：Nova 有 31 个 Editor 脚本（立绘编辑器、SaveViewer、Build Hooks、ImageGroup 编辑器等）；Uni-Story 仅 1 个 editor 脚本。
- **I18n 内容**：Nova 有 4 个英文已译剧本；Uni-Story 仅框架就绪，无英文剧本翻译。
- **Shader/VFX 丰富度**：Nova 37 shaderproto 生成 176 shader；Uni-Story 仅 12 个 shader。
- **示例作品**：Nova 有 10+ 商业作品验证；Uni-Story 缺少完整叙事示例。
- **Lua VM**：Nova 完整 Lua 运行时；Uni-Story 仅覆盖常用 NovaScript 语义，部分 API 仍为 no-op 兼容桩。

---

## 三、核心原则

1. **GDScript-first**：脚本块编译为 GDScript；兼容 NovaScript 时优先做语义映射和转换层。
2. **存档能力优先于表现堆叠**：成熟 VN 引擎的核心是可回跳、可恢复、可升级。
3. **场景与控制器分离**：UI 结构进 `.tscn`，逻辑进 `scripts/ui/*`。
4. **可验证推进**：每个阶段必须有验收剧本或 headless 测试。
5. **兼容与原生平衡**：Nova 作为设计目标，Godot 作为实现约束。
6. **文档同步**：完成阶段后更新 `PLAN.md` 状态，偏差和风险写入 `review.md`。
7. **工具链面向内容创作者**：工具设计以编剧/美术的实际工作流为第一优先级，不只为工程验证服务。

---

## 四、阶段路线图

### Phase 0：计划锁定与基线整理 ✅
### Phase 1：架构边界与工程骨架 ✅
### Phase 2：NovaScript 兼容基线 ✅
### Phase 3：Checkpoint / Bookmark 存档核心 ✅
### Phase 4：章节选择、全局进度与标题体验 ✅
### Phase 5：ViewManager 与 UI 产品层成熟化 ✅
### Phase 6：动画系统升级 ✅
### Phase 7：VFX / Shader / Transition 系统 ✅
### Phase 8：资源加载、预加载与内容生产工具 ✅
### Phase 9：小游戏、中断与扩展接口 ✅
### Phase 10：平台、质量与发布 ✅

---

### Phase 11：协作编剧工具链 ✅ 已完成

> 目标：补齐 Nova 的协作编剧工作流工具（merge/split/strip），使内容创作者可以合并/拆分/剥离剧本代码。  
> 差距：81% → 100%（8 个工具全部实现并各有 smoke test）。

- ✅ 8 个工具全部完成：`merge.py`、`split_chara.py`、`strip_code.py` 及其 docx/tex/xlsx 变体、`add_soft_hyphens.py`、`generate_sample_script.py`；新增 `merge_tool_smoke_test.gd`、`strip_code_smoke_test.gd`。
- ✅ 验收：lint `errors=0`，24 项测试通过；merge → split → strip 端到端工作流可跑通。

---

### Phase 12：立绘生产管线与 Editor 集成 ✅ 已完成

> 目标：建立 PSD → 图层 PNG → 合并 → 运行时合成的自动化立绘管线，并补齐 Godot Editor 集成。  
> 差距：立绘工具 0% → 100%（4/4）；Editor 集成 3% → 23%（1/31 → 7/31）。

- ✅ 4 个立绘工具：`standing/export_psd_layers.py`、`merge_psd_layers.py`、`export_poses.py`、`sort_poses.py`；`phase12_standing_tools_smoke_test.py` 34/34 PASS。
- ✅ `addons/standing_editor/` EditorPlugin（Inspector 编辑 + 实时预览）、`scripts/editor/save_viewer.gd` + `resource_dashboard.gd`。
- ✅ 验收：lint `errors=0`；SaveViewer 可解析 ≥3 个存档文件；仪表盘与资源扫描一致。

---

### Phase 13：示例作品与 I18n 内容 ✅ 已完成

> 目标：构建完整叙事示例作品并完成英文翻译。  
> 差距：叙事验证 0% / I18n 内容 0% → 均 ~90%。

- ✅ ch3 双分支 + ch4 三结局（true_end_good/true_end_dark/bad_end）、8 个新 Pose、AutoVoice 语音。
- ✅ 英文翻译 ch1-ch4（含分支与多结局）+ `i18n_switch_smoke_test.gd`；3 个小游戏模板（Click/Drag/QTE）+ `minigame_templates_smoke_test.gd`。
- ✅ 新增 `sample_work_playback_smoke_test.gd`、`sample_work_save_load_test.gd`。

---

### Phase 14：Shader/VFX 丰富度提升 ✅ 已完成

> 目标：扩充 shader 资产库。  
> 差距：12% → 57%（14 → 50 个 .gdshader）。

- ✅ 8 个新基础效果（pixelate/mosaic/kaleidoscope/swirl/radial_blur/zoom_blur/edge_detect/invert）+ POST 版本；OBJECT_EFFECTS 5→13，POST_EFFECTS 5→13。
- ✅ `query_uniforms()`、别名映射扩展、`shader_effects_smoke_test.gd`。

---

### Phase 15：NovaScript API 深化与 Lua 兼容收尾 ✅ 已完成（部分项待真机）

> 目标：解决剩余 no-op 兼容桩，建立设备验证基础设施。  
> 状态：✅ 代码部分完成（Lua 兼容 78% → 96%，no-op 桩 22 → 1）；设备真机验证待执行。

- ✅ 21 个 API 从 no-op 升级为完整实现（box_*、new_page、stop_auto_ff/stop_ff、immediate_step、input_on/off、ff_shortcut、auto_fade、auto_time、text_*、volume、anim_hold、get_current_position、input 等），白名单 22 → 1。
- ✅ `nova_lua_compat_smoke_test.gd`（20+ 项）、ScriptLoader 编译缓存预热、`docs/DeviceTestChecklist.md`。
- 🔲 真机验证：Windows/Linux/Android 设备测试清单已编写，未执行（见 `docs/DeviceTestChecklist.md`）。
- 🔲 性能优化后续项：场景加载减负、增量 snapshot、性能基线 20% 目标（待真机/CI 迭代）。

---

### Phase 16：Shader/VFX 全量对齐 Nova ✅ 已完成

> 目标：shaderproto 9 → 49（超 Nova 37），84 个 .gdshader。  
> 差距：Shader 丰富度 24% → **87%**。

- ✅ 40 个新 shaderproto（3 批）+ 7 个已有 shader 补模板；OBJECT_EFFECTS 13→40，POST_EFFECTS 13→37，TRANSITION_EFFECTS 2→6，别名 14→60+。
- ✅ 每个新效果均有对象版 + POST 全屏版；`shader_effects_smoke_test.gd` 覆盖全部 registry/编译/别名。

---

### Phase 17：Editor 集成与 UI 工具深度提升 ✅ 已完成

> 目标：补全 Godot Editor 集成。  
> 差距：Editor 集成 23% → **55%**（8 → 17 脚本）。

- ✅ 5 个新 Resource 类型（ImageEntry/ImageGroup/ImageGroupList/MusicEntry/MusicEntryList）+ ImageGroup/MusicGallery Inspector 与列表面板。
- ✅ BuildPanel + BuildHooks、StandingEditor 增强（双角色预览/图层重排/Pose 轮播）、`UniStoryEditorPlugin`（NovaMenu）、`editor_tools_smoke_test.gd`（60+ 项）。

---

### Phase 18：工具链补完、文档与发布成熟化 ✅ 已完成（导出产物 CI 已验证）

> 目标：补齐 Nova 剩余 Python 工具，完善用户文档与发布指南，v1.0.0-rc1。  
> 差距：工具链 67% → **93%+**（25/27 工具）。

- ✅ 9 个新工具（generate_charsets、generate_localized_paths、generate_shaders、list_bg、list_bgm、list_pos、show_branches、nova_script_parser、utils）；工具链 18/27 → 25/27。
- ✅ README 重写为用户手册、`docs/ReleaseGuide.md`、VS Code NovaScript 扩展（语法高亮 + 12 snippets）、CHANGELOG 用户版。
- ✅ 三平台导出产物 CI 验证（2026-08-11：Windows/Linux/Android 均成功）。
- 🔲 三平台真机验证（Windows/Linux/Android 真机可用性 — 需设备执行）；性能基线 CI 确认已通过（32/32）。

---

## 五、阶段状态表

| Phase | 名称 | 状态 |
|-------|------|------|
| 0 | 计划锁定与基线整理 | ✅ 完成 |
| 1 | 架构边界与工程骨架 | ✅ 完成 |
| 2 | NovaScript 兼容基线 | ✅ 完成 |
| 3 | Checkpoint / Bookmark 存档核心 | ✅ 完成 |
| 4 | 章节选择、全局进度与标题体验 | ✅ 完成 |
| 5 | ViewManager 与 UI 产品层成熟化 | ✅ 完成 |
| 6 | 动画系统升级 | ✅ 完成 |
| 7 | VFX / Shader / Transition 系统 | ✅ 完成 |
| 8 | 资源加载、预加载与内容生产工具 | ✅ 完成 |
| 9 | 小游戏、中断与扩展接口 | ✅ 完成 |
| 10 | 平台、质量与发布 | ✅ 完成 |
| **11** | **协作编剧工具链** | ✅ 完成 |
| **12** | **立绘生产管线与 Editor 集成** | ✅ 完成 |
| **13** | **示例作品与 I18n 内容** | ✅ 完成 |
| **14** | **Shader/VFX 丰富度提升** | ✅ 完成 |
| **15** | **NovaScript API 深化与 Lua 兼容收尾** | ✅ 完成 |
| **16** | **Shader/VFX 全量对齐 Nova** | ✅ 完成 |
| **17** | **Editor 集成与 UI 工具深度提升** | ✅ 完成 |
| **18** | **工具链补完、文档与发布成熟化** | ✅ 完成 |

---

## 六、当前状态

**全部 Phase 0-18 已完成 ✅！** 项目达到 v1.0.0-rc1 里程碑。

**当前相对于 Nova（37 shaderprotos, 27 tools, 31 editor scripts）的实际差距**：

```
工具链完整性  ██████████████████████░  93%  (25/27 工具已覆盖，仅差 2 个 — nova_script_parser.py 参考版 + 1 个 Nova 专用)
立绘生产管线  ██████████████████████  100%  (4/4 工具)
Editor 集成   █████████████████░░░░░  55%  (17/31 脚本，新增 9 个 Editor 脚本 + 5 个 Resource)
I18n 内容     ████████████████████░░  90%  (EN ch1-ch4 全翻译，含多结局分支)
Shader 丰富度 ████████████████████░░  87%  (84 gdshader / 49 shaderproto，超过 Nova 37 基准)
示例作品      ████████████████████░░  90%  (ch1-ch4 完整叙事 + 3 结局 + 3 小游戏模板)
Lua 兼容      ██████████████████████  96%  (仅 avatar_show 仍为 no-op，其余全部实现)
文档完整度    ██████████████████████  95%  (PLAN/Review/ReleaseGuide/DeviceTest + VS Code 扩展)
```

**Phase 18 关键交付**：
- 9 个新 Python 工具（generate_charsets、generate_localized_paths、generate_shaders、list_bg、list_bgm、list_pos、show_branches、nova_script_parser、utils）
- docs/ReleaseGuide.md — 三平台发布完整指南
- VS Code NovaScript 扩展（语法高亮 + 12 snippets + language config）
- README 更新为完整用户手册

**剩余待办（需真机/CI 环境）**：
- 🔲 三平台真机验证（Windows/Linux/Android 设备测试清单已编写，见 `docs/DeviceTestChecklist.md`；导出产物已由 CI 构建验证）
- 🔲 性能优化后续迭代（场景加载减负、增量 snapshot、性能基线 20% 目标）
- ✅ 三平台导出产物 CI 构建（2026-08-11：Windows/Linux/Android 全部成功）

**下一步**：项目已标记 v1.0.0-rc1，建议执行三平台真机测试后发布正式版 v1.0.0。

---

## 七、文档索引

| 文档 | 用途 |
|------|------|
| `PLAN.md` | 路线、任务、状态、验收标准 |
| `review.md` | Nova 对比、阶段审查、风险记录 |
| `docs/NovaScript.md` | 脚本语法、兼容表、API 参考 |
| `docs/ProjectTerms.md` | 术语表 |
| `docs/StandingImportGuide.md` | 立绘导入约定、目录结构、图层命名、Pose 配置 |
| `docs/CodingStandards.md` | 编码规范 |
| `docs/DeviceTestChecklist.md` | Phase 15 — 三平台设备测试清单 |
| `docs/ReleaseGuide.md` | 发布流程、导出配置、平台注意事项 |
| `README.md` | 用户视角快速开始和能力摘要 |
| `Setup.md` | 环境搭建与架构概览 |
| `CHANGELOG.md` | 面向用户的版本发布日志（Phase 历史归档） |
