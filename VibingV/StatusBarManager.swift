import SwiftUI
import AppKit

class StatusBarManager: NSObject, ObservableObject {
    static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    @Published var isRecordingReady: Bool = true

    // 快捷键管理器
    private var hotkeyManager: HotkeyManager?

    override init() {
        super.init()
        setupStatusBar()
        setupHotkeyManager()
    }

    // 设置快捷键管理器
    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager.shared
    }

    func setupStatusBar() {
        // 创建状态栏图标 - 使用 NSStatusBar 的 system 实例
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            print("Failed to create status bar button")
            return
        }

        // 使用自定义 V 图标
        let icon = createVIcon()
        button.image = icon
        button.image?.size = NSSize(width: 18, height: 18)
        button.imagePosition = .imageLeft

        // 设置点击事件
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // 创建弹出菜单
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 220, height: 140)
        popover?.behavior = .transient
        popover?.animates = true

        let menuView = StatusBarMenuView()
        popover?.contentViewController = NSHostingController(rootView: menuView)

        // 监听点击外部关闭
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let popover = self.popover, popover.isShown else { return }
            self.closePopover()
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // 右键点击也显示菜单
            togglePopover()
        } else {
            // 左键点击
            togglePopover()
        }
    }

    @objc private func togglePopover() {
        guard let popover = popover else { return }

        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }

        // 更新内容
        if let contentViewController = popover?.contentViewController as? NSHostingController<StatusBarMenuView> {
            contentViewController.rootView = StatusBarMenuView()
        }

        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover() {
        popover?.performClose(nil)
    }

    // 创建 V 图标
    private func createVIcon() -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)

        image.lockFocus()

        // 绘制背景 - 圆角矩形
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
        NSColor.black.setFill()
        path.fill()

        // 绘制 V 字 - 使用斜体
        let font = NSFont.systemFont(ofSize: 13, weight: .bold)
        let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: italicFont,
            .foregroundColor: NSColor.white
        ]

        let text = "V"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        text.draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = false

        return image
    }

    // 打开主窗口
    func openMainWindow() {
        closePopover()

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            // 查找或创建主窗口
            if let window = NSApp.windows.first(where: { $0.title.contains("Vibing") || $0.isKeyWindow }) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    // 退出应用
    func quitApp() {
        closePopover()
        NSApp.terminate(nil)
    }
}

// 状态栏菜单视图
struct StatusBarMenuView: View {
    @StateObject private var manager = StatusBarManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            HStack(spacing: 8) {
                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)

                Text("VibingV")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // 状态指示
            HStack(spacing: 6) {
                Circle()
                    .fill(manager.isRecordingReady ? Color.green : Color.red)
                    .frame(width: 6, height: 6)

                Text(manager.isRecordingReady ? "准备开始录音" : "录音中...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 8)

            // 设置按钮
            Button(action: {
                StatusBarManager.shared.openMainWindow()
            }) {
                HStack {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                    Text("设置")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘,")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // 退出按钮
            Button(action: {
                StatusBarManager.shared.quitApp()
            }) {
                HStack {
                    Text("退出")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘Q")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// 👇 加这一行，立刻有预览
#Preview {
    StatusBarMenuView()
}
