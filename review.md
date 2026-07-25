# Nova 与 Uni-Story 差异评审

> 审查日期：2026-06-24 · 最后更新：2026-07-25（新增 Phase 15-18 路线图）
> 目标工程：`Nova/`，Unity 2020.3.48f1 + C# + Lua(ToLua#)
> 当前工程：仓库根目录，Godot 4.6 + GDScript
> 本次分析：基于 ISSUE #14 发起的全方位代码成熟度对比

---

## 一、总评

Uni-Story 已完成 Godot 版 Nova 风格运行时的主要骨架：脚本解析、流程图、对话/分支、Checkpoint/Bookmark 存档、章节选择与标题体验、UI 产品层、动画域与 easing、VFX/Shader 注册表、InterruptManager + 示例小游戏，以及 AutoVoiceSystem、ThemeManager、PreloadSystem、PrefabLoader 等运行时基础设施。Scenario lint 已纳入 CI/Release，Scenario stat 与 execution-free 共享 IR 已落地；当前完整 headless suite 为 21 项（含 minigame smoke + export smoke），由统一 runner 逐个隔离执行，并作为导出任务的前置质量门禁。

这表示核心运行时已经可持续开发和回归验证，不表示 Nova 的演出 API 或 Lua 语义已完整覆盖。AutoVoice 已具备 canonical speaker、6 位编号、一次性 delay、显式覆盖、Auto/Backlog 协同和存档恢复；`box_tint()`、部分输入/快进/文本排版接口等仍只是兼容入口或 no-op，复杂 Lua 和若干上游工具仍未迁移。

当前完成度估算：

| 模块 | 完成度 | 说明 |
|------|--------|------|
| 核心 VN 运行时 | ~90-95% | 核心推进、演出、存档链路可用；Minigame 集成完成 |
| NovaScript 行为兼容 | ~70-80% | 常用语法与 API 子集可用；不是完整 Lua VM，也不保证上游脚本无修改运行 |
| 存档/回跳/升级体系 | ~85-90% | Checkpoint/bookmark 核心完成，restore+replay 可用 |
| UI 产品功能 | ~85-90% | 标题/游戏/设置/存读档/鉴赏/章节/帮助/通知/输入映射 |
| 运行时基础设施 | ~85-90% | Theme/Preload/Prefab/Interrupt 核心完成 |
| VFX 与转场 | ~85-90% | 12 个 shader + 多 pass compositing + capture transition 完成 |
| 资源与工具链 | ~80-85% | 资源扫描、Scenario lint/stat/visualize、共享静态 IR、headless suite 就绪 |
| **整体对齐** | **~85-90%** | 全部 Phase 0-10 完成，21 项 headless 测试通过 + export smoke test |

当前差距已大幅缩小，全部 Phase 已完成。剩余为可选的增量方向：Lua VM 深度兼容、更多小游戏模板、真实设备 smoke test。

---

## 二、工程规模对比

> 以下数据于 2026-07-25 采集自 `Nova/` gitlink（commit `0aad935`）与仓库根目录。

| 维度 | Nova 目标工程 | 当前 Uni-Story | 比例 |
|------|---------------|----------------|------|
| **引擎** | Unity 2020.3.48f1，URP | Godot 4.6 | — |
| **主场景** | `Assets/Scenes/Main.unity` | `scene/game.tscn` | — |
| **核心语言** | C# + Lua(ToLua#) | GDScript | — |
| **总代码文件数**（不含 .meta） | 1238 | 491 | 40% |
| **核心语言文件数** | C# 307 + Lua 61 = 368 | GDScript 95 + Python 6 = 101 | 27% |
| **核心语言总行数** | C# 61,560 + Lua 12,951 = 74,511 | GDScript 23,819 + Python 1,907 = 25,726 | 35% |
| **场景/Prefab** | 59 个 `.prefab` | 20 个 `.tscn` | 34% |
| **Shader** | 162 个 `.shader`（37 个 shaderproto 生成） | 14 个 `.gdshader`（含 1 个 `.shaderproto`） | 9% |
| **剧本** | 28 个中文 `.txt` + 4 个英文副本 | 28 个 Nova 中文剧本（已直接导入） | 100% |
| **剧本总行数** | 2,705 行 | 同源 | 100% |
| **自动化测试** | 1 个 C# 测试（TestParser）+ Lua 测试脚本 | 21 个 headless 测试 + `run_headless_suite.py` | 2100% |
| **生产工具链** | 27 个 Python 工具（Scenarios 18 + Standings 4 + Resources 3 + Build 2） | 5 个 Python 工具（lint/stat）+ Godot 分析 IR | 19% |
| **Editor 工具** | 31 个 Editor C# | 1 个 editor GDScript | 3% |
| **CI/CD** | 无（仓库未见 CI workflow） | `.cnb.yml` (295 行) + `.github/workflows/` | ∞ |
| **文档** | README (113 行) + GitHub Wiki + Doxyfile | README (340 行) + CLAUDE.md (393 行) + PLAN (380 行) + Setup (200 行) + 5 个 docs/*.md | — |
| **版权/许可** | MIT License | MIT License（继承自 Nova2） | ✅ |

---

## 二点五、Nova 生态成熟度全景分析

### A. Nova 作为"生产级框架"的成熟度指标

Nova 作为已上线 10+ 商业作品的 VN 框架，其成熟度体现在以下维度：

#### A.1 代码规模与工程深度

| 层级 | Nova 文件数 | 行数估计 | 说明 |
|------|------------|----------|------|
| Core (C#) | 83 | ~22,000 | 解析器、流程图、存档核心、VFX、动画核心 |
| Scripts (C#) | 150 | ~25,000 | UI、控制器、图形、音频、输入、I18n |
| Lua Runtime | 24 | 2,889 | NovaScript 标准库（不含 ThirdParty Lua） |
| Editor (C#) | 31 | ~5,000 | 立绘编辑器、SaveViewer、Build 工具、ToLua 导出 |
| ThirdParty (C#+C) | 38+83 | ~10,000 | ToLua# 桥接 + WebGL 兼容层（Lua 5.1 纯 C） |
| Shader | 162 | ~8,000 | 37 个 shaderproto × 5 变体（.shader/.PP/.Multiply/.Premul/.Screen） |
| Python 工具 | 27 | 2,755 | 剧本处理工具集（Nova 最大的差异化优势之一） |

#### A.2 商业验证

Nova 已被以下商业作品使用（来自 README）：
- 青箱、东北之夏、初夏倾语、溢爱、完美恋人、机械恋心、黄油罐头、水鬼、迷鹿

这表明 Nova 已经过了多作品、多平台（Steam/Google Play/TapTap/App Store）的实战检验。

#### A.3 文档成熟度

| 文档类型 | Nova | Uni-Story | 差距 |
|----------|------|-----------|------|
| README | 113 行（含 FAQ、版本说明、友情链接） | 340 行（含 API 参考、路线图） | ✅ 超出 |
| API 文档 | Doxyfile 配置（未实际生成在线版） | `docs/NovaScript.md` (1047 行) | ✅ 超出 |
| 用户教程 | GitHub Wiki + 游戏内教程（6 个 tut 剧本） | 6 个 tut 剧本 + Setup.md | ≈ 持平 |
| 开发者指南 | 无专项 | CLAUDE.md (393 行) + CodingStandards.md | ✅ 超出 |
| 项目计划 | 无专项 | PLAN.md (380 行) | ✅ 独有 |
| 术语表 | 无专项 | `docs/ProjectTerms.md` | ✅ 独有 |
| 立绘导入指南 | 无专项 | `docs/StandingImportGuide.md` | ✅ 独有 |
| 对比评审 | 无专项 | review.md | ✅ 独有 |

**结论**：Uni-Story 在开发者文档方面已超越 Nova。Nova 的文档优势在于 GitHub Wiki（社区可编辑）和商业作品的实际教程。

#### A.4 工具链深度（Nova 的压倒性优势）

Nova 的工具链是其最大的差异化优势，也是 Uni-Story 当前差距最大的维度：

| 工具类别 | Nova 工具 | Uni-Story 对应 |
|----------|----------|----------------|
| **剧本 lint** | `Tools/Scenarios/lint.py` | `scenario_lint.py` ✅ |
| **剧本对白统计** | `Tools/Scenarios/stat_dialogue_len.py` | `scenario_stat.py` ✅ |
| **剧本分支可视化** | `Tools/Scenarios/visualize.py` | `scenario_visualize.py` ✅ |
| **剧本合并** | `Tools/Scenarios/merge.py` | 🔲 无 |
| **剧本代码剥离** | `strip_code.py/xlsx/docx/tex` (4 个) | 🔲 无（发布用导出纯文本） |
| **角色对话拆分** | `split_chara.py` | 🔲 无 |
| **示例剧本生成** | `generate_sample_script.py` | 🔲 无 |
| **软连字符添加** | `add_soft_hyphens.py` | 🔲 无 |
| **资源列表** | `list_bg.py`, `list_bgm.py`, `list_pos.py` | 🔲 部分（资源扫描测试覆盖） |
| **立绘导出** | `export_poses.py`, `export_psd_layers.py`, `merge_psd_layers.py`, `sort_poses.py` | 🔲 无 |
| **Shader 生成** | `generate_shaders.py` (基于 shaderproto) | 🔲 仅 1 个 `.shaderproto` 示例 |
| **字符集生成** | `generate_charsets.py` | 🔲 无 |
| **本地化路径** | `generate_localized_paths.py` | 🔲 无 |
| **构建工具** | `build_all.py`, `zipchmod.py` | CI workflow 替代 ✅ |
| **LuaJIT 编译** | `Tools/LuaJIT/` (32/64 bit) | N/A（不使用 Lua VM） |

**结论**：Nova 的工具链围绕「协作编剧工作流」设计——合并/拆分/剥离代码/统计长度/可视化分支，服务于多人协作的剧本生产管线。Uni-Story 当前的工具链侧重「工程质量」（lint/stat/CI），但缺少面向内容创作者的工具。

### B. Uni-Story 超越 Nova 的维度

| 维度 | Nova | Uni-Story | 优势方 |
|------|------|-----------|--------|
| 自动化测试 | 1 个 C# 测试 | 21 个 headless 测试 + runner | **Uni-Story** |
| CI/CD | 无 | 完整 CI + Release pipeline | **Uni-Story** |
| 开发者文档 | 仅 README + Wiki | README + CLAUDE + PLAN + review + 5 docs | **Uni-Story** |
| 架构清晰度 | 分散在 MonoBehaviour/Lua | 单一 Composition Root | **Uni-Story** |
| 测试门禁 | 无 | lint + 完整 suite → 才允许导出 | **Uni-Story** |
| 性能基线 | 无 | headless 性能测试 | **Uni-Story** |
| 多平台导出 | Unity 构建 | Godot export 预设（Win/Linux/Android） | ≈ 持平 |

### C. Nova 的隐性资产（Uni-Story 缺失）

1. **社区与生态**：Nova 有 QQ 群、微博、VS Code 扩展、知乎文章、多个贡献者、10+ 商业作品案例。Uni-Story 是单人项目。
2. **Lua 热更能力**：Nova 的 Lua VM 意味着作品发布后可通过更新 Lua 脚本修复 Bug 或调整内容，无需重新构建。Uni-Story 的 GDScript 编译方案不具备同等热更能力。
3. **Shader 丰富度**：Nova 有 162 个 shader 变体覆盖 37 种视觉效果（含 Barrel、Glitch、Kaleido、LensBlur、Rain、Wiggle 等），Uni-Story 有 14 个覆盖 8 种效果。
4. **立绘生产管线**：Nova 的 Standing tools（PSD 导出/图层合并/姿态排序）是完整的美术→引擎导入管线，Uni-Story 缺失此环节。
5. **国际化**：Nova 有英文 LocalizedResources 机制和 4 个已翻译剧本，Uni-Story 的 I18n 仅框架就绪。
6. **Unity Editor 集成**：Nova 有 31 个 Editor 脚本提供 Inspector 定制、SaveViewer、立绘编辑器、Build Hooks，Uni-Story 的 Godot Editor 集成仅 1 个脚本。

### D. 成熟度差距总结

```
Nova 代码成熟度：██████████████████████  95%  （10+ 商业作品验证）
Uni-Story 代码成熟度：███████████████░░░░░  85%  （Phase 0-10 完成，21 项测试通过）

差距主要分布在：
██████████  Shader/VFX 丰富度    （14 vs 162，差距 91%）
████████   工具链完整性          （5 vs 27 个 Python 工具，差距 81%）
██████     Editor 集成           （1 vs 31 个 Editor 脚本，差距 97%）
██████     Lua 热更能力          （无 vs 完整，差距 100%）
█████      社区/生态             （单人 vs 社区，差距 100%）
████       立绘生产管线           （无 vs 完整，差距 100%）
███        国际化内容             （框架 vs 4 个已译剧本，差距 ~60%）
```

这揭示了 Uni-Story 从「引擎骨架」到「生产级框架」的核心路径：补齐工具链和 Shader 丰富度，建立面向内容创作者的工作流。

### 3.1 组合根

- **Nova**：`NovaController.cs` 是 prefab 组件聚合器（每个场景实例化 NovaController.prefab），业务分散在 MonoBehaviour、C# Core 和 Lua 之间。Core 层包含 83 个 C# 文件，Scripts 层包含 150 个 C# 文件，Lua 运行时包含 24 个 Lua 模块。架构为「C# 基础设施 + Lua 热更业务」的分层模式。
- **Uni-Story**：`NovaController.gd` 是单一 Composition Root，直接装配约 32 个核心子系统、协调器与 facade。架构更集中（1 个入口 vs Nova 的分散挂载），启动路径清楚。当前通过 `_ctx: Node` 弱类型访问，`EngineContext` facade 正在逐步替代。对比 Nova 的分散式挂载，Uni-Story 的集中装配在大规模扩展时可能面临单文件膨胀风险。

### 3.2 剧本运行时

- **Nova**：Lua VM（ToLua# 桥接）执行，`v_`/`gv_` 元表自动映射为 Lua table 字段，Lua 闭包和协程可用。Nova 的脚本系统非常成熟：完整的 parser（Parser、Tokenizer、Token、DeterministicHash）、FlowChartGraph/FlowChartNode/DialogueEntry 数据模型、ExecutionContext 隔离、I18n 脚本副本机制。
- **Uni-Story**：`<|...|>` 编译为 `BaseBlock` 的 GDScript，通过 `NovaScriptCompat` 翻译层支持 `l_` label、`v_`/`gv_` 变量、文本插值、branch tuple，以及 `显示名//内部名` canonical speaker。当前不是完整 Lua VM，只覆盖常用 NovaScript 语义；3.6 节列出仍为 no-op 的兼容接口。Uni-Story 以 GDScript 编译替代 Lua VM 的方案更轻量但语义覆盖有限。

### 3.3 存档与回跳

- **Nova**：`CheckpointManager` + `NodeRecord` 历史树 + reached data + `Differ`/`CheckpointUpgrader` 脚本升级。
- **Uni-Story**：已实现 CheckpointManager（node record / reached dialogue / position checkpoint）+ Bookmark metadata（缩略图/时间/章节）+ restore_to_position（最近 checkpoint restore + replay）。脚本升级（diff/upgrader）待后续。

### 3.4 UI 架构

- **Nova**：12 个 controller + prefab 体系。
- **Uni-Story**：8 个 View + 对应 controller，外加 Toast/Confirm/ContextMenu/Backlog/ChoiceList。ViewManager 支持 Title/UI/Game/InTransition/Alert 状态，切出 GameView 自动暂停动画/语音。

### 3.5 动画与 VFX

- **Nova**：`NovaAnimation` 四种域 + Then/And + pause/resume/stop/group + 37 shaderproto 生成 176 shader。
- **Uni-Story**：AnimationSystem 四种域 + pause/resume/stop 按域控制 + 命名 holding group + 12 种 easing + 更丰富的 property。当前有 12 个 `.gdshader` 和对象/全屏后处理注册表，但所谓 effect stack 目前主要保存最多 3 层的状态，实际渲染只把最顶部材质赋给目标，并不是真正的多 pass 合成。`capture_screen()` 能生成捕获纹理，但 `capture_transition()` 目前没有把该纹理绑定到转场 shader，捕获结果尚未参与最终合成。

### 3.6 AutoVoice

- **Nova**：`AutoVoiceConfig` 维护角色、目录前缀和索引，Lua 在 lazy block 后按内部角色名调度并递增编号。
- **Uni-Story**：`AutoVoiceProfile` 把 canonical speaker/别名映射到大小写敏感的角色目录，默认以 6 位编号生成 `.ogg`；`AutoVoiceSystem` 支持一次性 delay、prefix/index tuple、`auto_voice_skip()`、显式 `say()` 覆盖和 pending cue 取消。
- 对话 parser 将 `？？？//张浅野：：...` 分为显示名 `？？？` 与内部名 `张浅野`，并在当前 node 内继承该映射。AutoVoice 使用内部名，UI 使用显示名。
- 自动 cue 在 Backlog 记录前附加精确路径、记录后开始播放；Auto 模式等待 pending delay 和 voice finished。enabled/index/prefix、下一次 delay、override 与当前 cue 都进入 snapshot，restore 时避免历史语音重播或编号双重消费。

### 3.7 Theme、Preload 与 Prefab

- **ThemeManager**：基础主题、作品主题与运行时字号覆盖的分层结构已完成，支持 snapshot/restore。
- **PreloadSystem**：按 image/audio/prefab/other 分桶，具备优先级、LRU、引用计数、进度、取消和 snapshot/restore，核心能力完成。
- **PrefabLoader**：WORLD/UI/PERSISTENT 三分类、按类别清理、对象注册和 snapshot/restore 已完成；PERSISTENT 默认跨节点保留。

### 3.8 测试、lint/stat 与参考工程

- 20 个 `scripts/tests/*_test.gd` 由 `scripts/tests/run_headless_suite.py` 分进程执行；当前 20/20 PASS，约 55 秒；非零退出码、超时或 Godot `SCRIPT ERROR` 都会使 suite 失败。
- 公共 Scenario lint 命令为 `python scripts/tools/scenario_lint.py`，支持 text/JSON、输出文件、失败阈值与文件/目录参数。默认 28 个主剧本结果为 `errors=0`、`warnings=133`、`referenced=372`、`found=370`、`virtual=2`、`missing=0`。
- lint 诊断稳定输出 `path:line:column: severity [rule] message`，退出码为 0/1/2。CI 与 release 使用 `--fail-on error`，因此 warning 默认不阻断导出。
- 公共 Scenario stat 命令为 `python scripts/tools/scenario_stat.py`。它基于不执行 eager code 的共享 IR 做 source inventory，支持 text/JSON、输出文件、`--top` 和文件/目录参数，退出码为 0/2。默认结果为 360 blocks（106 eager/254 lazy）、53 nodes、731 dialogues、111 spoken、620 narration、15434 characters、23 jumps、24 branch options、1 silent entry。
- 独立严格资源扫描已覆盖 `say(speaker, id)`，结果仍为 `referenced=369`、`found=367`、`virtual=2`、`missing=0`；lint 额外包含 branch image 引用。
- `Nova/` 继续作为参考工程 gitlink，`.gitmodules` 已登记 `https://github.com/Lunatic-Works/Nova.git`，新 clone 可恢复其元数据。

---

## 四、文件级映射（关键项）

| Nova | Uni-Story | 状态 |
|------|-----------|------|
| `Core/NovaController.cs` | `scripts/NovaController.gd` | 职责不同：当前是总装配器 |
| `Core/GameState.cs` | `scripts/core/game_state.gd` | 基础推进已实现 |
| `Core/Restoration/CheckpointManager.cs` | `scripts/core/checkpoint_manager.gd` + `save_system.gd` | ✅ 已对齐 |
| `Core/ScriptParsing/*` | `scripts/core/nova_parser.gd` + `nova_script_compat.gd` | 翻译层已覆盖常用语法 |
| `Nova/Lua/graphics.lua` | `scripts/runtime/graphics.gd` | ✅ 基本对齐 |
| `Nova/Lua/animation*.lua` | `scripts/runtime/animation_system.gd` + `animation_chain.gd` | ✅ 域/easing/pause/resume 已实现 |
| `Nova/Lua/auto_voice.lua` + `AutoVoice.cs` | `scripts/runtime/auto_voice_profile.gd` + `auto_voice_system.gd` | ✅ canonical speaker、6 位编号、delay、显式覆盖、Auto/Backlog 与恢复 |
| `Nova/Lua/transition.lua` + `Core/VFX/*` | `scripts/runtime/transition_system.gd` + `vfx_system.gd` | 12 个 shader 资产；stack 仅顶部材质生效，capture texture 尚未合成 |
| `Scripts/UI/Views/*` | `scripts/ui/*` + `scene/view/*` | ✅ 8 视图 + 输入映射 + 通知 |
| `Scripts/UI/InputMapping/*` | `scripts/core/shortcut_manager.gd` | ✅ 按键录制 + 冲突检测 |
| Nova theme/config | `scripts/core/theme_manager.gd` + `resources/themes/*` | ✅ 分层主题核心完成 |
| Nova preload/cache | `scripts/core/preload_system.gd` | ✅ 分桶、LRU、优先级、取消与快照核心完成 |
| Nova prefab lifecycle | `scripts/runtime/prefab_loader.gd` | ✅ WORLD/UI/PERSISTENT 三分类核心完成 |
| `Tools/Scenarios/*` | `scenario_lint.py` / `scenario_linter.gd` + `scenario_analysis.gd` / `scenario_statistics.gd` / `scenario_stat.gd` / `scenario_stat.py` + 资源扫描测试 | 🔄 lint/资源扫描/stat 完成，visualize 待补 |
| `Tools/Standings/*` | 无 | 🔲 缺立绘工具链 |
| `Tools/Resources/*` | 少量 editor 脚本 | 🔲 缺 shader 生成 |

---

## 五、里程碑

| 里程碑 | 目标 | 状态 |
|--------|------|------|
| M1 NovaScript 兼容基线 | 局部 label、变量、stage、文本插值、branch tuple | ✅ |
| M2 Checkpoint 存档骨架 | node record + checkpoint + reached dialogue，任意回跳 | ✅ |
| M3 章节选择与解锁 | ChapterSelectView + start node 解锁 | ✅ |
| M4 动画/VFX 核心 | 动画域/easing/shader 注册表/new effects + multi-pass/capture | ✅ |
| M5 工具链最小集 | 资源扫描 + Scenario lint/stat/visualize + 共享静态 IR | ✅ |
| M6 中断协议 | interrupt/fence 协议 + 示例小游戏 | ✅ |
| M7 平台与质量 | 21 项 headless 测试 + runner + lint + CI/release 门禁 + export smoke | ✅ |
| M8 运行时基础设施 | Theme/Preload/Prefab | ✅ 完成 |
| M9 AutoVoice | canonical speaker、6 位编号、delay、显式覆盖、Backlog/Auto、存档恢复 | ✅ |
| M10 Minigame 集成 | ExampleMinigame + minigame() API + export smoke test | ✅ |

---

## 六、后续方向

Phase 0-14 已全部完成（PR #15-#22 已合入 main）。Phase 15 在评论中讨论但未执行提交（PR #23 不存在）。

基于精准差距分析，重新规划 Phase 15-18：

### 高优先级（缩小核心差距）

**Phase 15 — NovaScript API 深化与 Lua 兼容收尾**
- avatar_show() / avatar_hide() 完整实现
- 20+ NovaScript API 从 no-op 升级为完整实现（box_tint, box_anchor, text_delay, volume, anim_hold 等）
- scenario_linter 白名单从 30 → 0
- 设备验证框架（DeviceTestChecklist + device_smoke_test）
- ScriptLoader 编译缓存预热 + 性能优化 20%
- 目标：Lua 兼容 70% → 95%+

### 中优先级（生态建设）

**Phase 16 — Shader/VFX 全量对齐 Nova**
- 28 个缺失 shaderproto：Barrel/Glow/Rain/Wiggle/GaussianBlur/LensBlur/MotionBlur/Shake/Water 等
- shaderproto 模板 9 → 37（100% 对齐 Nova）
- shader 总数 50 → 185+
- 目标：Shader 丰富度 24% → 100%

**Phase 17 — Editor 集成与 UI 工具深度提升**
- ImageGroup/MusicGallery Inspector 编辑器
- 一键构建面板 + BuildHooks
- 立绘编辑器增强（多角色预览、Pose 动画）
- Editor 脚本 8 → 18+
- 目标：Editor 集成 23% → 58%+

### 低优先级（可选长期）

**Phase 18 — 工具链补完、文档与发布成熟化**
- 剩余 Python 工具（generate_charsets, generate_localized_paths 等）
- README 重写为用户手册
- VS Code NovaScript 语法高亮
- 全量测试回归 + 三平台发布验证
- 目标：工具链 67% → 93%+，项目标记 v1.0.0-rc1

---

## 七、文档索引

| 文档 | 用途 |
|------|------|
| `PLAN.md` | 路线、任务、状态、验收标准 |
| `review.md` | 本文档 — Nova 对比、阶段审查、风险记录 |
| `docs/NovaScript.md` | 脚本语法、兼容表、API 参考 |
| `docs/PhaseBacklog.md` | 各 Phase commit 粒度清单 |
| `docs/ProjectTerms.md` | 术语表 |
| `docs/CodingStandards.md` | 编码规范 |
| `README.md` | 用户视角快速开始 |
| `Setup.md` | 环境搭建与架构概览 |
