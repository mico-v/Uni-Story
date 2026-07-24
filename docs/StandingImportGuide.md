# 立绘（Standing Sprite）导入约定

本文定义 Uni-Story 引擎中角色立绘资源的目录结构、图层命名、导入流程和 StandingProfile 配置规范。

> 最后更新：2026-07-24
> 对应引擎版本：Phase 7+


## 一、目录结构

每个角色在 `resources/Standings/` 下拥有一个独立子目录：

```
resources/Standings/
└── <CharacterName>/         # 推荐使用英文/拼音，大小写敏感
    ├── body.png             # 身体图层（必需）
    ├── hair.png             # 前发图层
    ├── blush.png            # 脸红图层
    ├── sweat.png            # 汗滴/效果图层
    │
    ├── eye_<expr>.png       # 眼睛变体
    │   ├── eye_normal.png   #   普通
    │   ├── eye_smile.png    #   微笑
    │   ├── eye_shock.png    #   震惊
    │   ├── eye_close.png    #   闭眼
    │   ├── eye_divert.png   #   移开视线
    │   ├── eye_down.png     #   向下看
    │   ├── eye_cry.png      #   哭泣
    │   └── eye_squint.png   #   眯眼
    │
    ├── mouth_<expr>.png     # 嘴型变体
    │   ├── mouth_close.png  #   闭合
    │   ├── mouth_open.png   #   张开
    │   ├── mouth_smile.png  #   微笑
    │   ├── mouth_happy.png  #   露齿笑
    │   ├── mouth_close2.png #   闭合变体
    │   └── mouth_open2.png  #   张开变体
    │
    └── eyebrow_<expr>.png   # 眉毛变体
        ├── eyebrow_normal.png  # 普通
        ├── eyebrow_angry.png   # 愤怒
        ├── eyebrow_down.png    # 下垂
        ├── eyebrow_happy.png   # 开心
        ├── eyebrow_side.png    # 一侧上扬
        ├── eyebrow_angry2.png  # 愤怒变体
        └── eyebrow_down2.png   # 下垂变体
```

### 1.1 角色名规则

| 规则 | 示例 |
|------|------|
| 目录名为英文/拼音 | `Ergong`, `Gaotian`, `Qianye`, `Xiben` |
| 大小写敏感 | `Gaotian` ≠ `gaotian` |
| StandingProfile 中 `characters` key 为小写 | `"ergong"`, `"gaotian"` |
| NovaScript 中引用时使用小写 | `show("renna", "gaotian", "normal")` |

### 1.2 图层命名规则

```
<group>_<variant>.png
```

- **group**：`body`、`eye`、`eyebrow`、`mouth`、`hair`、`blush`、`sweat`、`effect`
- **variant**：表情/姿态变体名（不含下划线），如 `normal`、`smile`、`angry`

示例：
- `eye_normal.png` — 普通眼睛
- `mouth_happy.png` — 开心嘴型
- `eyebrow_angry2.png` — 愤怒眉毛变体2


## 二、导入流程

### 2.1 素材准备

1. **透明背景 PNG**：所有图层使用带 Alpha 通道的 PNG 格式
2. **统一画布尺寸**：同一角色的所有图层文件分辨率一致
3. **图层对齐**：所有图层以「身体中心」为锚点，图层间相对位置通过偏移量调节
4. **命名检查**：按上述规则命名，严禁使用空格或特殊字符

### 2.2 放入目录

```
resources/Standings/<CharacterName>/
```

将角色的所有 PNG 图层文件放入对应角色的目录中。

### 2.3 配置 StandingProfile

编辑 `resources/standing_profile.tres`（或作品级覆盖），为角色添加：

```gdscript
characters = {
    "<小写角色名>": {
        "directory": "Standings/<CharacterName>",
        "layer_order": ["body", "blush", "mouth", "eye", "eyebrow", "hair", "sweat", "effect"],
        "poses": {
            "normal": ["body", "mouth_smile", "eye_normal", "eyebrow_normal", "hair"],
            "shock": ["body", "mouth_open", "eye_shock", "eyebrow_angry", "hair"],
            # ... 更多姿态
        },
        "offsets": {
            "body": Vector2(x, y),
            "eye": Vector2(x, y),
            # ... 每个 layer group 的微调偏移
        }
    }
}
```

配置字段说明：

| 字段 | 类型 | 必需 | 说明 |
|------|------|:--:|------|
| `directory` | String | ✅ | 相对于 `resources/` 的目录路径 |
| `layer_order` | Array[String] | ❌ | 图层渲染顺序（从底到顶），覆盖 `default_layer_order` |
| `poses` | Dictionary | ❌ | 预定义姿态，`pose名 → [图层列表]` |
| `offsets` | Dictionary | ❌ | Layer group → 微调偏移（像素），Fine-tune 图层间的相对位置 |

### 2.4 微调偏移

如果某个角色的眼睛位置需要微调，在 `offsets` 中配置：

```gdscript
"offsets": {
    "eye": Vector2(-10, -5),   # 眼睛向左偏移10px，向上偏移5px
    "mouth": Vector2(2, 3),    # 嘴巴向右偏移2px，向下偏移3px
}
```

每个 `layer_group`（如 `body`、`eye`、`eyebrow`、`mouth`、`hair`）可以有独立的偏移量。


## 三、Pose 定义

Pose 是预定义的图层组合，在 NovaScript 中通过 `show()` 的第三个参数引用：

```
# 使用预定义 pose
show("renna", "gaotian", "normal")

# 自由组合图层（用 + 分隔，按 layer_order 排序）
show("renna", "gaotian", "eye_cry+mouth_open+hair")
```

### 3.1 Pose 配置最佳实践

```gdscript
"poses": {
    # 基础姿态
    "normal":   ["body", "mouth_smile", "eye_normal", "eyebrow_normal", "hair"],

    # 情感姿态
    "happy":    ["body", "mouth_happy", "eye_smile", "eyebrow_happy", "hair"],
    "sad":      ["body", "mouth_close", "eye_down", "eyebrow_down", "hair"],
    "angry":    ["body", "mouth_open", "eye_shock", "eyebrow_angry", "hair"],
    "surprise": ["body", "mouth_open2", "eye_shock", "eyebrow_angry2", "hair"],
    "cry":      ["body", "mouth_smile", "eye_cry", "eyebrow_normal", "hair", "sweat"],
}
```

**要点：**
- 每个 pose 至少包含 `body`
- `layer_order` 决定渲染顺序，pose 列表中未出现的 group 将不渲染
- 可以用 `+` 自由组合：`"eye_cry+mouth_open+body"`，引擎自动按 `layer_order` 排序


## 四、Nova 侧对标

### 4.1 与原 Nova (Unity) 的差异

| 项目 | Nova (Unity) | Uni-Story (Godot) |
|------|-------------|-------------------|
| 纹理格式 | Unity Texture2D / Sprite | PNG → Godot Texture2D |
| 图层管理 | C# StandingController | `SpriteComposer` + `StandingProfile` |
| 配置来源 | Lua config / Unity asset | `StandingProfile` Resource (`.tres`) |
| 坐标系统 | 像素 + `.asset` sidecar offset | 像素 offset → `StandingProfile.offsets` |
| 图层定位 | 父子 Transform 层级 | `CompositeSprite` 通过 offset 平移 |
| face 合成 | Nova FaceController (eye + mouth 自动组合) | `StandingProfile` 显式指定图层组合 |

### 4.2 迁移检查清单

从 Nova 工程迁移角色立绘时，确认以下步骤：

- [ ] 将 Unity Texture2D/Sprite 导出为带 Alpha 的 PNG
- [ ] 按 `resources/Standings/<Name>/` 组织目录
- [ ] 图层文件按 `group_variant.png` 规范重命名
- [ ] 在 `standing_profile.tres` 中注册角色
- [ ] 为每个 pose 定义图层组合
- [ ] 如角色立绘位置偏移，在 `offsets` 中微调
- [ ] 通过 headless smoke test 验证：`godot --headless --path . --script res://scripts/tests/sprite_composer_smoke_test.gd`


## 五、工具支持

### 5.1 列出已有角色

```bash
python3 scripts/tools/list_resources.py character --counts-only
```

### 5.2 列出角色所有图层

```bash
python3 scripts/tools/list_resources.py character
```

### 5.3 验证 StandingProfile 配置

```bash
# 通过 sprite composer smoke test 验证
godot --headless --path . --script res://scripts/tests/sprite_composer_smoke_test.gd
```


## 六、完整示例

以角色 "Gaotian" 为例：

**目录结构：**
```
resources/Standings/Gaotian/
├── body.png
├── blush.png
├── eye_close.png
├── eye_cry.png
├── eye_divert.png
├── eye_down.png
├── eye_normal.png
├── eye_shock.png
├── eye_smile.png
├── eyebrow_angry.png
├── eyebrow_down.png
├── eyebrow_down2.png
├── eyebrow_normal.png
├── hair.png
├── mouth_close.png
├── mouth_close2.png
├── mouth_happy.png
├── mouth_open.png
├── mouth_open2.png
├── mouth_smile.png
└── sweat.png
```

**StandingProfile 配置：**
```gdscript
"gaotian": {
    "directory": "Standings/Gaotian",
    "layer_order": ["body", "blush", "mouth", "eye", "eyebrow", "hair", "sweat", "effect"],
    "poses": {
        "normal": ["body", "mouth_smile", "eye_normal", "eyebrow_normal", "hair"],
        "cry": ["body", "mouth_smile", "eye_cry", "eyebrow_normal", "hair"]
    },
    "offsets": {
        "body": Vector2(-8, 246),
        "hair": Vector2(33, -442),
        "eye": Vector2(96, -484),
        "eyebrow": Vector2(114, -538),
        "mouth": Vector2(80, -360),
        "blush": Vector2(50, -504),
        "sweat": Vector2(2, -419)
    }
}
```

**NovaScript 中的使用：**
```
# 预设姿态
show("f-gaotian", "gaotian", "normal")

# 自由组合
show("f-gaotian", "gaotian", "eye_cry+mouth_smile+body+hair")

# 切换表情（复用 body，只换眼睛）
show("f-gaotian", "gaotian", "eye_shock+mouth_open+body+hair")
```
