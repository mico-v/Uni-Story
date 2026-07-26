# Uni-Story 发布指南

> 目标：从源代码构建、导出并在 Windows/Linux/Android 上发布 Uni-Story 视觉小说游戏。  
> 最后更新：2026-07-26（Phase 18）

---

## 一、导出前置检查

在导出之前，确保通过以下质量门禁：

### 1.1 剧本静态检查

```bash
python scripts/tools/scenario_lint.py
```

要求：`errors=0`。warnings 不阻断发布，但建议 review 所有 warning。

### 1.2 Headless 测试套件

```bash
# 先导入项目资源
godot --headless --path . --import

# 运行全量测试
python scripts/tests/run_headless_suite.py --godot godot --timeout 180
```

要求：所有测试通过，零失败。

### 1.3 资源完整性验证

```bash
# 扫描资源引用
python scripts/tools/list_resources.py

# 检查 BGM/BG 完整性
python scripts/tools/list_bg.py --details
python scripts/tools/list_bgm.py --details

# 检查本地化资源映射
python scripts/tools/generate_localized_paths.py
```

---

## 二、导出配置

### 2.1 Windows

- **预设名**: `Windows Desktop`
- **输出**: `.exe` + `.pck`
- **架构**: x86_64
- **模板**: 需要 Godot 4.6 Windows Desktop 导出模板

```bash
godot --headless --path . --export-release "Windows Desktop" ./build/windows/Uni-Story.exe
```

**注意事项**：
- 确保 Godot 编辑器中已安装 Windows 导出模板
- `.pck` 文件与 `.exe` 放在同一目录
- 签名（可选）：使用 `signtool` 对 `.exe` 进行数字签名

### 2.2 Linux

- **预设名**: `Linux/X11`
- **输出**: `.x86_64` 二进制
- **架构**: x86_64

```bash
godot --headless --path . --export-release "Linux/X11" ./build/linux/Uni-Story.x86_64
```

**注意事项**：
- 需要 Godot 4.6 Linux/X11 导出模板
- 二进制需要可执行权限：`chmod +x Uni-Story.x86_64`
- AppImage 打包可选

### 2.3 Android

- **预设名**: `Android`
- **输出**: `.apk` 或 `.aab`
- **架构**: arm64 + armv7（双架构）

```bash
godot --headless --path . --export-release "Android" ./build/android/Uni-Story.apk
```

**前置条件**：
1. 安装 Android SDK (API 33+) 和 NDK
2. 配置 `ANDROID_HOME` 环境变量
3. 创建 `android/` 目录（Godot 自动生成）
4. 配置 keystore：
   ```bash
   keytool -genkey -v -keystore uni-story.keystore -alias uni-story -keyalg RSA -keysize 2048 -validity 36500
   ```

**注意事项**：
- 在 Godot 编辑器的 `Editor → Editor Settings → Export → Android` 中配置 SDK 路径
- 导出预设中配置 JDK 路径（JDK 17+）
- 签名密钥务必安全保存，丢失无法更新应用
- `.aab` 格式用于 Google Play，`.apk` 用于直接分发

---

## 三、一键构建（CI/CD）

项目已包含 CI 流水线（`.cnb.yml`），运行以下步骤：

1. **Lint 门禁**：`scenario_lint.py` → errors=0
2. **测试门禁**：全量 headless 测试通过
3. **导出**：并行导出 Windows/Linux/Android
4. **产出物**：在 Release 页面下载

你也可以通过 Editor 的 **Build Panel**（`UniStory Editor Suite` 插件）一键触发。

---

## 四、平台注意事项

### 4.1 Windows

- 最低系统：Windows 10 (64-bit)
- 依赖：Visual C++ Redistributable 2015+（通常已预装）
- 杀毒软件可能误报：首次启动时建议添加白名单

### 4.2 Linux

- 最低系统：Ubuntu 20.04+ 或等效发行版
- 依赖：`libstdc++6`、`libc6`（通常已预装）
- X11 或 Wayland 兼容

### 4.3 Android

- 最低 API Level：24（Android 7.0）
- 目标 API Level：34（Android 14）
- 屏幕：强制横屏（`export_presets.cfg` 已配置）
- 权限：无需特殊权限（纯单机游戏）

### 4.4 共用

- 所有平台均使用相同的 `export_presets.cfg` 配置
- 资源不区分平台，通过 `.godot/imported/` 按平台导入
- 存档位置：Godot `user://` 路径（各平台有默认位置）

---

## 五、发布检查清单

- [ ] 剧本 lint `errors=0`
- [ ] headless 测试全部通过
- [ ] `shaderproto_gen.py --all` 生成正常
- [ ] I18n 本地化文件完整（zh.json + en.json）
- [ ] 字体字符集已生成（`generate_charsets.py --generate-files`）
- [ ] Windows `.exe` 启动无崩溃
- [ ] Windows 存档/读档正常
- [ ] Linux 二进制启动无崩溃
- [ ] Linux 存档/读档正常
- [ ] Android 横屏适配正确
- [ ] Android 触控操作流畅
- [ ] 所有场景（ch1-ch4）可完整播放
- [ ] 中英文切换正常
- [ ] CHANGELOG 已更新
- [ ] 版本号已更新（`export_presets.cfg` + `project.godot`）

---

## 六、常见问题

### Q: 导出的 .exe 双击无反应？
A: 检查是否有 `.pck` 文件在同一目录，以及是否缺少 VC++ Redistributable。

### Q: Android APK 安装失败？
A: 检查签名是否正确、最低 API 版本是否匹配、架构是否支持。

### Q: 字体显示异常？
A: 运行 `python scripts/tools/generate_charsets.py --generate-files` 确保字符集完整。

### Q: CG/立绘不显示？
A: 运行 `python scripts/tools/list_bg.py --details` 检查资源文件是否存在。

---

## 七、参考文档

| 文档 | 用途 |
|------|------|
| `Setup.md` | 开发环境搭建 |
| `PLAN.md` | 路线图和开发计划 |
| `docs/NovaScript.md` | 剧本语法完整参考 |
| `docs/StandingImportGuide.md` | 立绘导入教程 |
| `docs/DeviceTestChecklist.md` | 三平台设备测试清单 |
| `docs/CodingStandards.md` | 编码规范 |
| `docs/ProjectTerms.md` | 术语表 |
