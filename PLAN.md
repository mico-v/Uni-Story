# Uni-Story 成熟化开发计划

> 当前目标：使用 Godot 4.6 + GDScript，学习 Nova 的架构设计，逐步建设成熟、可维护、可扩展的视觉小说游戏引擎。  
> 参考工程：`Nova/` Unity + C# + Lua(ToLua#)  
> 当前工程：Godot + GDScript-first，不引入 Unity/C# 依赖，不把 Lua VM 作为默认运行时。  
> 日期：2026-06-24 · 最后更新：2026-07-25

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
- VFX：OBJECT/POST/TRANSITION effect registry、effect-list 状态记录、`clear_effect()`、快照恢复、多 pass SubViewport compositing、`capture_screen()` 接入 shader transition。12 个 `.gdshader` 资产，覆盖 blur/grayscale/dissolve/glitch/ripple/chromatic/vignette/wipe 等效果。
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
- 24 个 headless 测试通过（约 55 秒），由 `scripts/tests/run_headless_suite.py` 聚合执行。
- CI 与 Release workflow 均先执行 Scenario lint（warning 默认不阻断）和 headless quality gate，通过后才允许 Windows/Linux/Android 导出。
- Godot export presets + GitHub Actions 发布基础。
- 性能基线 headless 测试覆盖解析/场景加载/存档/恢复/回跳耗时。
- 导出产物启动 smoke test（`export_smoke_test.gd`：子系统初始化 + ch1 推进 + 存读档 + 视图导航 + ch4 播放）。

主要短板（源自 `review.md` 差距分析）：

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

### Phase 11：协作编剧工具链（高优先级 🔴）

> 目标：补齐 Nova 的协作编剧工作流工具，使内容创作者可以合并/拆分/剥离剧本代码，覆盖从写作到交付的完整流程。  
> 背景：Nova 的 27 个 Python 工具中，协作编剧类工具（merge/split/strip）是制作真实作品的核心依赖；Uni-Story 当前完全缺失。  
> 差距：81%（12/27 工具已覆盖，缺 15 个）。

#### 11.1 剧本合并工具 `merge.py`

- [x] 实现 `scripts/tools/merge.py`：将多个分角色剧本文件合并为单一 NovaScript 剧本
- [x] 支持按角色标签 (`#角色名`) 识别和归并台词
- [x] 支持 `--input-dir`、`--output` 参数
- [x] 输出格式兼容 NovaScript 规范，可直接被现有 parser 解析
- [x] smoke test：`merge_tool_smoke_test.gd` 验证合并输出可被 `ScriptLoader` 正确解析

#### 11.2 角色台词拆分工具 `split_chara.py`

- [x] 实现 `scripts/tools/split_chara.py`：将完整剧本按角色拆分为独立文件
- [x] 支持 `--input`、`--output-dir` 参数
- [x] 保留原始行号和上下文注释
- [x] smoke test：验证拆分后的文件覆盖所有角色的所有台词，无遗漏、无重复

#### 11.3 代码剥离工具家族 `strip_code.py` / `strip_code_docx.py` / `strip_code_tex.py` / `strip_code_xlsx.py`

- [x] 实现 `scripts/tools/strip_code.py`：剥离剧本中所有 `<|...|>` 代码块，输出纯文本
- [x] 实现 `scripts/tools/strip_code_docx.py`：剥离代码后输出 Word (.docx) 格式
- [x] 实现 `scripts/tools/strip_code_tex.py`：剥离代码后输出 LaTeX 格式
- [x] 实现 `scripts/tools/strip_code_xlsx.py`：剥离代码后输出 Excel (.xlsx) 格式（按列：说话人/台词/位置）
- [x] 保留 `（TODO：…）` 注记和 stage directions 作为注释
- [x] 统一 `--input` / `--output` CLI 接口
- [x] smoke test：对 ch1.txt 执行四种剥离，验证输出格式正确且内容完整

#### 11.4 软连字符工具 `add_soft_hyphens.py`

- [x] 实现 `scripts/tools/add_soft_hyphens.py`：在日文/中文文本中自动插入软连字符
- [x] 支持 `--language zh|ja` 参数
- [x] smoke test：验证插入位置符合语言排版规范

#### 11.5 示例剧本生成器 `generate_sample_script.py`

- [x] 实现 `scripts/tools/generate_sample_script.py`：从模板生成示例 NovaScript 剧本
- [x] 支持 `--template basic|branching|minigame` 参数
- [x] 生成结果可被 `ScriptLoader` 正确解析并编译
- [x] smoke test：三种模板生成后均可通过 Scenario lint（error=0）

#### Phase 11 验收标准

- `python scripts/tools/scenario_lint.py` → `errors=0`
- 24 项 headless 测试全部通过
- 新增 4-6 项 smoke test 覆盖新工具
- merge → split → strip 端到端工作流可跑通：合并 2 个分角色文件 → 拆分回独立文件 → 剥离代码输出纯文本/DOCX/TEX/XLSX

---

### Phase 12：立绘生产管线与 Editor 集成（高优先级 🔴）

> 目标：建立从 PSD 源文件到游戏立绘的自动化生产管线，并补齐 Godot Editor 集成能力。  
> 背景：Nova 有 4 个立绘工具 + 31 个 Editor 脚本；Uni-Story 仅有导入约定文档。  
> 差距：立绘工具 0%（0/4）；Editor 集成 3%（1/31）。

#### 12.1 PSD 图层导出工具 `export_psd_layers.py`

- [ ] 实现 `scripts/tools/standing/export_psd_layers.py`：从 PSD 文件导出各图层为独立 PNG
- [ ] 支持 `--input`、`--output-dir`、`--scale` 参数
- [ ] 支持图层分组（body/eye/eyebrow/mouth 等），按 `docs/StandingImportGuide.md` 约定命名
- [ ] smoke test：对示例 PSD 导出，验证图层文件数量、命名和尺寸正确

#### 12.2 PSD 图层合并工具 `merge_psd_layers.py`

- [ ] 实现 `scripts/tools/standing/merge_psd_layers.py`：按 Pose 配置合并图层为单张立绘
- [ ] 读取 `StandingProfile` 中的 offset/scale 配置
- [ ] 支持 `--profile` 指定 Profile 资源路径
- [ ] 输出合并后的 PNG，保持与运行时 `SpriteComposer` 一致的合成结果
- [ ] smoke test：合并结果与运行时立绘渲染做像素级对比

#### 12.3 姿态导出与排序工具 `export_poses.py` / `sort_poses.py`

- [ ] 实现 `scripts/tools/standing/export_poses.py`：从 `StandingProfile` 导出所有 Pose 定义（JSON/YAML）
- [ ] 实现 `scripts/tools/standing/sort_poses.py`：按命名规则排序 Pose 列表
- [ ] smoke test：验证导出和排序后的 Pose 列表与 Profile 一致

#### 12.4 立绘编辑器 Godot Plugin（基础版）

- [ ] 创建 `addons/standing_editor/` Godot EditorPlugin
- [ ] 在 Inspector 中可视化编辑 `StandingProfile` 的图层 offset/scale
- [ ] 实时预览立绘合成效果
- [ ] 支持拖拽调整图层顺序
- [ ] Editor 场景测试：在 Godot 编辑器中加载并操作

#### 12.5 SaveViewer

- [ ] 创建 `scripts/editor/save_viewer.gd`：在 Editor 中查看和解析存档文件
- [ ] 显示 bookmark 元数据（章节、时间、缩略图）和 checkpoint 状态
- [ ] 支持存档 JSON 语法高亮和折叠

#### 12.6 资源校验仪表盘

- [ ] 创建 `scripts/editor/resource_dashboard.gd`：Editor 面板聚合资源扫描结果
- [ ] 显示 referenced/found/missing/virtual 统计
- [ ] 缺失资源列表可点击跳转到对应剧本位置
- [ ] 一键运行 Scenario lint，结果内嵌显示

#### Phase 12 验收标准

- `python scripts/tools/scenario_lint.py` → `errors=0`
- 24 项 headless 测试全部通过
- 新增 4-5 项 smoke test 覆盖立绘工具和 SaveViewer
- PSD → 图层 PNG → merge → 运行时合成，端到端管线跑通
- SaveViewer 可正确解析至少 3 个存档文件
- 资源仪表盘显示结果与 `scenario_resource_scan_test.gd` 一致

---

### Phase 13：示例作品与 I18n 内容（中优先级 🟡）

> 目标：构建完整叙事示例作品，证明引擎可用于真实商业级视觉小说制作；完成英文翻译框架的实质内容填充。  
> 背景：Nova 有 10+ 商业作品验证 + 4 个英文已译剧本；Uni-Story 仅有 4 章技术示例剧本。  
> 差距：叙事验证 0% / I18n 内容 0%。

#### 13.1 示例作品：3+ 章节完整故事线

- [ ] 编写 ch1-ch3 完整叙事剧本（含分支、至少 2 个结局）
- [ ] 覆盖全部核心功能：branch/ending、CG、BGM/BGS/SE、回跳、小游戏
- [ ] 制作配套立绘素材（至少 3 个角色，各 2+ 个 Pose）
- [ ] 配置 `StandingProfile` 和 `VisualProfile`
- [ ] 配置 AutoVoice 语音素材（至少 1 个角色的完整语音）
- [ ] 新增 `sample_work_playback_smoke_test.gd`：完整播放 ch1-ch3 并成功到达所有结局
- [ ] 新增 `sample_work_save_load_test.gd`：在示例作品中存档/读档/回跳全流程

#### 13.2 英文翻译剧本

- [ ] 翻译 ch1-ch3 示例作品为英文版
- [ ] 配置 I18n 映射（`显示名//内部名` → English display name）
- [ ] 英文 UI 字符串审查和完善（`resources/localized_resources/localized_strings/en.json`）
- [ ] 新增 `i18n_switch_smoke_test.gd`：运行时切换 zh/en，验证 UI 和剧本文本均正确切换

#### 13.3 更多小游戏模板

- [ ] 实现点击类小游戏模板 `ClickMinigame`：点击目标得分
- [ ] 实现拖拽类小游戏模板 `DragMinigame`：拖拽物品到目标区域
- [ ] 实现 QTE 类小游戏模板 `QTEMinigame`：限时按键反应
- [ ] 每个模板有独立 `.tscn` + controller + `minigame()` 集成
- [ ] 新增 `minigame_templates_smoke_test.gd`：逐个加载并运行三种模板

#### Phase 13 验收标准

- `python scripts/tools/scenario_lint.py` → `errors=0`
- 全部已有测试通过 + 4 项新 smoke test
- 示例作品 ch1-ch3 完整播放无报错，所有结局可达
- 中英文切换后 UI 和剧本对白正确显示
- 三种小游戏模板可独立运行并正确回传变量

---

### Phase 14：Shader/VFX 丰富度提升（中优先级 🟡）

> 目标：大幅扩充 shader 资产库，缩小与 Nova 的 shader 数量差距（12 vs 176）。  
> 背景：Nova 的 shaderproto 机制可生成 5 种 blend mode 变体 × 37 种基础效果 = 176 个 shader。  
> 差距：91%（12/176）。

#### 14.1 扩充 shaderproto 模板库

- [ ] 新增 8 个基础 shader 效果模板（JSON）：pixelate、mosaic、kaleidoscope、swirl、radial_blur、zoom_blur、edge_detect、invert
- [ ] 每个模板支持与现有 blend mode 变体组合
- [ ] `shaderproto_gen.py` 生成验证：`python scripts/tools/shaderproto_gen.py --all` 无错误

#### 14.2 新增 shader 效果

- [ ] `pixelate.gdshader`：像素化效果（可调 pixel_size）
- [ ] `mosaic.gdshader`：马赛克效果
- [ ] `kaleidoscope.gdshader`：万花筒效果
- [ ] `swirl.gdshader`：漩涡扭曲
- [ ] `radial_blur.gdshader`：径向模糊
- [ ] `zoom_blur.gdshader`：缩放模糊
- [ ] `edge_detect.gdshader`：边缘检测
- [ ] `invert.gdshader`：色彩反转
- [ ] 新增 `shader_effects_smoke_test.gd`：逐个加载并验证所有 shader 编译通过

#### 14.3 VFX 系统增强

- [ ] 注册新 shader 到 OBJECT_EFFECTS 或 POST_EFFECTS registry
- [ ] `VFXSystem` 支持按 uniform 参数查询效果（为后续可视化编辑器做准备）
- [ ] 确保新 shader 均支持 snapshot/restore

#### Phase 14 验收标准

- `python scripts/tools/scenario_lint.py` → `errors=0`
- 全部已有测试通过 + 1 项新 smoke test
- `shaderproto_gen.py --all` 成功生成所有变体
- VFX stack smoke test 覆盖新增效果
- shader 总数达到 20+ 基础效果（含变体 60+）

---

### Phase 15：Lua VM 深度兼容与设备验证（低优先级 🟢）

> 目标：进一步提升 NovaScript 行为兼容度，完成真实设备验证，进行性能优化。  
> 背景：当前 NovaScript 行为兼容 ~70-80%，部分 API 仍为 no-op 兼容桩。  
> 差距：Lua 兼容度缺 ~20-30%。

#### 15.1 Lua VM 兼容深化

- [ ] 实现 `box_tint()` 完整语义（对话框背景染色）
- [ ] 实现输入相关的完整 API（`input()`、输入验证回调）
- [ ] 实现快进/文本排版相关接口（`skip_mode_custom`、text formatting hooks）
- [ ] 实现剩余 Nova Lua API：`set_text_speed()` 运行时动态调整、`get_current_position()` 等
- [ ] 新增 `nova_lua_compat_smoke_test.gd`：验证 Lua API 兼容桩不再为 no-op

#### 15.2 真实设备 smoke test

- [ ] Windows 真机：启动 → 播放 ch1 → 存档 → 读档 → 退出，全程无崩溃
- [ ] Linux 真机：同上
- [ ] Android 真机：启动 → 横屏适配 → 触控操作 → 播放 → 存档/读档 → 退出
- [ ] 记录并修复设备相关 Bug
- [ ] 新增 `device_smoke_test_checklist.md`：设备测试清单和结果记录模板

#### 15.3 性能优化

- [ ] 基于 `performance_baseline_test.gd` 基线，设定优化目标（每项降低 20%）
- [ ] 场景加载优化：减少不必要的 autoload 初始化
- [ ] 存档/恢复优化：增量 snapshot 替代全量序列化
- [ ] 解析优化：ScriptLoader 缓存预热
- [ ] 更新性能基线阈值

#### 15.4 文档与发布准备

- [ ] 更新 `README.md` 为完整的用户使用手册
- [ ] 编写 `docs/ReleaseGuide.md`：发布流程、导出配置、平台注意事项
- [ ] 整理 `CHANGELOG.md` 为面向用户的版本发布日志
- [ ] 所有文档同步至最新事实

#### Phase 15 验收标准

- `python scripts/tools/scenario_lint.py` → `errors=0`
- 全部已有测试通过 + 1 项新 smoke test
- Nova Lua API no-op 桩减少至 0（全部实现或明确标记为 `not_applicable`）
- 三平台真机测试通过
- 性能指标不低于基线（或达标优化目标）
- 所有文档与代码一致

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
| **12** | **立绘生产管线与 Editor 集成** | 🔲 未开始 |
| **13** | **示例作品与 I18n 内容** | 🔲 未开始 |
| **14** | **Shader/VFX 丰富度提升** | 🔲 未开始 |
| **15** | **Lua VM 深度兼容与设备验证** | 🔲 未开始 |

---

## 六、当前状态

**已全部完成 Phase 0-10**（24 项 headless 测试通过 + export smoke test + 性能基线）。

**当前差距**（按优先级，源自 `review.md`）：

```
工具链完整性  ████████░░░░░░░░░░░░  19%  (7/27 工具已覆盖)
立绘生产管线  ░░░░░░░░░░░░░░░░░░░░   0%  (0/4 工具)
Editor 集成   █░░░░░░░░░░░░░░░░░░░   3%  (1/31 脚本)
I18n 内容     ████████████░░░░░░░░  60%  (框架就绪，缺英文剧本翻译)
Shader 丰富度 ████░░░░░░░░░░░░░░░░  12%  (12/176 shader，缺 164)
示例作品      ░░░░░░░░░░░░░░░░░░░░   0%  (无完整叙事示例)
Lua 兼容      ████████████████░░░░  78%  (部分 API 仍为 no-op)
```

**下一步**：按照 Phase 11 → 12 → 13 → 14 → 15 顺序推进，每个阶段独立可验证，完成后更新状态表。

---

## 七、文档索引

| 文档 | 用途 |
|------|------|
| `PLAN.md` | 路线、任务、状态、验收标准 |
| `review.md` | Nova 对比、阶段审查、风险记录 |
| `docs/NovaScript.md` | 脚本语法、兼容表、API 参考 |
| `docs/PhaseBacklog.md` | 各 Phase commit 粒度清单 |
| `docs/ProjectTerms.md` | 术语表 |
| `docs/StandingImportGuide.md` | 立绘导入约定、目录结构、图层命名、Pose 配置 |
| `docs/CodingStandards.md` | 编码规范 |
| `README.md` | 用户视角快速开始和能力摘要 |
| `Setup.md` | 环境搭建与架构概览 |
