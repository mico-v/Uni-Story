# Uni-Story

Uni-Story 是从 Nova2 项目继续开发而来的 Godot 视觉小说运行时/框架。当前分支基于 Godot 4.6，保留 NovaScript 风格的剧本组织方式，并把演出脚本块编译为真正的 GDScript 执行，用于验证更轻量、可重放的视觉小说运行时架构。

本仓库延续自 Nova2，原项目采用 MIT License。继续开发、分发或再授权本项目时，需要保留 `LICENSE` 中的原版权声明和许可文本。

## 当前状态

- 引擎：Godot 4.6
- 主场景：`res://scene/game.tscn`
- 当前开发分支：`rewrite/godot4.6`
- 运行时路线：纯 GDScript 实现核心模型与演出运行时
- 剧本路线：保留 NovaScript 格式，将 `<|...|>` / `@<|...|>` 演出块包装为 `BaseBlock` 子类并在运行时编译执行

当前重点是视觉小说运行时和演出系统。项目已经具备脚本解析、流程图、对话、选项、图片显示、立绘合成、头像、动画、音频接口、镜头、转场、变量、存档和文本回顾等基础能力。详细开发记录见 [PLAN.md](PLAN.md)。

## 快速启动

1. 安装 Godot 4.6。
2. 使用 Godot 打开本仓库根目录。
3. 运行主场景 `res://scene/game.tscn`。

仓库中保留了 Godot .NET 项目文件，但当前 `rewrite/godot4.6` 分支的核心运行时主要由 GDScript 驱动。本地没有 .NET 环境时，也可以先使用 Godot 编辑器运行和验证 GDScript 侧功能。

## 主要能力

- 剧本解析：将 NovaScript 剧本切分为 eager、lazy 和 text 块。
- 流程图：构建章节、节点、跳转和选项。
- 对话系统：支持说话人、逐字显示、对话框位置预设和文本回顾。
- 图片与立绘：支持图片显示/隐藏/移动/染色，多图层立绘合成和头像切换。
- 动画系统：支持 `o.anim` 链式动画，链内顺序执行，跨语句并行执行。
- 音频接口：提供 BGM、SE、Voice 的运行时 API。
- 镜头与转场：支持逻辑相机移动、缩放、旋转，以及 fade、fade_in、flash。
- 变量与分支：支持运行时变量、条件跳转和分支选择。
- 存档与回顾：支持 JSON 存档槽位、模型快照/重放和 backlog。
- 自动播放与快进：Auto 模式打字机结束后定时推进，Skip 模式跳过已读文本并在未读处自动停止。

## 目录结构

```text
scene/
  game.tscn                 # 项目主场景，只挂载 NovaController
scripts/
  NovaController.gd          # Node 中枢，创建运行时子系统并桥接模型与视图
  core/                      # 纯模型、剧本解析、流程图、状态、存档、回顾
  runtime/                   # 演出脚本运行时、图像、动画、音频、镜头、转场等系统
resources/
  scenarios/                 # 示例剧本与测试剧本
  characters/                # 示例角色素材
  demo_media/                # 示例演示素材
addons/godot_mcp/            # Godot MCP 调试/自动化插件
```

## 剧本 API

演出脚本块继承 `BaseBlock`，可使用下列运行时 API。完整说明和当前进度见 [PLAN.md](PLAN.md)。

- 流程：`label`、`jump_to`、`jump_if`、`branch`、`is_start`、`is_end`
- 图像：`show`、`hide`、`move`、`tint`
- 立绘与头像：`show_char`、`set_layer`、`hide_char`、`set_avatar`、`clear_avatar`
- 动画：`o.anim.PropertyVector3(...)`、`o.anim.PropertyColor(...)`
- 音频：`play_bgm`、`stop_bgm`、`play_se`、`play_voice`
- 镜头/转场/对话框：`cam`、`trans`、`set_box`
- VFX：`vfx`、`clear_vfx`、`post_fx`、`clear_post_fx`、`shake`
- 变量：`set_var`、`get_var`、`has_var`、`add_var`
- 其它：`wait`、`print`

## 路线图

近期计划优先补齐以下能力：

- ViewManager 与统一视图切换
- 设置界面、快捷键和音量/文字速度配置
- 脚本热加载

更完整的路线图请查看 [PLAN.md](PLAN.md)。

## 许可

本项目基于 Nova2 继续开发，遵循 MIT License。原版权声明为：

```text
Copyright (c) 2024 Lunatic Works
```

任何复制、修改、合并、发布、分发、再授权或销售本项目副本的行为，都必须在副本或实质性部分中包含 MIT 许可文本和上述版权声明。完整许可文本见 [LICENSE](LICENSE)。
