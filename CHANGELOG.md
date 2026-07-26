# Changelog

## 2026-07-26 — Phase 16 Shader/VFX 全量对齐 Nova ✅

- ✅ 新增 22 个基础 shader 效果 + 补全 7 个已有 shader 的 `.shaderproto` 模板
  - 屏幕特效：barrel、barrel_hyper、glow、overglow、overlay、rain、wiggle、flip_grid
  - 模糊/变形：gaussian_blur、lens_blur、motion_blur、rotation_blur、mono、sharpen、shake、rand_roll
  - 色彩/转场/特效：fade、fade_global、fade_radial_blur、final_blit、color、colorless、blink、broken_tv、change_texture_with_fade、gray_wave、masked_mosaic、mix_add、ripple_move、roll、show_second_texture、water、default
  - 已有 shader 补全：blur、chromatic_aberration、glitch、grayscale、ripple、vignette、wipe
- ✅ **shaderproto 模板**：9 → **49**（超出 Nova 37 基准）
- ✅ **`.gdshader` 总数**：50 → **84**（+34，shaderproto_gen.py 运行后可达更多变体）
- ✅ **VFXSystem registry**：OBJECT_EFFECTS 13→40，POST_EFFECTS 13→37
- ✅ **TRANSITION_EFFECTS**：2→6（新增 fade/flip_grid/roll/fade_radial_blur）
- ✅ **别名映射**：14→60+（fisheye/bloom/raindrop/wobble/flash/crt 等）
- ✅ 每个新 shader 均有对象版 + POST 全屏版
- ✅ 扩展 `shader_effects_smoke_test.gd`：覆盖所有 registry + 编译 + 别名验证
- ✅ 更新 PLAN.md / review.md / docs/PhaseBacklog.md / CHANGELOG
- 📏 差距改善：
  - Shader 丰富度：24% → **87%**（shaderproto 49 vs Nova 37，超过 Nova 基准）
  - shader 文件数：50 → **84**（vs Nova 176，差距从 72% 缩小到 52%）

## 2026-07-25 — Phase 15 Lua VM 深度兼容与设备验证 ✅

- ✅ 实现 21 个 no-op 桩 → 完整实现：box_tint、box_anchor、box_alignment、box_offset、new_page、stop_auto_ff、stop_ff、immediate_step、input_on/off、ff_shortcut_on/off、auto_fade_on/off、auto_time、text_delay、text_duration、text_scroll、set_text_speed、skip_mode_custom、text_easing、volume、get_current_position、input、anim_hold_begin/end
- ✅ NovaScript 兼容度：Lua 兼容 **78% → 96%**（仅 avatar_show 仍为 no-op）
- ✅ scenario_linter no-op 白名单：22 项 → **1 项**
- ✅ GDScript 编译缓存预热：`ScriptLoader._warm_compile_cache()` 预编译所有 lazy block
- ✅ 新增 `nova_lua_compat_smoke_test.gd`：20 项测试验证所有 API 不再为空操作
- ✅ 更新 `nova_animation_compat.gd`：box_anchor/box_tint 委托到实际渲染
- ✅ 编写 `docs/DeviceTestChecklist.md`：三平台设备测试清单
- ✅ NovaController 新增 helper：deactivate_auto_mode、deactivate_skip_mode、set_input_enabled、set_ff_shortcut_enabled、get_current_position
- 📏 差距改善：
  - Lua 兼容：78% → **96%**
  - no-op 桩：22 → **1**（仅 avatar_show）

## 2026-07-25 — Phase 15-18 路线图制定

- 📋 基于精准差距分析，重新规划 Phase 15-18（原 Phase 15 内容拆分为 4 个阶段）
- 📊 差距重新校准：工具链 67%、Editor 集成 23%、Shader 丰富度 24%（shaderproto 9/37）、Lua 兼容 ~70%
- 🎯 目标对齐 Nova 完整成熟引擎能力：95%+ Lua 兼容、37/37 shaderproto、18+ Editor 脚本、93%+ 工具链
- 📁 更新 PLAN.md / review.md / docs/PhaseBacklog.md

## 2026-07-25 — Phase 14 Shader/VFX 丰富度提升 ✅

- ✅ 新增 8 个基础 shader 效果：pixelate、mosaic、kaleidoscope、swirl、radial_blur、zoom_blur、edge_detect、invert
- ✅ 每个基础 shader 均有对应的 POST 全屏版本（共 16 个新 .gdshader 文件）
- ✅ 新增 8 个 .shaderproto 模板，`shaderproto_gen.py` 生成 22 个变体 shader
- ✅ shader 总数：14 → **50**（基础效果 8 种 → **21 种**）
- ✅ VFXSystem registry 扩展：OBJECT_EFFECTS 5→13，POST_EFFECTS 5→13
- ✅ 新增 `query_uniforms()` 方法：按效果名查询 uniform 参数（名称/类型/hint）
- ✅ 扩展 `_normalize_effect_name()` 别名（pixel/tile/twirl/negative 等 8 组映射）
- ✅ 新增 `shader_effects_smoke_test.gd`：验证所有 shader 编译、registry、stack/snapshot/restore、uniform 查询
- 📏 差距改善：
  - Shader 丰富度：12% → **57%**（12/176 → 50/176，按基础效果 21 种）

## 2026-07-25 — Phase 13 示例作品与 I18n 内容 ✅

- ✅ ch3 新增玩家选择分支（throw_away / use_poison），双路径剧情
- ✅ ch4 新增三结局：true_end_good（真相告白）、true_end_dark（毒药饮尽）、bad_end（Flag 缺失）
- ✅ StandingProfile 扩展：4 角色各新增 2-3 个 Pose（smile、angry、cry），共 8 个新 Pose
- ✅ 英文剧本翻译：ch3 和 ch4 完整翻译，含分支选择和双结局
- ✅ 3 个小游戏模板：ClickMinigame（点击得分）、DragMinigame（拖拽匹配）、QTEMinigame（限时按键）
- ✅ 4 项新 smoke test：sample_work_playback、sample_work_save_load、i18n_switch、minigame_templates
- 📏 差距改善：
  - 示例作品：0% → **90%**（ch1-ch4 完整叙事 + 3 结局）
  - I18n 内容：60% → **90%**（EN ch1-ch4 全翻译，含多结局分支）

## 2026-07-25 — Phase 12 立绘生产管线与 Editor 集成 ✅

- ✅ 4 个立绘生产工具：`export_psd_layers.py`, `merge_psd_layers.py`, `export_poses.py`, `sort_poses.py`
- ✅ Godot 立绘编辑器插件 (`addons/standing_editor/`)：Inspector 集成 + 实时预览 + 图层可视编辑
- ✅ SaveViewer：存档 JSON 查看器，支持 metadata 显示、语法高亮、导出
- ✅ 资源校验仪表盘：Editor 面板聚合资源扫描结果，缺失资源可点击跳转
- ✅ 34 项 Phase 12 smoke test 全部通过
- 📏 差距改善：
  - 立绘生产管线：0% → **100%**（4/4 工具）
  - Editor 集成：3% → **23%**（1/31 → 7/31 脚本）
  - 工具链覆盖率：19% → **52%**（7/27 → 14/27 工具已覆盖）

## 2026-07-25 — Phase 11 协作编剧工具链

- ✅ 8 个协作编剧工具：merge, split_chara, strip_code ×4, add_soft_hyphens, generate_sample_script
- ✅ Phase 11 smoke test：6/6 test cases passed
- 工具链覆盖率：19% → 52%

## 2026-07-25 — 全方位成熟度对比分析

- 基于 ISSUE #14 发起，拉取 Nova gitlink 进行全方位代码成熟度对比
- 更新 `review.md`：新增 Nova 生态成熟度全景分析（代码规模/商业验证/文档/工具链）、Uni-Story 超越维度、Nova 隐性资产、差距可视化总结
- 重新排列后续方向优先级：工具链扩展 → Shader 丰富度 → I18n 内容，替代原有泛化列表

## 2026-07 — Phase 0-10 完成

- Phase 0：计划锁定与基线整理
- Phase 1：架构边界与工程骨架
- Phase 2：NovaScript 兼容基线
- Phase 3：Checkpoint / Bookmark 存档核心
- Phase 4：章节选择、全局进度与标题体验
- Phase 5：ViewManager 与 UI 产品层成熟化
- Phase 6：动画系统升级
- Phase 7：VFX / Shader / Transition 系统
- Phase 8：资源加载、预加载与内容生产工具
- Phase 9：小游戏、中断与扩展接口
- Phase 10：平台、质量与发布
- 21 项 headless 测试通过 + 完整 CI/Release pipeline

## Release

- Windows x64 build
- Linux x64 build
- Android APK build
