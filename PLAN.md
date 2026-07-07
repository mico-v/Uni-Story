# Uni-Story 成熟化开发计划

> 当前目标：使用 Godot 4.6 + GDScript，学习 Nova 的架构设计，逐步建设成熟、可维护、可扩展的视觉小说游戏引擎。  
> 参考工程：`Nova/` Unity + C# + Lua(ToLua#)  
> 当前工程：Godot + GDScript-first，不引入 Unity/C# 依赖，不把 Lua VM 作为默认运行时。  
> 日期：2026-06-24 · 最后更新：2026-07-06

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
| 工具链 | 剧本 lint、分支可视化、资源扫描、立绘工具、shader 生成 | Godot/Python 工具并行 |

---

## 二、当前基线

已具备一套可运行的 GDScript 视觉小说框架，10 个 Phase 核心任务全部完成：

- NovaScript eager/lazy/text 块解析 + GDScript 动态编译。
- 流程图、分支、跳转、条件分支、命名结局、局部 label。
- 变量系统（`v_` / `gv_` 兼容）、I18n、ReadTracker、Backlog（语音路径记录）。
- 图像显示/隐藏/移动/染色、StandingProfile 驱动立绘合成、头像切换。
- 动画系统：4 种动画域、pause/resume/stop 按域控制、命名 holding 组、12 种 easing 类型。
- 音频系统：BGM 交叉淡入淡出、SE 池化、Voice 播放、独立音量总线。
- 镜头移动/缩放/旋转、转场（fade/flash/dissolve/wipe）、屏幕震动。
- VFX：8 种对象/后处理 shader 效果（blur/grayscale/dissolve/glitch/ripple/chromatic/vignette + wipe 转场）。
- Prefab 加载、视频播放、Timeline 编排。
- Checkpoint/Bookmark 双层存档模型、缩略图截图、reached dialogue/end 追踪。
- 标题菜单（9 入口）、章节选择、Help、设置、CG/音乐鉴赏、存读档。
- 输入映射（按键录制 + 冲突检测）、Toast 通知、Confirm 确认框。
- InterruptManager（小游戏中断/恢复协议）。
- 移动端横屏自适应、触控操作。
- 8 个 headless 自动化测试（7 smoke + 1 resource scan）。
- Godot export presets + GitHub Actions 发布基础。

主要短板（留到后续）：

- 完整 Lua VM 兼容、auto_voice 真实调度、UI 主题拆分。
- Nova 工具链迁移（lint/visualize/stat）、立绘导入工具、shader 生成器。
- 导出 smoke test、性能基线、示例作品完善。

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

### Phase 5：ViewManager 与 UI 产品层成熟化 ✅ 完成

- [x] ViewManager 状态机 + transition input blocker
- [x] 切出 GameView 时暂停动画/音频
- [x] 统一 Toast 通知 + Alert 确认框
- [x] 移动端强制横屏 + GameView 自适应布局
- [x] StandingProfile 立绘合成 + VisualProfile 资源 alias
- [x] 输入映射：按键录制、冲突提示、ConfigFile 持久化
- [x] 存读档丰富列表：缩略图、章节名、时间、位置
- [x] 回顾面板：语音重播、跳转确认
- [x] UI 主题资源拆分

### Phase 6：动画系统升级 ✅ 核心完成

- [x] 动画域：PER_DIALOGUE、HOLDING、UI、TEXT
- [x] then/and_anim 语义 + 命名 holding 组
- [x] pause/resume/stop 按域控制 + ViewManager 集成
- [x] Easing parser（12 种缓动类型）
- [x] 更丰富的 property：Float/Vector2/MoveTo/FadeTo/RotateTo/ScaleTo/TintTo

### Phase 7：VFX / Shader / Transition 系统 ✅ 完成

- [x] VFX 注册表（OBJECT/POST/TRANSITION 三类）
- [x] 多参数动画 + 8 种 shader 效果
- [x] 新增 glitch.gdshader、ripple.gdshader
- [x] shader layer / material stack / screen capture
- [ ] shaderproto 生成器

### Phase 8：资源加载、预加载与内容生产工具 🔄 核心完成

- [x] 资源扫描测试（scenario_resource_scan_test.gd）
- [x] PreloadSystem 优先级/LRU 升级
- [ ] Nova 工具链迁移（lint/visualize/stat）
- [ ] 立绘导入约定与工具

### Phase 9：小游戏、中断与扩展接口 🔄 核心完成

- [x] InterruptManager：begin/end_interrupt 协议
- [x] 中断期间暂停推进 + 结束后自动 checkpoint
- [x] BaseBlock 暴露中断 API + restorable 注册
- [x] Gameplay prefab manager
- [ ] 示例小游戏场景

### Phase 10：平台、质量与发布 🔄 核心完成

- [x] 8 个 headless 测试全通过
- [x] 主场景 headless 加载通过
- [x] 文档对齐当前进度
- [ ] 导出 smoke test + 性能基线
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

1. **UI 主题拆分** — 支持作品级主题定制（Phase 5 预留）✅
2. **PreloadSystem 升级** — 优先级/取消/LRU/进度（Phase 8 预留）✅
3. **Gameplay prefab manager** — 区分 UI/world/persistent prefab（Phase 9 预留）✅
4. **Shader 深度** — shader layer、render target、shaderproto 生成器（Phase 7 预留）✅
5. **Nova 工具链迁移** — lint、visualize、stat、立绘导入（Phase 8 预留）
6. **导出与性能** — 导出 smoke test、性能基线（Phase 10 预留）
7. **示例作品** — 3 章节完整样例（Phase 10 预留）

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
| `SETUP.md` | 环境搭建与架构概览 |
