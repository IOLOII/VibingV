import Foundation
import AppKit

// 快捷键管理器 - 处理全局快捷键监听
class HotkeyManager: NSObject {
    static let shared = HotkeyManager()

    // 事件监听器
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    // 按键码定义
    private let kVK_RightOption: UInt16 = 61
    private let kVK_Escape: UInt16 = 53
    private let kVK_Slash: UInt16 = 44

    override init() {
        super.init()
        setupMonitors()
    }

    deinit {
        removeMonitors()
    }

    // 设置监听器
    private func setupMonitors() {
        // 本地监听器（应用激活时）- 用于检测修饰键变化
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        // 全局监听器（应用未激活时）- 用于检测修饰键变化
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // 添加按键监听器用于 Esc 和 Option+/
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event)
        }
    }

    // 移除监听器
    private func removeMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // 处理修饰键变化（用于检测 Right Option）
    private func handleFlagsChanged(_ event: NSEvent) {
        // keyCode 61 是 Right Option
        if event.keyCode == kVK_RightOption {
            // 检测 Right Option 从按下到释放的完整周期
            if event.modifierFlags.contains(.option) {
                // 按下状态
                // 不在这里处理，等待释放
            } else {
                // 释放状态 - 切换录音状态
                print("Right Option 点击 detected")
                toggleRecording()
            }
        }
    }

    // 处理按键按下
    private func handleKeyDown(_ event: NSEvent) {
        // 检测 Esc 键 (keyCode 53)
        if event.keyCode == kVK_Escape {
            handleEscapeKey()
            return
        }

        // 检测 / 键 (keyCode 44) + Option
        if event.keyCode == kVK_Slash && event.modifierFlags.contains(.option) {
            handleTranslateShortcut()
            return
        }
    }

    // 处理 Esc 键
    private func handleEscapeKey() {
        print("Esc 键按下")
        if RecordingOverlayManager.shared.isShowing {
            RecordingOverlayManager.shared.cancelRecording()
        }
    }

    // 处理翻译快捷键
    private func handleTranslateShortcut() {
        print("Option + / 按下")
        if RecordingOverlayManager.shared.isShowing {
            RecordingOverlayManager.shared.toggleTranslation()
        }
    }

    // 切换录音状态
    private func toggleRecording() {
        if RecordingOverlayManager.shared.isShowing {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // 开始录音
    private func startRecording() {
        print("开始录音")
        RecordingOverlayManager.shared.showOverlay()
    }

    // 停止录音
    private func stopRecording() {
        print("停止录音")
        RecordingOverlayManager.shared.stopRecording()
    }
}

// 辅助功能：检查辅助功能权限
extension HotkeyManager {
    // 检查是否已获得辅助功能权限
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessibilityEnabled
    }

    // 请求辅助功能权限
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // 显示权限提示
    func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "VibingV 需要辅助功能权限来监听全局快捷键。请在系统设置中授予权限。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开辅助功能设置
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
