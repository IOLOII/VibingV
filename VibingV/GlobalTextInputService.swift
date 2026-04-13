import Foundation
import AppKit
import Carbon

// MARK: - 全局文本输入服务

/// 全局文本输入服务 - 跨应用文本填充
/// 使用 CGEvent 模拟键盘事件将文本输入到当前焦点位置
class GlobalTextInputService {
    static let shared = GlobalTextInputService()

    // 原始剪贴板字符串内容
    private var savedString: String?

    private init() {}

    // MARK: - 公开方法

    /// 将文本输入到当前光标位置（跨应用）
    /// - Parameters:
    ///   - text: 要输入的文本
    ///   - autoRestoreClipboard: 是否自动恢复原始剪贴板内容（默认 true）
    ///   - completion: 输入完成后的回调
    func inputText(_ text: String, autoRestoreClipboard: Bool = true, completion: (() -> Void)? = nil) {
        print("[GlobalTextInput] inputText() called with text: \(text.prefix(50))...")

        // 0. 先检查辅助功能权限状态
        var hasAccessibility = AXIsProcessTrusted()
        print("[GlobalTextInput] Initial accessibility check: \(hasAccessibility)")
        print("[GlobalTextInput] Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("[GlobalTextInput] App path: \(Bundle.main.bundlePath)")

        if !hasAccessibility {
            // 尝试请求权限（会弹出系统对话框让用户授权）
            print("[GlobalTextInput] Requesting accessibility permission...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            hasAccessibility = AXIsProcessTrustedWithOptions(options)
            print("[GlobalTextInput] After requesting, accessibility: \(hasAccessibility)")
        }

        // 等待一下让权限更新
        Thread.sleep(forTimeInterval: 0.5)
        hasAccessibility = AXIsProcessTrusted()
        print("[GlobalTextInput] Final accessibility check: \(hasAccessibility)")

        if !hasAccessibility {
            print("[GlobalTextInput] No accessibility permission!")
        } else {
            print("[GlobalTextInput] Accessibility permission granted!")
        }

        // 1. 保存当前剪贴板内容
        savePasteboard()

        // 2. 将文本复制到剪贴板
        copyToPasteboard(text)

        // 3. 延迟模拟粘贴（不隐藏 overlay，因为 overlay 的显示和隐藏由 AudioRecorderManager 单独管理）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            print("[GlobalTextInput] Simulating paste...")
            self.simulatePaste()

            // 5. 延迟恢复原始剪贴板内容
            if autoRestoreClipboard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self = self else { return }
                    print("[GlobalTextInput] Restoring clipboard...")
                    self.restorePasteboard()
                    print("[GlobalTextInput] inputText completed")
                    completion?()
                }
            } else {
                print("[GlobalTextInput] inputText completed (no restore)")
                completion?()
            }
        }
    }

    /// 直接输入文本（不依赖剪贴板）- 使用 Unicode 输入
    /// - Parameters:
    ///   - text: 要输入的文本
    ///   - completion: 输入完成后的回调
    func inputTextDirectly(_ text: String, completion: (() -> Void)? = nil) {
        // 使用 CGEvent 模拟键盘事件输入每个字符
        DispatchQueue.global(qos: .userInitiated).async {
            for character in text {
                self.inputCharacter(String(character))
                // 添加小延迟避免输入过快
                Thread.sleep(forTimeInterval: 0.01)
            }

            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    // MARK: - 私有方法

    /// 保存当前剪贴板内容
    private func savePasteboard() {
        let pasteboard = NSPasteboard.general
        // 只保存字符串类型，这是最常见的剪贴板内容
        // NSPasteboardItem 的 copyWithZone: 可能不可用，所以使用数据存储
        savedString = pasteboard.string(forType: .string)
        print("[GlobalTextInput] 剪贴板内容已保存: \(savedString?.prefix(50) ?? "nil")...")
    }

    /// 恢复原始剪贴板内容
    private func restorePasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let savedStr = savedString {
            pasteboard.setString(savedStr, forType: .string)
            print("[GlobalTextInput] 剪贴板内容已恢复: \(savedStr.prefix(50))...")
        }
        savedString = nil
    }

    /// 复制文本到剪贴板
    private func copyToPasteboard(_ text: String) {
        print("[GlobalTextInput] copyToPasteboard() 开始, text: \(text.prefix(100))...")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("[GlobalTextInput] copyToPasteboard() 完成, success: \(success), stringLength: \(text.count)")
    }

    /// 模拟 Cmd+V 粘贴
    private func simulatePaste() {
        print("[GlobalTextInput] simulatePaste() 开始")
        
        // 创建 key down event
        let source = CGEventSource(stateID: .hidSystemState)
        print("[GlobalTextInput] CGEventSource 创建成功, source: \(source)")
        
        // V 键的 keyCode 是 9
        let vKeyCode: CGKeyCode = 9
        print("[GlobalTextInput] V 键 keyCode: \(vKeyCode)")

        // 创建 key down event (Command+V)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            print("[GlobalTextInput] keyDown event 创建成功, flags: \(keyDown.flags)")
            keyDown.post(tap: .cghidEventTap)
            print("[GlobalTextInput] keyDown event 已发送")
        } else {
            print("[GlobalTextInput] ERROR: keyDown event 创建失败!")
        }

        // 创建 key up event
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            print("[GlobalTextInput] keyUp event 创建成功, flags: \(keyUp.flags)")
            keyUp.post(tap: .cghidEventTap)
            print("[GlobalTextInput] keyUp event 已发送")
        } else {
            print("[GlobalTextInput] ERROR: keyUp event 创建失败!")
        }

        print("[GlobalTextInput] simulatePaste() 完成")
    }

    /// 输入单个字符
    private func inputCharacter(_ character: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        // 将字符转换为 Unicode 码点
        guard let unicodeScalar = character.unicodeScalars.first else { return }
        let scalarValue = unicodeScalar.value

        // 使用 CGEventKeyboardSetUnicodeString 输入字符
        var unichar = UniChar(scalarValue)
        let length = 1

        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            event.keyboardSetUnicodeString(stringLength: length, unicodeString: &unichar)
            event.post(tap: .cghidEventTap)
        }

        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            event.post(tap: .cghidEventTap)
        }
    }
}
