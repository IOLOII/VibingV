# 实时语音识别功能架构

## 概述

本项目使用 Fun-ASR WebSocket 协议实现实时语音识别功能，基于阿里云百炼服务。

## 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         FunASRWebSocketService                   │
│                        (FunASRWebSocketService.swift)           │
│                                                                  │
│  - WebSocket 连接管理 (URLSessionWebSocketTask)                  │
│  - 任务指令: run-task / finish-task                              │
│  - 音频格式: PCM 16bit 16kHz 单声道                              │
│  - 事件处理: task-started, result-generated, task-finished      │
└─────────────────────────────────────────────────────────────────┘
                                ▲
                                │ onEvent: FunASREvent
                                │
┌─────────────────────────────────────────────────────────────────┐
│                         AudioRecorderManager                      │
│                        (AudioRecorderManager.swift)             │
│                                                                  │
│  - 录音状态机: idle → recording → realtimeRecognizing → done    │
│  - 音频引擎: AVAudioEngine 采集麦克风输入                         │
│  - 音量监测: 实时音量显示                                        │
│  - UI 绑定: @Published 属性与 SwiftUI 视图同步                   │
└─────────────────────────────────────────────────────────────────┘
```

## 核心文件

### FunASRWebSocketService.swift
- **职责**: WebSocket 通信和音频流传输
- **协议**: Fun-ASR 实时语音识别 WebSocket API
- **端点**: `wss://dashscope.aliyuncs.com/api-ws/v1/inference/`
- **模型**: `fun-asr-realtime`

### AudioRecorderManager.swift
- **职责**: 协调录音和识别流程
- **功能**:
  - 管理录音状态 (`RecordingState`)
  - 控制 AVAudioEngine 进行音频采集
  - 提供实时识别开始/停止方法
  - 音量监测和 UI 状态同步

## 事件流

```
1. connectWebSocket()     → WebSocket 连接建立
2. sendRunTask()           → 发送 run-task 指令
3. 收到 task-started       → 开始音频采集
4. processAudioBuffer()    → PCM 音频数据通过 WebSocket 发送
5. 收到 result-generated   → 实时返回识别结果
6. sendFinishTask()        → 发送 finish-task 指令
7. 收到 task-finished      → 任务完成
```

## 录音状态机

```swift
enum RecordingState {
    case idle                           // 空闲
    case recording(volume: Double, isTranslating: Bool)  // 录音中
    case realtimeRecognizing            // 实时识别中
    case recognizing                    // 识别中
    case completed(text: String)         // 完成
    case error(message: String)         // 错误
}
```

## 使用方式

```swift
// 设置实时识别回调
AudioRecorderManager.shared.onRealtimeEvent = { event in
    switch event {
    case .recognitionResult(let text, let isFinal, _, _):
        print("实时识别: \(text)")
    case .sessionFinished(let transcript):
        print("最终文本: \(transcript)")
    case .error(let message):
        print("错误: \(message)")
    default:
        break
    }
}

// 开始实时识别
AudioRecorderManager.shared.startRealtimeRecognition()

// 停止实时识别
AudioRecorderManager.shared.stopRealtimeRecognition()
```

## 废弃文件

位于 `useless/` 目录下的废弃文件:

- `OSSService.swift` - 旧版 OSS 上传服务，已被 WebSocket 实时识别替代
- `AliyunSpeechService.swift` - 旧版语音识别服务，已被 FunASRWebSocketService 替代

## 技术参数

| 参数 | 值 |
|------|-----|
| WebSocket URL | `wss://dashscope.aliyuncs.com/api-ws/v1/inference/` |
| 模型 | `fun-asr-realtime` |
| 音频格式 | PCM 16bit |
| 采样率 | 16000 Hz |
| 声道 | 单声道 |
| 鉴权 | Bearer Token |

## 参考文档

- [实时语音识别 WebSocket 协议](../../VibingV/实时语音识别ws.md)
- [阿里云百炼 API Key 获取](https://help.aliyun.com/zh/model-studio/get-api-key)
