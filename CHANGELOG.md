# Changelog

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
