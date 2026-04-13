# macOS 权限授权指南

本文档介绍 macOS 中与本项目相关的权限授权机制，包括辅助功能（Accessibility）和事件监控（Event Monitoring）的区别。

## 概述

本项目涉及以下 macOS 权限：

| 权限类型 | 用途 | 触发场景 |
|---------|------|---------|
| 辅助功能 (Accessibility) | CGEvent 键盘模拟 | 模拟 Cmd+V 粘贴 |
| 事件监控 (Event Monitoring) | NSEvent 全局监听 | 监听全局快捷键 |
| 麦克风 (Microphone) | 音频录制 | 语音识别录音 |

## 辅助功能权限 (Accessibility)

### 用途
用于通过 `CGEvent` 模拟键盘和鼠标事件，实现跨应用的文本输入功能。

### 相关 API

#### 1. `AXIsProcessTrusted()` 
**检查权限是否已授予（不触发对话框）**

```swift
let hasPermission = AXIsProcessTrusted()
// 返回 true 表示已授权，false 表示未授权
```

#### 2. `AXIsProcessTrustedWithOptions(options)`
**检查权限，可选择是否显示系统授权对话框**

```swift
// 选项 1: 不显示对话框，只检查权限状态
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
let hasPermission = AXIsProcessTrustedWithOptions(options)

// 选项 2: 显示系统授权对话框
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
let hasPermission = AXIsProcessTrustedWithOptions(options)
```

### 关键行为 ⚠️

**当 `prompt: true` 时：**
- 如果应用**尚未**在辅助功能列表中，系统会显示授权对话框
- **对话框会自动将应用添加到「系统设置 > 隐私与安全性 > 辅助功能」列表中**
- 用户点击"允许"后，权限被授予
- 权限存储在 TCC 数据库中，基于应用的**代码签名**

**当 `prompt: false` 时：**
- 只检查权限状态，不显示任何对话框
- 如果未授权，返回 `false`

### TCC 数据库与代码签名

TCC (Transparency, Consent, and Control) 数据库根据**代码签名**存储权限。从 Xcode Debug 运行时：
- 代码签名是临时的（ad-hoc signing）
- 路径可能是 `~/Library/Developer/Xcode/DerivedData/...`
- 与正式安装的 `/Applications/VibingV.app` 不同

**这意味着：**
1. 从 Xcode 运行并授权后
2. 重新构建（代码签名可能变化）
3. TCC 可能找不到对应的权限记录

**解决方案：**
- 将应用安装到 `/Applications` 后运行
- 或使用有效的开发者证书签名

## 事件监控权限 (Event Monitoring)

### 用途
用于通过 `NSEvent.addGlobalMonitorForEvents()` 监听全局键盘和鼠标事件，实现全局快捷键。

### 相关 API

```swift
// 添加全局事件监听器
let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
    // 处理事件
}

// 添加本地事件监听器（仅当前应用）
let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
    // 处理事件
}
```

### 权限触发机制

**重要：** `NSEvent.addGlobalMonitorForEvents` 本身不会主动显示授权对话框。

权限触发发生在：
1. 应用尝试使用事件监控功能时
2. macOS 检测到需要授权时

当需要授权时，系统会显示对话框询问用户是否允许。

### 权限位置

事件监控权限位于：**系统设置 > 隐私与安全性 > 输入监控**

## 辅助功能 vs 事件监控

| 特性 | 辅助功能 | 事件监控 |
|------|---------|---------|
| API | `AXIsProcessTrusted*` | `NSEvent.add*Monitor*` |
| 用途 | 模拟键盘/鼠标事件 | 监听键盘/鼠标事件 |
| 权限位置 | 辅助功能 | 输入监控 |
| 对话框自动添加 | ✅ 是 | ✅ 是 |
| TCC 存储 | ✅ 是 | ✅ 是 |

## 权限请求最佳实践

### 1. 应用启动时请求（推荐）

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // 检查权限
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    let hasPermission = AXIsProcessTrustedWithOptions(options)
    
    if !hasPermission {
        // 显示自定义提示，询问用户是否前往授权
        showPermissionAlert()
    }
}
```

### 2. 尝试使用功能前请求

```swift
func someFunction() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    guard AXIsProcessTrustedWithOptions(options) else {
        // 显示系统授权对话框
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(promptOptions)
        return
    }
    
    // 执行需要权限的操作
    performAction()
}
```

### 3. 使用前检查 + 延迟请求

```swift
func inputText(_ text: String) {
    // 立即检查
    if !AXIsProcessTrusted() {
        // 异步请求权限（不会立即阻塞）
        DispatchQueue.main.async {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return
    }
    
    // 执行输入
    simulateKeyEvent(text)
}
```

## 常见问题

### Q: 为什么 `AXIsProcessTrustedWithOptions(prompt: true)` 没有显示对话框？

可能原因：
1. 应用已在辅助功能列表中且已授权
2. 权限检查被系统缓存（尝试完全退出应用后重试）
3. 代码签名问题（从 Xcode 运行与从 /Applications 运行不同）

### Q: 如何清除 TCC 缓存？

```bash
# 重置辅助功能权限
tccutil reset Accessibility

# 重置所有权限
tccutil reset All
```

### Q: 如何检查 TCC 数据库中的记录？

```bash
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT client, auth_value FROM access WHERE service='kTCCServiceAccessibility'"
```

## 参考资料

- [Apple Developer Documentation - AXIsProcessTrusted](https://developer.apple.com/documentation/applicationservices/1453502-axisprocesstrusted)
- [macOS Security - Transparency, Consent, and Control](https://www.apple.com/business/docs/site/macOS_Security_Overview.pdf)
- [Input Monitoring and Privacy](https://developer.apple.com/documentation/appkit/nsevent/1535471-addglobalmonitorforevents)
