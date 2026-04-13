import SwiftUI
import AppKit
import ApplicationServices
import AVFoundation

@main
struct VibingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 应用保存的外观设置
                    SettingsStore.shared.applyAppearance()
                }
        }
        .windowStyle(DefaultWindowStyle())
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 VibingV") {
                    // 显示关于窗口
                }
            }
        }
    }
}

// AppDelegate 用于设置状态栏
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager: StatusBarManager?
    var hotkeyManager: HotkeyManager?

    // 权限检查定时器
    var permissionCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化状态栏
        statusBarManager = StatusBarManager.shared

        // 初始化快捷键管理器
        hotkeyManager = HotkeyManager.shared

        // 步骤 1: 检查并请求辅助功能权限
        // 显示系统授权对话框，对话框会自动将应用添加到辅助功能列表
        requestAccessibilityPermissionsIfNeeded()
    }

    /// 检查并请求辅助功能权限（如果需要）
    /// 使用 AXIsProcessTrustedWithOptions(prompt: true) 直接显示系统授权对话框
    /// 对话框会自动将应用添加到辅助功能列表
    private func requestAccessibilityPermissionsIfNeeded() {
        // 使用 prompt: false 先检查权限状态
        let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(checkOptions)

        if isTrusted {
            print("[AppDelegate] 辅助功能权限已授权")
            // 辅助功能权限已授权，开始检查麦克风权限
            checkMicrophonePermission()
            return
        }

        print("[AppDelegate] 辅助功能权限未授权，显示系统授权对话框...")

        // 使用 prompt: true 显示系统授权对话框
        // 系统对话框会自动将应用添加到「系统设置 > 隐私与安全性 > 辅助功能」列表
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(promptOptions)

        // 启动定时器，定期检查辅助功能权限是否已授权
        // 一旦授权，立即检查麦克风权限
        startPermissionCheckTimer()
    }

    /// 启动定时器，定期检查辅助功能权限状态
    private func startPermissionCheckTimer() {
        // 每 0.5 秒检查一次辅助功能权限
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
            let isTrusted = AXIsProcessTrustedWithOptions(checkOptions)

            if isTrusted {
                print("[AppDelegate] 用户已完成辅助功能授权")
                // 停止定时器
                timer.invalidate()
                self?.permissionCheckTimer = nil
                // 开始检查麦克风权限
                self?.checkMicrophonePermission()
            }
        }
    }

    /// 检查并请求麦克风权限
    /// 使用 AVCaptureDevice.requestAccess(for:) 请求麦克风权限
    private func checkMicrophonePermission() {
        // 先检查当前麦克风权限状态
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("[AppDelegate] 麦克风权限已授权")
        case .notDetermined:
            print("[AppDelegate] 麦克风权限未决定，请求授权...")
            // 请求麦克风权限，会显示系统对话框
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("[AppDelegate] 用户已授权麦克风权限")
                    } else {
                        print("[AppDelegate] 用户拒绝麦克风权限")
                    }
                }
            }
        case .denied:
            print("[AppDelegate] 麦克风权限被拒绝")
        case .restricted:
            print("[AppDelegate] 麦克风权限受限")
        @unknown default:
            print("[AppDelegate] 麦克风权限状态未知")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭最后一个窗口时不退出应用，保持状态栏运行
        return false
    }
}
