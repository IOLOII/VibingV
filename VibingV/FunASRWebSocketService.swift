import Foundation
import AVFoundation

// MARK: - Fun-ASR WebSocket 实时语音识别服务

/// Fun-ASR WebSocket 实时语音识别服务配置
struct FunASRConfig {
    // WebSocket 端点
    static let webSocketURL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference/"

    // API Key
    static var apiKey: String {
        // 优先从环境变量获取
        if let envKey = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] {
            return envKey
        }
        // 回退到硬编码的 API Key
        return "sk-use-your-key" // - [阿里云百炼 API Key 获取](https://help.aliyun.com/zh/model-studio/get-api-key)
    }

    // 模型名称
    static let model = "fun-asr-realtime"

    // 音频参数
    static let sampleRate = 16000
    static let format = "pcm"

    // 音频分片大小 (每100ms的音频数据约1600字节 for 16kHz 16bit mono PCM)
    static let chunkSize = 1024

    // 发送间隔 (毫秒)
    static let sendInterval: TimeInterval = 0.1

    // MARK: - 可调优参数

    /// 是否启用语义断句
    /// - true: 使用语义断句，关闭 VAD 断句，适合会议转写，准确度高
    /// - false: 使用 VAD 断句，关闭语义断句，适合交互场景，延迟低
    /// 默认: false (VAD 断句，响应更快)
    static let semanticPunctuationEnabled = true

    /// VAD 静音时长阈值（毫秒）
    /// 静音时长超过该阈值即判定句子结束
    /// 取值范围: [200, 6000]
    /// 默认: 800ms (较短的阈值，响应更及时)
    static let maxSentenceSilence = 800

    /// 是否开启防止 VAD 断句过长的功能
    /// - true: 限制 VAD 断句长度，避免过长切割
    /// - false: 关闭
    /// 默认: false
    static let multiThresholdModeEnabled = false

    /// 是否开启长连接保持
    /// - true: 开启，持续发送静音音频时保持连接
    /// - false: 关闭，60秒后连接因超时断开
    /// 默认: false
    static let heartbeatEnabled = false

    /// 语言提示（可选）
    /// 支持: "zh" (中文), "en" (英文), "ja" (日语)
    /// 如果不设置，模型会自动识别语种
    /// 默认: nil (自动识别)
    static let languageHints: [String]? = nil

    /// 语音噪音阈值
    /// 取值范围: [-1.0, 1.0]
    /// - 接近 -1: 噪音被识别为语音的概率增大
    /// - 接近 +1: 语音被误判为噪音的概率增大
    /// 默认: 0.0 (平衡)
    static let speechNoiseThreshold: Float = 0.0
}

// MARK: - 识别结果结构体

/// 实时语音识别结果
struct FunASRRecognitionResult {
    let text: String
    let beginTime: Int
    let endTime: Int?
    let isFinal: Bool
    let usageDuration: Int?

    init(text: String, beginTime: Int = 0, endTime: Int? = nil, isFinal: Bool = false, usageDuration: Int? = nil) {
        self.text = text
        self.beginTime = beginTime
        self.endTime = endTime
        self.isFinal = isFinal
        self.usageDuration = usageDuration
    }
}

// MARK: - WebSocket 事件

/// Fun-ASR WebSocket 事件类型
enum FunASREvent {
    case connected
    case taskStarted
    case resultReceived(FunASRRecognitionResult)
    case taskFinished
    case taskFailed(errorCode: String, errorMessage: String)
    case disconnected
    case error(Error)
}

// MARK: - Fun-ASR WebSocket 服务类

/// Fun-ASR WebSocket 实时语音识别服务
class FunASRWebSocketService: NSObject {
    static let shared = FunASRWebSocketService()

    // WebSocket 连接
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // 音频引擎
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?

    // 状态标记
    private(set) var isConnected = false
    private(set) var isTaskStarted = false
    private(set) var isRecording = false

    // 是否正在取消（用于防止取消后的错误回调）
    private var isCancelling = false

    // 任务 ID
    private var taskId: String = ""

    // 回调
    var onEvent: ((FunASREvent) -> Void)?

    // 完整识别文本（最终输出，只有 final=true 时追加）
    private(set) var fullTranscript: String = ""

    // 当前预览文本（实时显示，每次识别结果都更新）
    private(set) var currentPreviewText: String = ""

    // 音频缓冲队列
    private var audioBuffer: Data = Data()
    private let audioQueue = DispatchQueue(label: "com.vibingv.funasr.audioqueue")

    // 录音文件 URL
    private var recordingURL: URL?

    override init() {
        super.init()
    }

    // MARK: - 公开方法

    /// 检查麦克风权限
    func checkMicrophonePermission() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return false
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// 请求麦克风权限
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// 开始实时语音识别（假设权限已检查并授权）
    func startRecognition() {
        print("[FunASR] startRecognition() called, isConnected=\(isConnected), isRecording=\(isRecording), isTaskStarted=\(isTaskStarted)")
        guard !isConnected else {
            print("[FunASR] WebSocket 已连接")
            return
        }

        print("[FunASR] 开始识别, isConnected=\(isConnected)")
        // 重置状态
        fullTranscript = ""
        currentPreviewText = ""
        isTaskStarted = false
        isCancelling = false  // 重置取消标志
        taskId = generateTaskId()
        print("[FunASR] 任务 ID: \(taskId)")

        // 创建 WebSocket 连接
        connectWebSocket()
    }

    /// 停止实时语音识别
    func stopRecognition() {
        guard isConnected else { return }

        isRecording = false

        // 发送 finish-task 指令
        sendFinishTask()

        // 延迟关闭连接
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.disconnect()
        }
    }

    /// 取消识别
    func cancelRecognition() {
        print("[FunASR] cancelRecognition() called, isRecording=\(isRecording), isConnected=\(isConnected)")
        isCancelling = true  // 标记正在取消
        isRecording = false
        stopAudioCapture()
        print("[FunASR] cancelRecognition: calling disconnect()")
        disconnect()
        fullTranscript = ""
        currentPreviewText = ""
        print("[FunASR] cancelRecognition() completed")
    }

    // MARK: - 私有方法

    /// 生成 32 位任务 ID
    private func generateTaskId() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32).description
    }

    /// 连接 WebSocket
    private func connectWebSocket() {
        guard let url = URL(string: FunASRConfig.webSocketURL) else {
            onEvent?(.error(NSError(domain: "FunASR", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 WebSocket URL"])))
            return
        }

        print("[FunASR] 准备连接 WebSocket: \(FunASRConfig.webSocketURL)")
        print("[FunASR] API Key 长度: \(FunASRConfig.apiKey.count)")

        // 创建 URLSession
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        // 创建 WebSocket Task
        var request = URLRequest(url: url)
        request.setValue("Bearer \(FunASRConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        // 开始接收消息
        receiveMessage()

        print("[FunASR] WebSocket 连接中...")
    }

    /// 断开 WebSocket 连接
    private func disconnect() {
        print("[FunASR] disconnect() called, isConnected=\(isConnected), webSocketTask=\(webSocketTask != nil)")
        guard isConnected || webSocketTask != nil else {
            print("[FunASR] 断开连接: 已经处于断开状态")
            return
        }

        print("[FunASR] 断开WebSocket连接")
        isConnected = false
        isTaskStarted = false

        if let task = webSocketTask {
            task.cancel(with: .normalClosure, reason: nil)
        }
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        // 停止音频采集
        stopAudioCapture()

        print("[FunASR] WebSocket 连接已关闭")
        print("[FunASR] disconnect: calling onEvent?(.disconnected)")
        onEvent?(.disconnected)
    }

    /// 接收 WebSocket 消息
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            // 如果正在取消，忽略所有错误
            if self.isCancelling {
                print("[FunASR] receiveMessage: ignoring callback (isCancelling=true)")
                return
            }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleTextMessage(text)
                    }
                @unknown default:
                    break
                }
                // 继续接收下一条消息
                self.receiveMessage()

            case .failure(let error):
                // 如果正在取消，忽略错误
                if self.isCancelling {
                    print("[FunASR] 接收消息失败(取消中，忽略): \(error.localizedDescription)")
                    return
                }
                print("[FunASR] 接收消息失败: \(error.localizedDescription)")
                self.onEvent?(.error(error))
                self.disconnect()
            }
        }
    }

    /// 处理文本消息
    private func handleTextMessage(_ text: String) {
        print("[FunASR] 收到原始消息: \(text)")

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              let event = header["event"] as? String else {
            print("[FunASR] 无法解析消息为 JSON")
            return
        }

        print("[FunASR] 收到事件: \(event)")

        switch event {
        case "task-started":
            isTaskStarted = true
            onEvent?(.taskStarted)
            // 开始录音并发送音频流
            startAudioCapture()

        case "result-generated":
            if let payload = json["payload"] as? [String: Any],
               let output = payload["output"] as? [String: Any],
               let sentence = output["sentence"] as? [String: Any] {
                let text = sentence["text"] as? String ?? ""
                let beginTime = sentence["begin_time"] as? Int ?? 0
                let endTime = sentence["end_time"] as? Int
                let sentenceEnd = sentence["sentence_end"] as? Bool ?? false
                let usageDuration = (payload["usage"] as? [String: Any])?["duration"] as? Int

                // 打印识别结果
                print("[FunASR] 识别结果: \"\(text)\" (begin: \(beginTime), end: \(endTime ?? -1), final: \(sentenceEnd))")

                // Fun-ASR 返回的 text 只是当前时刻识别出的词，不是完整句子
                // 我们需要从 words 数组构建完整句子
                var completeSentence = text
                if let words = sentence["words"] as? [[String: Any]] {
                    let wordTexts = words.compactMap { $0["text"] as? String }
                    if !wordTexts.isEmpty {
                        completeSentence = wordTexts.joined()
                        // 如果有标点符号（在最后一个词中），追加到句子末尾
                        if let lastWord = words.last,
                           let lastPunct = lastWord["punctuation"] as? String,
                           !lastPunct.isEmpty {
                            completeSentence += lastPunct
                        }
                    }
                }
                print("[FunASR] 完整句子: \"\(completeSentence)\" (final: \(sentenceEnd))")

                // 只有 final=true (sentenceEnd=true) 的结果才是确认的识别结果
                // final=false 的中间结果仅用于实时 UI 显示预览，不应更新 fullTranscript
                if sentenceEnd {
                    // 这是一个确认的句子，需要追加到累积文本
                    if !completeSentence.isEmpty {
                        if fullTranscript.isEmpty {
                            fullTranscript = completeSentence
                        } else {
                            fullTranscript = fullTranscript + completeSentence
                        }
                        print("[FunASR] 句子确认，追加到完整文本: \"\(fullTranscript)\"")
                    } else {
                        print("[FunASR] 句子确认但内容为空，保留之前的完整文本: \"\(fullTranscript)\"")
                    }
                    // final=true 时，currentPreviewText = fullTranscript
                    currentPreviewText = fullTranscript
                } else {
                    // 中间结果，更新 currentPreviewText 为 fullTranscript + 当前中间结果
                    if !completeSentence.isEmpty {
                        currentPreviewText = fullTranscript + completeSentence
                    } else {
                        currentPreviewText = fullTranscript
                    }
                    print("[FunASR] 中间结果预览: \"\(currentPreviewText)\"")
                }

                let result = FunASRRecognitionResult(
                    text: text,
                    beginTime: beginTime,
                    endTime: endTime,
                    isFinal: sentenceEnd,
                    usageDuration: usageDuration
                )
                onEvent?(.resultReceived(result))
            }

        case "task-finished":
            print("[FunASR] 任务完成")
            onEvent?(.taskFinished)

        case "task-failed":
            let errorCode = header["error_code"] as? String ?? "UNKNOWN"
            let errorMessage = header["error_message"] as? String ?? "未知错误"
            print("[FunASR] 任务失败: \(errorCode) - \(errorMessage)")
            onEvent?(.taskFailed(errorCode: errorCode, errorMessage: errorMessage))
            disconnect()

        default:
            print("[FunASR] 未知事件: \(event)")
        }
    }

    /// 发送 run-task 指令
    private func sendRunTask() {
        // 构建 parameters
        var parameters: [String: Any] = [
            "format": FunASRConfig.format,
            "sample_rate": FunASRConfig.sampleRate,
            "semantic_punctuation_enabled": FunASRConfig.semanticPunctuationEnabled,
            "max_sentence_silence": FunASRConfig.maxSentenceSilence,
            "multi_threshold_mode_enabled": FunASRConfig.multiThresholdModeEnabled,
            "heartbeat": FunASRConfig.heartbeatEnabled,
            "speech_noise_threshold": FunASRConfig.speechNoiseThreshold
        ]

        // 添加语言提示（如果有设置）
        if let languageHints = FunASRConfig.languageHints, !languageHints.isEmpty {
            parameters["language_hints"] = languageHints
        }

        let runTaskMessage: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": FunASRConfig.model,
                "parameters": parameters,
                "input": [:]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: runTaskMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("[FunASR] 发送 run-task 失败: \(error.localizedDescription)")
                self?.onEvent?(.error(error))
            } else {
                print("[FunASR] run-task 指令已发送")
            }
        }
    }

    /// 发送 finish-task 指令
    private func sendFinishTask() {
        let finishTaskMessage: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: finishTaskMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("[FunASR] 发送 finish-task 失败: \(error.localizedDescription)")
            } else {
                print("[FunASR] finish-task 指令已发送")
            }
        }
    }

    /// 开始音频采集
    private func startAudioCapture() {
        // 创建录音文件用于保存
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("funasr_recording.pcm")

        guard let recordingURL = recordingURL else { return }
        try? FileManager.default.removeItem(at: recordingURL)

        // 配置音频引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else { return }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("[FunASR] 输入音频格式: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        // 目标格式: 16kHz 单声道 PCM 16bit
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        print("[FunASR] 目标音频格式: \(targetFormat.sampleRate)Hz, \(targetFormat.channelCount) channels")

        do {
            // 创建 PCM 文件 (16kHz mono)
            let pcmSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            audioFile = try AVAudioFile(forWriting: recordingURL, settings: pcmSettings)

            // 安装 tap 采集音频，使用重采样转换器
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBufferWithResample(buffer, targetFormat: targetFormat)
            }

            try audioEngine.start()
            isRecording = true
            print("[FunASR] 音频采集已开始")

        } catch {
            print("[FunASR] 启动音频采集失败: \(error.localizedDescription)")
            onEvent?(.error(error))
        }
    }

    // 音频音量回调
    var onAudioLevelUpdate: ((Double) -> Void)?

    /// 计算音频音量级别
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0.0 }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0.0
        var maxAmplitude: Float = 0.0

        // 计算所有通道的平均振幅和最大振幅
        for channel in 0..<channelCount {
            let data = channelData[channel]
            for i in 0..<frameLength {
                let amplitude = abs(data[i])
                sum += amplitude
                if amplitude > maxAmplitude {
                    maxAmplitude = amplitude
                }
            }
        }

        let averageAmplitude = sum / Float(frameLength * channelCount)

        // 使用对数刻度转换，使音量显示更自然
        // 将 0-1 的范围映射到 0-1，但使用对数曲线
        let db = 20 * log10(max(averageAmplitude, 0.0001))
        let normalizedLevel = min(max((db + 60) / 60, 0), 1)

        return Double(normalizedLevel)
    }

    /// 处理音频缓冲并进行重采样
    private func processAudioBufferWithResample(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard isRecording, isTaskStarted else { return }

        // 计算音频音量并回调
        let audioLevel = calculateAudioLevel(from: buffer)
        DispatchQueue.main.async {
            self.onAudioLevelUpdate?(audioLevel)
        }

        // 创建音频转换器
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            print("[FunASR] 无法创建音频转换器")
            return
        }

        // 计算输出缓冲大小
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return
        }

        // 进行重采样
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            print("[FunASR] 音频重采样失败: \(error?.localizedDescription ?? "未知错误")")
            return
        }

        guard status == .haveData else {
            return
        }

        // 获取重采样后的 PCM 数据
        guard let channelData = outputBuffer.floatChannelData else { return }

        let frameLength = Int(outputBuffer.frameLength)

        // 转换 Float 样本为 Int16 (PCM 16bit)
        var pcmData = Data()
        for i in 0..<frameLength {
            let sample = channelData[0][i]
            let intSample = Int16(max(-1.0, min(1.0, sample)) * Float(Int16.max))
            var littleEndian = intSample.littleEndian
            pcmData.append(Data(bytes: &littleEndian, count: 2))
        }

        // 保存到文件
        if let audioFile = audioFile {
            do {
                try audioFile.write(from: outputBuffer)
            } catch {
                print("[FunASR] 写入音频文件失败: \(error.localizedDescription)")
            }
        }

        // 发送到服务器
        sendAudioData(pcmData)
    }

    /// 停止音频采集
    private func stopAudioCapture() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        isRecording = false
        print("[FunASR] 音频采集已停止")
    }

    /// 发送音频数据
    private func sendAudioData(_ data: Data) {
        guard isConnected, isTaskStarted else { return }

        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("[FunASR] 发送音频数据失败: \(error.localizedDescription)")
                self?.onEvent?(.error(error))
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension FunASRWebSocketService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[FunASR] WebSocket 连接已建立, isConnected=\(isConnected)")
        isConnected = true
        onEvent?(.connected)

        // 发送 run-task 指令
        sendRunTask()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[FunASR] WebSocket 连接已关闭: closeCode=\(closeCode.rawValue), reason=\(reason?.description ?? "nil")")
        isConnected = false
        isTaskStarted = false
        isRecording = false
        stopAudioCapture()
        onEvent?(.disconnected)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[FunASR] WebSocket 任务完成但有错误: \(error.localizedDescription)")
            onEvent?(.error(error))
        }
        isConnected = false
        isTaskStarted = false
    }
}
