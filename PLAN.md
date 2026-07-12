# Uni-Story 成熟化开发计划

> 当前目标：使用 Godot 4.6 + GDScript，学习 Nova 的架构设计，逐步建设成熟、可维护、可扩展的视觉小说游戏引擎。  
> 参考工程：`Nova/` Unity + C# + Lua(ToLua#)  
> 当前工程：Godot + GDScript-first，不引入 Unity/C# 依赖，不把 Lua VM 作为默认运行时。  
> 日期：2026-06-24 · 最后更新：2026-07-10

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
| 工具链 | 剧本 lint、静态 IR、对白统计、分支可视化、资源扫描、立绘工具、shader 生成 | Godot/Python 工具并行 |

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
- VFX：OBJECT/POST effect registry、effect-list 状态记录、`clear_effect()`、快照恢复，以及 blur/grayscale/dissolve/glitch/ripple/chromatic/vignette/wipe 等效果入口；CanvasItem 当前只渲染 effect list 顶部材质。
- Prefab 加载按 WORLD/UI/PERSISTENT 分类管理生命周期，另有视频播放与 Timeline 编排。
- PreloadSystem 支持优先级、分类型 LRU、取消、引用计数和进度查询。
- ThemeManager 已完成 base/work 两层核心主题架构；debug theme 尚未实现。
- Checkpoint/Bookmark 双层存档模型、缩略图截图、reached dialogue/end 追踪。
- 标题菜单（9 入口）、章节选择、Help、设置、CG/音乐鉴赏、存读档。
- 输入映射（按键录制 + 冲突检测）、Toast 通知、Confirm 确认框。
- InterruptManager（小游戏中断/恢复协议）。
- 移动端横屏自适应、触控操作。
- Scenario lint 已提供公共入口 `python scripts/tools/scenario_lint.py`，覆盖结构/属性、编译、流程图、资源、canonical speaker 与常见内容/兼容陷阱；默认 28 个主剧本为 `errors=0`、`warnings=133`、`referenced=372`、`found=370`、`virtual=2`、`missing=0`。
- Scenario stat 已提供公共入口 `python scripts/tools/scenario_stat.py`，复用不执行 eager code 的 `scenario_analysis.gd` 共享 IR；默认基线为 360 blocks（106 eager/254 lazy）、53 nodes、731 dialogues、15434 characters、23 jumps、24 branch options、1 silent entry。
- 20/20 个 headless 测试通过（约 55 秒），由 `scripts/tests/run_headless_suite.py` 聚合执行。
- CI 与 Release workflow 均先执行 Scenario lint（warning 默认不阻断）和 headless quality gate，通过后才允许 Windows/Linux/Android 导出。
- Godot export presets + GitHub Actions 发布基础。

主要短板（留到后续）：

- 完整 Lua VM 兼容，以及仍为兼容桩的少量 Nova API。
- debug theme、Nova 剧本分支展示/流程可视化、资源列表工具、立绘导入工具和 shader 生成器。
- VFX 真正多 pass compositing、TRANSITION registry，以及把 `capture_screen()` 结果接入 shader transition。
- 导出产物启动 smoke test、性能基线、示例作品完善。

---

## 三、核心原则

1. **GDScript-first**：脚本块编译为 GDScript；兼容 NovaScript 时优先做语义映射和转换层。
2. **存档能力优先于表现堆叠**：成熟 VN 引擎的核心是可回跳、可恢复、可升级。
3. **场景与控制器分离**：UI 结构进 `.tscn`，逻辑进 `scripts/ui/*`。
4. **可验证推进**：每个阶段必须有验收剧本或 headless 测试。
5. **兼容与原生平衡**：Nova 作为设计目标，Godot 作为实现约束。
6. **文档同步**：完成阶段后更新 `PLAN.md` 状态，偏差和风险写入 `review.md`。

---

## 四、阶段路线图

### Phase 0：计划锁定与基线整理 ✅
### Phase 1：架构边界与工程骨架 ✅
### Phase 2：NovaScript 兼容基线 ✅
### Phase 3：Checkpoint / Bookmark 存档核心 ✅
### Phase 4：章节选择、全局进度与标题体验 ✅

### Phase 5：ViewManager 与 UI 产品层成熟化 🔄 核心完成

- [x] ViewManager 状态机 + transition input blocker
- [x] 切出 GameView 时暂停动画/音频
- [x] 统一 Toast 通知 + Alert 确认框
- [x] 移动端强制横屏 + GameView 自适应布局
- [x] StandingProfile 立绘合成 + VisualProfile 资源 alias
- [x] 输入映射：按键录制、冲突提示、ConfigFile 持久化
- [x] 存读档丰富列表：缩略图、章节名、时间、位置
- [x] 回顾面板：语音重播、跳转确认
- [x] ThemeManager base/work 两层核心主题架构
- [ ] debug theme 与调试模式主题切换

### Phase 6：动画系统升级 ✅ 核心完成

- [x] 动画域：PER_DIALOGUE、HOLDING、UI、TEXT
- [x] then/and_anim 语义 + 命名 holding 组
- [x] pause/resume/stop 按域控制 + ViewManager 集成
- [x] Easing parser（12 种缓动类型）
- [x] 更丰富的 property：Float/Vector2/MoveTo/FadeTo/RotateTo/ScaleTo/TintTo

### Phase 7：VFX / Shader / Transition 系统 🔄 核心完成

- [x] OBJECT/POST effect registry
- [ ] TRANSITION effect registry（当前转场仍由 `match` 分支选择 shader）
- [x] effect-list bookkeeping、`clear_effect()`、snapshot/restore
- [x] 多参数动画 + 8 种逻辑效果入口
- [x] 新增 glitch.gdshader、ripple.gdshader
- [ ] 真正多 pass shader/material compositing（CanvasItem 当前只渲染顶部材质）
- [x] `capture_screen()` API
- [ ] captured texture 接入 shader transition
- [ ] shaderproto 生成器

### Phase 8：资源加载、预加载与内容生产工具 🔄 核心完成

- [x] 严格资源扫描：包含 `say(speaker, id)`，`referenced=369`、`found=367`、`virtual=2`、`missing=0`
- [x] PreloadSystem 优先级、分类型 LRU、取消、引用计数与进度
- [x] Scenario lint：公共 Python CLI、text/JSON 报告、可配置失败阈值、稳定定位、结构/流程/资源/兼容规则与 smoke test
- [x] execution-free Scenario analysis IR：统一输出 blocks/nodes/entries/silent entries/edges/events，供统计与后续可视化复用
- [x] Scenario stat：Python/Godot CLI、text/JSON、对白规范化/长度/说话人/节点/文件统计、默认基线与 smoke test
- [ ] Scenario visualize / branch visualization：消费共享 IR 展示 nodes/edges/events
- [ ] list_bg/list_bgm 等资源列表工具
- [ ] 立绘导入约定与工具

### Phase 9：小游戏、中断与扩展接口 🔄 核心完成

- [x] InterruptManager：begin/end_interrupt 协议
- [x] 中断期间暂停推进 + 结束后自动 checkpoint
- [x] BaseBlock 暴露中断 API + restorable 注册
- [x] Gameplay prefab manager：WORLD/UI/PERSISTENT 分类生命周期
- [ ] 示例小游戏场景

### Phase 10：平台、质量与发布 🔄 核心完成

- [x] 20/20 个 headless 测试纳入自动发现并通过（约 55 秒）
- [x] Python 聚合 runner：`scripts/tests/run_headless_suite.py`
- [x] CI/Release 在所有导出 job 前执行 Scenario lint（error 阻断、warning 默认不阻断）与 headless quality gate
- [x] 主场景 headless 加载通过
- [x] 文档对齐至 2026-07-10 当前事实
- [ ] 导出产物启动 smoke test + 性能基线
- [ ] 示例作品完善

---

## 五、阶段状态表

| Phase | 名称 | 状态 |
|-------|------|------|
| 0 | 计划锁定与基线整理 | ✅ 完成 |
| 1 | 架构边界与工程骨架 | ✅ 完成 |
| 2 | NovaScript 兼容基线 | ✅ 完成 |
| 3 | Checkpoint / Bookmark 存档核心 | ✅ 核心完成 |
| 4 | 章节选择、全局进度与标题体验 | ✅ 核心完成 |
| 5 | ViewManager 与 UI 产品层成熟化 | ✅ 核心完成 |
| 6 | 动画系统升级 | ✅ 核心完成 |
| 7 | VFX / Shader / Transition 系统 | ✅ 核心完成 |
| 8 | 资源加载、预加载与内容生产工具 | ✅ 核心完成 |
| 9 | 小游戏、中断与扩展接口 | ✅ 核心完成 |
| 10 | 平台、质量与发布 | ✅ 核心完成 |

---

## 六、下一步开发路径

优先级从高到低：

1. **Scenario visualize / branch visualization** — 直接消费 `scenario_analysis.gd` 的 nodes/edges/events，补分支展示与流程可视化。
2. **VFX 深化** — 实现 TRANSITION registry、真正多 pass compositing，并把 captured texture 传入 shader transition。
3. **导出与性能** — 对 Windows/Linux/Android 导出产物做启动 smoke test，建立解析、预加载、存档与回跳性能基线。
4. **示例作品** — 完善 3 章节样例，覆盖分支/结局/CG/BGM/回跳/小游戏。
5. **主题与内容工具补齐** — debug theme、立绘导入约定与 shaderproto 生成器。

---

## 七、文档索引

| 文档 | 用途 |
|------|------|
| `PLAN.md` | 路线、任务、状态、验收标准 |
| `review.md` | Nova 对比、阶段审查、风险记录 |
| `docs/NovaScript.md` | 脚本语法、兼容表、API 参考 |
| `docs/PhaseBacklog.md` | 各 Phase commit 粒度清单 |
| `docs/ProjectTerms.md` | 术语表 |
| `docs/CodingStandards.md` | 编码规范 |
| `README.md` | 用户视角快速开始和能力摘要 |
| `Setup.md` | 环境搭建与架构概览 |
