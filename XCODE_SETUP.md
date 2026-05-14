# Xcode 项目创建步骤

由于 Xcode 项目文件（`.xcodeproj`）包含复杂的配置（签名、entitlements、部署目标），建议用 Xcode GUI 创建：

## 步骤

### 1. 打开 Xcode，创建新项目

```
File → New → Project...
```

选择：
- **Platform**: macOS
- **Template**: App
- **Product Name**: SwiftSnap
- **Team**: 你的开发者账号（或 None）
- **Organization Identifier**: com.yourname
- **Interface**: SwiftUI
- **Language**: Swift
- **Storage**: None (不需要 Core Data)
- **Include Tests**: 可选

### 2. 配置项目设置

在项目设置中：

#### General
- **Minimum Deployments**: macOS 13.0

#### Signing & Capabilities
- **App Sandbox**: ❌ 关闭（需要 Accessibility 权限，Sandbox 会阻止）
- **Hardened Runtime**: ❌ 关闭（或配置例外）
- **Privacy**: 添加以下权限描述：
  - `NSAccessibilityUsageDescription`: "SwiftSnap needs Accessibility permission to detect double-tap Option key for quick screenshots."
  - `NSScreenCaptureUsageDescription`: "SwiftSnap needs Screen Recording permission to capture screenshots."

### 3. 删除自动生成的文件，替换为已有代码

删除 Xcode 自动生成的：
- `SwiftSnapApp.swift`（ContentView.swift 等）

复制已有代码：
```bash
# 复制代码文件
cp ~/claude/dev/swiftsnap/SwiftSnap/Services/*.swift <Xcode项目目录>/SwiftSnap/Services/
cp ~/claude/dev/swiftsnap/SwiftSnap/SwiftSnapApp.swift <Xcode项目目录>/SwiftSnap/
```

### 4. 配置 Info.plist

添加权限描述：

```xml
<key>NSAccessibilityUsageDescription</key>
<string>SwiftSnap needs Accessibility permission to detect double-tap Option key for quick screenshots.</string>

<key>NSScreenCaptureUsageDescription</key>
<string>SwiftSnap needs Screen Recording permission to capture screenshots.</string>
```

### 5. Build & Run

```
Product → Build (Cmd+B)
Product → Run (Cmd+R)
```

首次运行时，系统会提示：
1. Accessibility 权限 — 点击"允许"
2. Screen Recording 权限 — 点击"允许"

### 6. 测试双击 Option

如果一切正常：
- 双击 Option 键
- 截图会保存到 Desktop (`SpikeScreenshot_TIMESTAMP.png`)
- 截图会复制到剪贴板

---

## 快捷方式：直接用现有目录

如果你想直接在 `~/claude/dev/swiftsnap` 目录创建 Xcode 项目：

```bash
# 打开 Xcode
open -a Xcode ~/claude/dev/swiftsnap
```

然后在 Xcode 中：
1. 右键点击项目导航器空白处
2. "Add Files to..."
3. 添加所有 Swift 文件

---

## 如果遇到问题

### Accessibility 权限不弹出
- 检查 `NSAccessibilityUsageDescription` 是否添加
- 手动开启：系统设置 → 隐私与安全 → 辅助功能 → 添加 SwiftSnap

### ScreenCaptureKit 错误
- 确保 macOS 13+ (Ventura)
- 确保 Screen Recording 权限已授予

### 编译错误
- 确保导入正确：`import ScreenCaptureKit`, `import Carbon`
- 确保 deployment target 是 macOS 13.0

---

## 下一步

技术验证成功后，可以：
1. 实现区域选择 UI（overlay + 拖拽）
2. 实现标注功能
3. 实现贴图窗口