import Foundation
import AppKit
import Combine

// MARK: - 焦点文本框监控服务

/// 监控当前焦点文本框的服务
/// 用于在语音识别完成后自动填充文本到当前焦点的文本输入框
class FocusedTextFieldMonitor: ObservableObject {
    static let shared = FocusedTextFieldMonitor()
    
    // MARK: - Published 属性
    @Published private(set) var currentTextField: NSView?
    @Published private(set) var isTextFieldFocused: Bool = false
    
    // MARK: - 私有属性
    private var cancellables = Set<AnyCancellable>()
    
    // 存储当前焦点的文本框
    private var trackedTextField: NSTextField?
    
    // MARK: - 初始化
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - 公开方法
    
    /// 获取当前焦点的文本内容（如果存在）
    var currentText: String? {
        return trackedTextField?.stringValue
    }
    
    /// 设置焦点文本框的文本内容
    /// - Parameter text: 要设置的文本
    /// - Returns: 是否设置成功
    @discardableResult
    func setFocusedTextField(_ text: String) -> Bool {
        guard let textField = trackedTextField else {
            print("[FocusedTextFieldMonitor] 没有活跃的文本输入框")
            return false
        }
        
        textField.stringValue = text
        print("[FocusedTextFieldMonitor] 已填充文本到焦点文本框: \(text.prefix(20))...")
        return true
    }
    
    /// 插入文本到当前焦点位置（在现有文本后追加）
    /// - Parameter text: 要插入的文本
    /// - Returns: 是否插入成功
    @discardableResult
    func insertText(_ text: String) -> Bool {
        guard let textField = trackedTextField else {
            print("[FocusedTextFieldMonitor] 没有活跃的文本输入框")
            return false
        }
        
        textField.stringValue += text
        return true
    }
    
    /// 检查当前是否有可编辑的文本输入框
    var hasEditableTextField: Bool {
        return trackedTextField != nil && trackedTextField!.isEditable && trackedTextField!.isEnabled
    }
    
    // MARK: - 私有方法
    
    /// 设置监控
    private func setupMonitoring() {
        // 使用定时器轮询当前焦点状态
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateFocusedTextField()
        }
        
        // 监听窗口成为关键窗口
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { [weak self] _ in
                self?.updateFocusedTextField()
            }
            .store(in: &cancellables)
        
        // 监听应用成为活跃应用
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateFocusedTextField()
            }
            .store(in: &cancellables)
        
        // 监听窗口 resign key（失去焦点）
        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
            .sink { [weak self] notification in
                if let window = notification.object as? NSWindow, window == NSApp.keyWindow {
                    self?.clearFocus()
                }
            }
            .store(in: &cancellables)
        
        // 初始更新
        updateFocusedTextField()
    }
    
    /// 更新当前焦点文本框
    private func updateFocusedTextField() {
        DispatchQueue.main.async { [weak self] in
            self?.performUpdateFocusedTextField()
        }
    }
    
    private func performUpdateFocusedTextField() {
        // 获取当前窗口的 firstResponder
        guard let window = NSApp.keyWindow else {
            if trackedTextField != nil {
                clearFocus()
            }
            return
        }
        
        guard let firstResponder = window.firstResponder else {
            if trackedTextField != nil {
                clearFocus()
            }
            return
        }
        
        // 检查 firstResponder 是否是 NSTextField
        if let textField = firstResponder as? NSTextField {
            if textField.isEditable && textField.isEnabled && !textField.isHidden {
                if trackedTextField?.hashValue != textField.hashValue {
                    print("[FocusedTextFieldMonitor] 检测到焦点文本框: \(textField.identifier?.rawValue ?? "未命名")")
                }
                trackedTextField = textField
                currentTextField = textField
                isTextFieldFocused = true
                return
            }
        }
        
        // 如果 firstResponder 是 NSView，尝试在父视图链中查找文本框
        if let view = firstResponder as? NSView {
            let textField = findTextField(in: view)
            if let textField = textField, textField.isEditable && textField.isEnabled && !textField.isHidden {
                if trackedTextField?.hashValue != textField.hashValue {
                    print("[FocusedTextFieldMonitor] 检测到焦点文本框 (父视图): \(textField.identifier?.rawValue ?? "未命名")")
                }
                trackedTextField = textField
                currentTextField = textField
                isTextFieldFocused = true
                return
            }
        }
        
        // 没有找到有效的文本输入框
        if trackedTextField != nil {
            clearFocus()
        }
    }
    
    /// 在指定视图的父视图链中查找文本框
    private func findTextField(in view: NSView) -> NSTextField? {
        var currentView: NSView? = view
        
        while let v = currentView {
            if let textField = v as? NSTextField {
                return textField
            }
            currentView = v.superview
        }
        
        return nil
    }
    
    /// 清除焦点状态
    private func clearFocus() {
        if trackedTextField != nil {
            print("[FocusedTextFieldMonitor] 清除焦点文本框")
        }
        trackedTextField = nil
        currentTextField = nil
        isTextFieldFocused = false
    }
}

// MARK: - NSTextField 扩展

extension NSTextField {
    /// 检查是否是有效的文本输入框
    var isValidTextInput: Bool {
        return isEditable && isEnabled && !isHidden
    }
}
