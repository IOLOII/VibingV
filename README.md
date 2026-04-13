# VibingV

> Inspired by [Vibing](https://github.com/VibingJustSpeakIt/Vibing)

A local utility powered by online AI LLMs (e.g., DeepSeek) and speech models (e.g., Alibaba Cloud).

## update your key

`VibingV/FunASRWebSocketService.swift`

```swift
    // API Key
    static var apiKey: String {
        // 优先从环境变量获取
        if let envKey = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] {
            return envKey
        }
        // 回退到硬编码的 API Key
        return "sk-use-your-key" // - [阿里云百炼 API Key 获取](https://help.aliyun.com/zh/model-studio/get-api-key)
    }
```

<img width="1000" height="700" alt="image" src="https://github.com/user-attachments/assets/ac6e4ce4-9290-4a90-bcfc-131a57790bc8" />
<img width="400" height="148" alt="image" src="https://github.com/user-attachments/assets/b5471a12-5c6b-47ff-9344-6ffa69023199" />
