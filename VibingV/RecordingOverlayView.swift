import SwiftUI
import AppKit

// 录音覆盖层视图 - 显示录音状态和识别结果
struct RecordingOverlayView: View {
    // 使用 ObservedObject 引用单例
    @ObservedObject private var audioManager = AudioRecorderManager.shared
    @State private var isVisible: Bool = false
    
    var body: some View {
        ZStack {
            if isVisible {
                // 背景遮罩
//                Color.black.opacity(0.3)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        // 点击背景不关闭，只能通过快捷键或完成关闭
//                    }
                
                // 录音状态面板 - 居中偏下
                VStack {
                    Spacer()
                    recordingPanel
                        .padding(.bottom, 70) // 距离底部70像素
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) {
                isVisible = true
            }
        }
        .onChange(of: audioManager.recordingState) { [weak audioManager] newState in
            // 识别完成后自动关闭
            guard let _ = audioManager else { return }
            if case .idle = newState {
                hideOverlay()
            }
        }
    }
    
    // 录音面板内容
    @ViewBuilder
    private var recordingPanel: some View {
        switch audioManager.recordingState {
        case .idle:
            EmptyView()
            
        case .recording(let volume, let isTranslating):
            recordingStateView(volume: volume, isTranslating: isTranslating)
            
        case .realtimeRecognizing:
            recordingStateView(volume: audioManager.audioLevel, isTranslating: audioManager.isTranslating)
            
        case .recognizing:
            recognizingView()
            
        case .completed(let text):
            completedView(text: text)
            
        case .error(let message):
            errorView(message: message)
        }
    }
    
    // 录音中视图 - 严格参照截图5
    private func recordingStateView(volume: Double, isTranslating: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // 麦克风图标 - 带动画
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                // 音量指示器 - 波浪动画
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { index in
                        VolumeBar(
                            index: index,
                            volume: volume,
                            isAnimating: true
                        )
                    }
                }
                .frame(height: 30)
                
                // 状态文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(isTranslating ? "录音中 (翻译)" : "录音中...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("按 ⌥ Right Option 停止")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // 实时识别文本显示区
            if !audioManager.recognizedText.isEmpty {
                // 实时识别结果 - 支持多行滚动显示
                ScrollView {
                    HStack(spacing: 8) {
                        Image(systemName: "lasso.badge.sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text(audioManager.recognizedText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 80)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
            } else {
                // 等待识别中
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        .scaleEffect(0.6)
                        .frame(maxWidth: 30)
                    
                    Text("等待语音输入...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity,alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 38)
                .fill(Color(red: 0.18, green: 0.20, blue: 0.25))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .frame(width: 400)
    }
    
    // 识别中视图
    private func recognizingView() -> some View {
        HStack(spacing: 16) {
            // 波形图标 - 带动画
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "waveform")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("识别中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("语音转写即将显示")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 加载动画
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 38)
                .fill(Color(red: 0.18, green: 0.20, blue: 0.25))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .frame(width: 400)
    }
    
    // 完成视图
    private func completedView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 成功图标
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Text("已完成")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Spacer()
            }
            
            // 识别结果
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 38)
                .fill(Color(red: 0.15, green: 0.25, blue: 0.20))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .frame(width: 400)
    }
    
    // 错误视图
    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // 错误图标
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("发生错误")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
                
                Spacer()
            }
            
            // 错误信息
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.25, green: 0.18, blue: 0.15))
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .frame(width: 400)
    }
    
    // 隐藏覆盖层
    private func hideOverlay() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            RecordingOverlayManager.shared.hideOverlay()
        }
    }
}

// 音量条组件 - 带动画效果
struct VolumeBar: View {
    let index: Int
    let volume: Double
    let isAnimating: Bool
    
    @State private var animationOffset: Double = 0
    
    var body: some View {
        let threshold = Double(index) / 10.0
        let isActive = volume > threshold
        
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 28
        
        // 计算波浪效果
        let wavePhase = Double(index) * 0.5
        let animatedVolume = isAnimating && isActive ? min(volume + abs(sin(wavePhase + animationOffset)) * 0.3, 1.0) : (isActive ? volume : 0.1)
        let height = baseHeight + (maxHeight - baseHeight) * CGFloat(animatedVolume)
        
        RoundedRectangle(cornerRadius: 2)
            .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
            .frame(width: 6, height: height)
            .animation(.easeInOut(duration: 0.1), value: animatedVolume)
            .onAppear {
                if isAnimating {
                    withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                        animationOffset = .pi * 2
                    }
                }
            }
    }
}

// 录音覆盖层管理器 - 管理覆盖层的显示和隐藏
class RecordingOverlayManager: ObservableObject {
    static let shared = RecordingOverlayManager()
    
    @Published var isShowing: Bool = false
    
    private var overlayWindow: NSWindow?
    
    // 是否正在处理中（防止重复触发）
    private var isProcessing: Bool = false
    
    // 显示覆盖层
    func showOverlay() {
        print("[RecordingOverlayManager] showOverlay() called, isShowing=\(isShowing), isProcessing=\(isProcessing)")
        
        // 如果状态是 idle，重置 isProcessing 标志（兜底保护）
        if AudioRecorderManager.shared.recordingState == .idle && isProcessing {
            print("[RecordingOverlayManager] state is idle but isProcessing is true, resetting isProcessing")
            isProcessing = false
        }
        
        // 防止重复触发
        guard !isProcessing else {
            print("[RecordingOverlayManager] already processing, returning")
            return
        }
        
        // 如果正在显示，先关闭再重新打开
        if isShowing {
            print("[RecordingOverlayManager] already showing, closing first")
            // 直接关闭窗口，不调用 hideOverlay() 避免重置 AudioRecorderManager 状态
            closeOverlayWindow()
        }
        
        isProcessing = true
        
        // 检查麦克风权限
        let hasPermission = AudioRecorderManager.shared.checkMicrophonePermission()
        print("[RecordingOverlayManager] microphone permission: \(hasPermission)")
        
        if !hasPermission {
            print("[RecordingOverlayManager] requesting microphone permission...")
            // 权限未授权时，不显示 overlay，直接请求授权
            AudioRecorderManager.shared.requestMicrophonePermission { [weak self] granted in
                print("[RecordingOverlayManager] permission callback: granted=\(granted)")
                if granted {
                    print("[RecordingOverlayManager] permission granted, showing overlay")
                    // 权限授予后，重新显示 overlay
                    DispatchQueue.main.async {
                        self?.showOverlayInternal()
                    }
                } else {
                    print("[RecordingOverlayManager] permission denied, not showing overlay")
                    // 权限被拒绝，重置处理标志
                    self?.isProcessing = false
                }
            }
            return
        }
        
        showOverlayInternal()
    }
    
    // 内部方法：显示覆盖层
    private func showOverlayInternal() {
        print("[RecordingOverlayManager] showOverlayInternal() called")
        
        // 确保 AudioRecorderManager 状态是 idle
        if AudioRecorderManager.shared.recordingState != .idle {
            print("[RecordingOverlayManager] AudioRecorderManager state is not idle, resetting first")
            AudioRecorderManager.shared.resetState()
        }
        
        isShowing = true
        print("[RecordingOverlayManager] isShowing set to true")
        
        // 创建覆盖层窗口
        let contentView = RecordingOverlayView()
        print("[RecordingOverlayManager] RecordingOverlayView created")
        
        // 获取主屏幕尺寸
        guard let screen = NSScreen.main else {
            print("[RecordingOverlayManager] no main screen")
            isProcessing = false
            return
        }
        let screenFrame = screen.frame
        print("[RecordingOverlayManager] screen: \(screenFrame)")
        
        // 计算窗口位置 - 水平居中，垂直偏下
        let windowWidth: CGFloat = 420
        let windowHeight: CGFloat = 100
        let bottomPadding: CGFloat = 80 // 距离 Dock 80 像素
        
        let windowRect = NSRect(
            x: (screenFrame.width - windowWidth) / 2,
            y: bottomPadding,
            width: windowWidth,
            height: windowHeight
        )
        print("[RecordingOverlayManager] window rect: \(windowRect)")
        
        // 创建窗口
        overlayWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        print("[RecordingOverlayManager] NSWindow created")
        
        let hostingView = NSHostingView(rootView: contentView)
        overlayWindow?.contentView = hostingView
        overlayWindow?.isOpaque = false
        overlayWindow?.backgroundColor = .clear
        overlayWindow?.level = .floating
        overlayWindow?.ignoresMouseEvents = false
        overlayWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        overlayWindow?.makeKeyAndOrderFront(nil)
        print("[RecordingOverlayManager] window ordered front")
        
        // 开始录音
        print("[RecordingOverlayManager] calling startRealtimeRecognition()")
        AudioRecorderManager.shared.startRealtimeRecognition()
        print("[RecordingOverlayManager] startRealtimeRecognition() called, state=\(AudioRecorderManager.shared.recordingState)")
        
        // 播放开始音效
        SoundPlayer.shared.playStartSound()
        
        // 重置处理标志（允许后续操作）
        isProcessing = false
    }
    
    // 关闭窗口（不重置 AudioRecorderManager 状态）
    private func closeOverlayWindow() {
        print("[RecordingOverlayManager] closeOverlayWindow() called")
        
        // 关闭窗口
        overlayWindow?.orderOut(nil)
        overlayWindow?.contentView = nil
        overlayWindow = nil
        print("[RecordingOverlayManager] window closed")
        
        isShowing = false
        print("[RecordingOverlayManager] isShowing set to false")
    }
    
    // 隐藏覆盖层
    func hideOverlay() {
        print("[RecordingOverlayManager] hideOverlay() called, isShowing=\(isShowing), isProcessing=\(isProcessing)")
        
        // 如果正在处理中，先标记为不处理
        isProcessing = false
        
        guard isShowing else {
            print("[RecordingOverlayManager] not showing, returning")
            return
        }
        
        isShowing = false
        print("[RecordingOverlayManager] isShowing set to false")
        
        // 先关闭窗口
        overlayWindow?.orderOut(nil)
        overlayWindow?.contentView = nil
        overlayWindow = nil
        print("[RecordingOverlayManager] window closed")
        
        // 取消当前的录音/识别
        AudioRecorderManager.shared.cancelRealtimeRecognition()
        print("[RecordingOverlayManager] cancelRealtimeRecognition() called")
    }
    
    // 停止录音并识别
    func stopRecording() {
        let currentState = AudioRecorderManager.shared.recordingState
        print("[RecordingOverlayManager] stopRecording() called, state=\(currentState)")
        
        // 根据当前状态决定如何处理
        switch currentState {
        case .idle:
            // 空闲状态，什么都不做
            print("[RecordingOverlayManager] state is idle, doing nothing")
            break
            
        case .recording(let volume, let isTranslating):
            print("[RecordingOverlayManager] state is recording, calling stopRealtimeRecognition()")
            AudioRecorderManager.shared.stopRealtimeRecognition()
            // 播放结束音效
            SoundPlayer.shared.playStopSound()
            
        case .realtimeRecognizing:
            print("[RecordingOverlayManager] state is realtimeRecognizing, calling stopRealtimeRecognition()")
            AudioRecorderManager.shared.stopRealtimeRecognition()
            // 播放结束音效
            SoundPlayer.shared.playStopSound()
            
        case .recognizing:
            print("[RecordingOverlayManager] state is recognizing, calling cancelRealtimeRecognition()")
            AudioRecorderManager.shared.cancelRealtimeRecognition()
            print("[RecordingOverlayManager] calling hideOverlay()")
            hideOverlay()
            
        case .completed(let text):
            print("[RecordingOverlayManager] state is completed: \(text.prefix(20))...")
            AudioRecorderManager.shared.cancelRealtimeRecognition()
            print("[RecordingOverlayManager] calling hideOverlay()")
            hideOverlay()
            
        case .error(let message):
            print("[RecordingOverlayManager] state is error: \(message)")
            AudioRecorderManager.shared.cancelRealtimeRecognition()
            print("[RecordingOverlayManager] calling hideOverlay()")
            hideOverlay()
        }
    }
    
    // 取消录音
    func cancelRecording() {
        print("[RecordingOverlayManager] cancelRecording() called")
        AudioRecorderManager.shared.cancelRealtimeRecognition()
        print("[RecordingOverlayManager] calling hideOverlay()")
        hideOverlay()
    }
    
    // 切换翻译模式
    func toggleTranslation() {
        print("[RecordingOverlayManager] toggleTranslation() called")
        AudioRecorderManager.shared.isTranslating.toggle()
        if case .recording(let volume, let isTranslating) = AudioRecorderManager.shared.recordingState {
            AudioRecorderManager.shared.recordingState = .recording(volume: volume, isTranslating: !isTranslating)
        }
    }
}

// 预览
struct RecordingOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 1. 录音中状态
            RecordingOverlayView()
                .previewDisplayName("录音中")
                .onAppear {
                    // 模拟录音数据
                    AudioRecorderManager.shared.recordingState = .realtimeRecognizing
                    AudioRecorderManager.shared.audioLevel = 0.6
                }
            
            // 2. 识别中状态
            RecordingOverlayView()
                .previewDisplayName("识别中")
                .onAppear {
                    AudioRecorderManager.shared.recordingState = .recognizing
                }
            
            // 3. 完成状态（带示例文本）
            RecordingOverlayView()
                .previewDisplayName("完成")
                .onAppear {
                    AudioRecorderManager.shared.recordingState = .completed(text: "这是一段测试转写的结果")
                }
        }
        .frame(width: 500, height: 300)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
