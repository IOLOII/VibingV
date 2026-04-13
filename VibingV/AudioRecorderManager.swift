import Foundation
import AVFoundation
import AppKit
import Combine

// MARK: - 录音状态枚举

/// 录音管理器状态
enum RecordingState: Equatable {
    case idle                           // 空闲状态
    case recording(volume: Double, isTranslating: Bool)  // 录音中
    case realtimeRecognizing            // 实时语音识别中
    case recognizing                    // 识别中
    case completed(text: String)        // 识别完成
    case error(message: String)         // 错误状态
}

// MARK: - 录音管理器

/// 录音管理器 - 处理音频录制和实时语音识别
/// 
/// 协调 FunASRWebSocketService 进行实时语音识别
class AudioRecorderManager: NSObject, ObservableObject {
    static let shared = AudioRecorderManager()
    
    // MARK: - Published 属性 (UI 绑定)
    @Published var recordingState: RecordingState = .idle
    @Published var isRecording: Bool = false
    @Published var isTranslating: Bool = false
    @Published var recognizedText: String = ""
    @Published var audioLevel: Double = 0.0
    
    // MARK: - 私有属性
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // Fun-ASR WebSocket 服务
    private let funASRService = FunASRWebSocketService.shared
    
    // 音量监测定时器
    private var levelTimer: Timer?
    
    // 是否应该保持弹窗显示
    private var shouldKeepOverlay = false
    
    // 录音开始时间
    private var recordingStartTime: Date?
    
    // 任务是否已正常完成（用于区分正常关闭和错误）
    private var hasTaskFinished = false
    
    // 是否正在处理中（防止重复触发）
    private var isProcessing = false
    
    // MARK: - 初始化
    
    override init() {
        super.init()
        setupFunASRCallback()
    }
    
    // MARK: - 公开方法
    
    /// 检查麦克风权限
    func checkMicrophonePermission() -> Bool {
        return funASRService.checkMicrophonePermission()
    }
    
    /// 请求麦克风权限
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        funASRService.requestMicrophonePermission(completion: completion)
    }
    
    /// 开始实时语音识别
    func startRealtimeRecognition() {
        // 使用 isProcessing 标志防止重复触发
        guard !isProcessing else {
            print("[AudioRecorder] 正在处理中，忽略重复开始请求")
            return
        }
        
        // 检查状态，如果不是 idle，先重置
        if recordingState != .idle {
            print("[AudioRecorder] 状态不是 idle，先重置状态: \(recordingState)")
            resetState()
        }
        
        isProcessing = true
        print("[AudioRecorder] startRealtimeRecognition: 开始识别")
        shouldKeepOverlay = true
        recognizedText = ""
        recordingState = .realtimeRecognizing
        print("[AudioRecorder] startRealtimeRecognition: state set to realtimeRecognizing")
        
        // 调用 FunASR 服务开始识别
        // 注意：不需要在这里调用 cancelRecognition()，因为 startRecognition() 内部有检查
        funASRService.startRecognition()
        startLevelMonitoring()
    }
    
    /// 停止实时语音识别
    func stopRealtimeRecognition() {
        // 只在录音或实时识别状态时响应
        var isRecordingOrRecognizing = false
        if case .realtimeRecognizing = recordingState {
            isRecordingOrRecognizing = true
        } else if case .recording = recordingState {
            isRecordingOrRecognizing = true
        }
        
        guard isRecordingOrRecognizing else {
            print("[AudioRecorder] 停止识别：当前状态不是录音中，忽略")
            return
        }
        
        // 停止音量监测
        levelTimer?.invalidate()
        levelTimer = nil
        
        // 保持 overlay 显示，等待 taskFinished
        shouldKeepOverlay = true
        recordingState = .recognizing
        funASRService.stopRecognition()
    }
    
    /// 取消实时语音识别
    func cancelRealtimeRecognition() {
        shouldKeepOverlay = false
        levelTimer?.invalidate()
        levelTimer = nil
        
        funASRService.cancelRecognition()
        recognizedText = ""
        recordingState = .idle
        isProcessing = false  // 重置处理标志
        print("[AudioRecorder] cancelRealtimeRecognition: isProcessing reset to false")
    }
    
    /// 复制到剪贴板
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// 重置状态
    func resetState() {
        recordingState = .idle
        recognizedText = ""
        isRecording = false
        isTranslating = false
        audioLevel = 0.0
        shouldKeepOverlay = false
        recordingStartTime = nil
        hasTaskFinished = false  // 重置任务完成标志
        isProcessing = false     // 重置处理标志
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    // MARK: - 私有方法
    
    /// 设置 Fun-ASR WebSocket 回调
    private func setupFunASRCallback() {
        funASRService.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                self?.handleFunASREvent(event)
            }
        }
    }
    
    /// 判断当前是否处于活动状态（录音/实时识别中）
    private var isInActiveState: Bool {
        switch recordingState {
        case .realtimeRecognizing, .recording:
            return true
        default:
            return false
        }
    }
    
    /// 判断当前是否处于处理完成状态
    private var isInProcessingState: Bool {
        switch recordingState {
        case .recognizing, .completed:
            return true
        default:
            return false
        }
    }
    
    /// 处理 Fun-ASR WebSocket 事件
    private func handleFunASREvent(_ event: FunASREvent) {
        print("[AudioRecorder] handleFunASREvent: \(event), current state=\(recordingState)")
        switch event {
        case .connected:
            print("[AudioRecorder] Fun-ASR WebSocket 已连接")
            isRecording = true
            
        case .taskStarted:
            print("[AudioRecorder] Fun-ASR 任务已开始")
            
        case .resultReceived:
            // 使用实时预览文本，显示每次识别的中间结果
            recognizedText = funASRService.currentPreviewText
            print("[AudioRecorder] 实时识别: \(funASRService.currentPreviewText)")
            
        case .taskFinished:
            print("[AudioRecorder] Fun-ASR 任务完成，最终文本: \(funASRService.fullTranscript)")
            let rawTranscript = funASRService.fullTranscript
            recognizedText = rawTranscript
            hasTaskFinished = true  // 标记任务已正常完成
            isProcessing = false    // 任务完成，重置处理标志
            print("[AudioRecorder] state changed to completed, hasTaskFinished=true, isProcessing=false")

            // 检查是否启用了 AI 文本润色
            let aiSettings = AISettingsStore.shared
            if aiSettings.isEnabled && aiSettings.isConfigurationValid && !rawTranscript.isEmpty {
                print("[AudioRecorder] AI 润色已启用，开始润色文本...")
                recordingState = .recognizing  // 显示"识别中"状态，表示正在处理

                AITextPolishService.shared.polishText(rawTranscript) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .success(let polishedText):
                        print("[AudioRecorder] AI 润色完成: \(polishedText.prefix(50))...")
                        self.finalizeRecording(with: polishedText)
                    case .failure(let error):
                        print("[AudioRecorder] AI 润色失败: \(error.localizedDescription)，使用原始文本")
                        self.finalizeRecording(with: rawTranscript)
                    }
                }
            } else {
                // 未启用 AI 润色或配置无效，直接使用原始文本
                if aiSettings.isEnabled && !aiSettings.isConfigurationValid {
                    print("[AudioRecorder] AI 润色已启用但配置无效，跳过润色")
                }
                finalizeRecording(with: rawTranscript)
            }
            
        case .taskFailed(let errorCode, let errorMessage):
            print("[AudioRecorder] Fun-ASR 任务失败: \(errorCode) - \(errorMessage)")
            print("[AudioRecorder] isInActiveState=\(isInActiveState), isInProcessingState=\(isInProcessingState), hasTaskFinished=\(hasTaskFinished)")
            
            // 差异化错误处理：
            // 活动状态时，立即显示错误
            // 处理完成状态时，忽略非连接失败错误
            if isInActiveState {
                recordingState = .error(message: "\(errorCode): \(errorMessage)")
                print("[AudioRecorder] state changed to error: \(errorCode)")
            } else if isInProcessingState {
                // 处理完成状态下，只有连接失败才显示错误
                if errorCode.contains("connection") || errorCode.contains("network") {
                    recordingState = .error(message: "\(errorCode): \(errorMessage)")
                    print("[AudioRecorder] state changed to error (connection): \(errorCode)")
                } else {
                    print("[AudioRecorder] error ignored (not connection error)")
                }
                // 其他错误不显示，静默处理
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                // 检查状态是否已经被重置
                guard case .error = self.recordingState else {
                    print("[AudioRecorder] state is not error in auto-hide timer, skipping")
                    return
                }
                print("[AudioRecorder] error auto-hide timer fired")
                self.resetState()
                RecordingOverlayManager.shared.hideOverlay()
            }
            
        case .disconnected:
            print("[AudioRecorder] Fun-ASR WebSocket 已断开")
            print("[AudioRecorder] isInActiveState=\(isInActiveState), hasTaskFinished=\(hasTaskFinished), recordingState=\(recordingState)")
            isRecording = false
            
            // 如果任务已正常完成，不显示断开错误
            if hasTaskFinished {
                print("[AudioRecorder] ignoring disconnected (hasTaskFinished=true)")
                return
            }
            
            // 如果状态已经是 idle（用户已主动关闭），不显示错误
            if case .idle = recordingState {
                print("[AudioRecorder] ignoring disconnected (state is idle)")
                return
            }
            
            // 连接断开需要始终提示（可能影响后续业务流程）
            if isInActiveState {
                recordingState = .error(message: "网络连接已断开")
                print("[AudioRecorder] state changed to error: 网络连接已断开")
            } else {
                print("[AudioRecorder] disconnected ignored (not in active state)")
            }
            
        case .error(let error):
            print("[AudioRecorder] Fun-ASR 错误: \(error.localizedDescription)")
            print("[AudioRecorder] isInActiveState=\(isInActiveState), isInProcessingState=\(isInProcessingState), hasTaskFinished=\(hasTaskFinished)")
            
            // 如果任务已正常完成，不显示后续错误
            if hasTaskFinished {
                print("[AudioRecorder] ignoring error (hasTaskFinished=true)")
                return
            }
            
            // 差异化错误处理：
            // 活动状态时，立即显示错误
            // 处理完成状态时，忽略非连接失败错误
            let isConnectionError = error.localizedDescription.contains("connection") ||
                                   error.localizedDescription.contains("network") ||
                                   error.localizedDescription.contains("Socket")
            
            if isInActiveState {
                recordingState = .error(message: error.localizedDescription)
                print("[AudioRecorder] state changed to error: \(error.localizedDescription)")
            } else if isInProcessingState && isConnectionError {
                // 处理完成状态下，只有连接失败才显示错误
                recordingState = .error(message: error.localizedDescription)
                print("[AudioRecorder] state changed to error (connection): \(error.localizedDescription)")
            } else {
                print("[AudioRecorder] error ignored")
            }
            // 其他错误不显示，静默处理
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                // 检查状态是否已经被重置
                guard case .error = self.recordingState else {
                    print("[AudioRecorder] state is not error in auto-hide timer, skipping")
                    return
                }
                print("[AudioRecorder] error auto-hide timer fired")
                self.resetState()
                RecordingOverlayManager.shared.hideOverlay()
            }
        }
    }

    /// 完成录音流程，输入文本到光标位置
    private func finalizeRecording(with text: String) {
        // 检查是否需要翻译
        let settings = SettingsStore.shared
        let aiSettings = AISettingsStore.shared

        if settings.translationMode != .none && aiSettings.isConfigurationValid && !text.isEmpty {
            print("[AudioRecorder] 需要翻译，目标语言: \(settings.translationMode.targetLanguage)")
            recordingState = .recognizing  // 显示处理中状态

            AITextPolishService.shared.translateText(text, targetLanguage: settings.translationMode.targetLanguage) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let translatedText):
                    print("[AudioRecorder] 翻译完成: \(translatedText.prefix(50))...")
                    self.inputFinalText(translatedText)
                case .failure(let error):
                    print("[AudioRecorder] 翻译失败: \(error.localizedDescription)，使用原文")
                    self.inputFinalText(text)
                }
            }
        } else {
            inputFinalText(text)
        }
    }

    /// 输入最终文本到光标位置
    private func inputFinalText(_ text: String) {
        recordingState = .completed(text: text)

        if !text.isEmpty {
            print("[AudioRecorder] Calling GlobalTextInputService.inputText() with: \(text.prefix(50))...")
            // 使用全局文本输入服务，将文本输入到当前焦点位置
            // 注意：overlay 的显示和隐藏由 AudioRecorderManager 单独管理
            GlobalTextInputService.shared.inputText(text) { [weak self] in
                guard let self = self else { return }
                print("[AudioRecorder] 文本已输入到当前光标位置")

                // 检查状态是否已经被重置（用户可能已经开始新的录制）
                guard case .completed = self.recordingState else {
                    print("[AudioRecorder] state is not completed, skipping auto-hide")
                    return
                }

                // 文本填充完成后，保持 overlay 显示一段时间让用户看到结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    // 再次检查状态
                    guard case .completed = self.recordingState else {
                        print("[AudioRecorder] state is not completed in auto-hide timer, skipping")
                        return
                    }
                    print("[AudioRecorder] auto-hide: calling resetState() and hideOverlay()")
                    self.shouldKeepOverlay = false
                    self.resetState()
                    RecordingOverlayManager.shared.hideOverlay()
                }
            }
        } else {
            print("[AudioRecorder] text is empty, no input needed")
            // 没有文本，延迟后自动隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                // 检查状态是否已经被重置
                guard case .completed = self.recordingState else {
                    print("[AudioRecorder] state is not completed in auto-hide timer, skipping")
                    return
                }
                self.shouldKeepOverlay = false
                self.resetState()
                RecordingOverlayManager.shared.hideOverlay()
            }
        }
    }
    
    /// 开始音量监测
    private func startLevelMonitoring() {
        // 取消之前的定时器（现在使用 FunASRWebSocketService 的真实音量回调）
        levelTimer?.invalidate()
        levelTimer = nil

        // 设置 FunASR 服务的音量回调
        funASRService.onAudioLevelUpdate = { [weak self] level in
            guard let self = self else { return }

            // 应用平滑处理，避免音量跳动过快
            let smoothedLevel = self.smoothAudioLevel(level)

            DispatchQueue.main.async {
                self.audioLevel = smoothedLevel

                // 更新录音状态，传递真实音量
                if case .realtimeRecognizing = self.recordingState {
                    self.recordingState = .recording(volume: smoothedLevel, isTranslating: self.isTranslating)
                } else if case .recording(_, let isTranslating) = self.recordingState {
                    self.recordingState = .recording(volume: smoothedLevel, isTranslating: isTranslating)
                }
            }
        }
    }

    // 音量平滑处理参数
    private var lastAudioLevel: Double = 0.0
    private let smoothingFactor: Double = 0.3

    /// 平滑音频音量，避免跳动过快
    private func smoothAudioLevel(_ newLevel: Double) -> Double {
        let smoothed = lastAudioLevel * (1 - smoothingFactor) + newLevel * smoothingFactor
        lastAudioLevel = smoothed
        return smoothed
    }
}
