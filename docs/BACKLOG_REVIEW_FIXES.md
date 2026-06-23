# Uni-Story 修复记录 —— Backlog 回顾与选单显示

## 修复内容

### 1. Backlog 回顾面板

#### 按当前进度过滤
- 打开回顾面板时，只显示当前进度及之前的对话记录，不显示未来的文本。
- 实现方式：根据 `game_state.current_node.name` 和 `game_state.current_index` 判断每条记录是否在当前位置之后，如果是则跳过渲染。

#### 条目 Hover 效果
- 回顾面板中的每条对话记录都是 `RichTextLabel`。
- 鼠标悬停时通过 `modulate` 改变颜色（变为淡黄色），移出时恢复白色，提供视觉反馈。

#### 跳转确认
- 点击回顾条目时弹出确认对话框，确认后执行完整的加载流程：
  1. `reset_world()` —— 清理运行时状态
  2. `game_state.jump_to_position(node_name, entry_index)` —— 跳转到目标位置
  3. `load_game()` —— 恢复 UI 状态

### 2. 选单（ChoiceList）显示修复

#### 问题现象
- 从 Backlog 跳转到选项分支前时，再次遇到选单会出现**错位、显示不完整**。

#### 修复措施

**`choice_list_controller.gd`**：
1. `clear()` 方法现在会重置布局约束：
   - `custom_minimum_size.y = 0`
   - `clip_contents = false`
   防止旧的状态残留导致后续选单高度计算错误。

2. 无图片分支的按钮添加 `size_flags_horizontal = Control.SIZE_EXPAND_FILL`，确保在 VBoxContainer 中全宽显示。

3. 图片分支的 `HBoxContainer` 添加 `size_flags_vertical = Control.SIZE_SHRINK_CENTER`，防止垂直方向异常拉伸。

**`game_view_controller.gd`**：
- `reset_world()` 中清理 choice_list 时，优先调用 `_choice_list_controller.clear()`（而非直接 `_clear_children`），让 ChoiceListController 自行管理内部布局状态，确保 `custom_minimum_size` 和 `clip_contents` 被正确重置。

### 3. 相关文件变更

| 文件 | 变更 |
|------|------|
| `scripts/ui/choice_list_controller.gd` | 添加 `size_flags`、改进 `clear()` |
| `scripts/ui/game_view_controller.gd` | `reset_world()` 中使用 `_choice_list_controller.clear()` |
| `scripts/ui/backlog_panel_controller.gd` | 添加过滤逻辑和 hover 效果 |

## 技术细节

- **场景继承**：`BtnBack` 等按钮必须存在于 base scene 中，继承场景才能正确引用。
- **Typed Arrays**：使用 `Array[String]`、`Array[Dictionary]` 等 typed array 避免运行时类型不匹配。
- **Lambda Capture**：GDScript 4 的 lambda 按值捕获，需要用 Dictionary 包装可变状态。
- **Controller 生命周期**：`SaveLoadPanelController` 和 `BacklogPanelController` 通过 `.new()` 实例化，不在场景树中，因此使用 `_ctx.get_tree()` 而非 `get_tree()`。
