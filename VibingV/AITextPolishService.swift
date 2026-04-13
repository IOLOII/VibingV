import Foundation
import Combine

// MARK: - AI 文本润色服务

/// AI 文本润色服务 - 支持多种大模型 API
/// 支持 OpenAI 兼容协议的 API，如 DeepSeek、Minimax 等
class AITextPolishService: ObservableObject {
    static let shared = AITextPolishService()

    // MARK: - Published Properties
    @Published var isPolishing: Bool = false
    @Published var lastPolishedText: String = ""
    @Published var lastError: String? = nil

    // MARK: - 配置
    struct AIConfig {
        // API 配置
        var apiKey: String
        var baseURL: String
        var model: String
        var provider: AIProvider

        init(apiKey: String, baseURL: String, model: String, provider: AIProvider) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.model = model
            self.provider = provider
        }
    }

    enum AIProvider: String, CaseIterable, Identifiable {
        case deepseek = "DeepSeek"
        case minimax = "Minimax"
        case openai = "OpenAI"
        case custom = "自定义"

        var id: String { rawValue }

        var defaultBaseURL: String {
            switch self {
            case .deepseek:
                return "https://api.deepseek.com/v1"
            case .minimax:
                return "https://api.minimax.chat/v1"
            case .openai:
                return "https://api.openai.com/v1"
            case .custom:
                return ""
            }
        }

        var defaultModel: String {
            switch self {
            case .deepseek:
                return "deepseek-chat"
            case .minimax:
                return "abab6.5s-chat"
            case .openai:
                return "gpt-3.5-turbo"
            case .custom:
                return ""
            }
        }

        var description: String {
            switch self {
            case .deepseek:
                return "DeepSeek Chat - 国产大模型"
            case .minimax:
                return "Minimax - 国产大模型"
            case .openai:
                return "OpenAI GPT"
            case .custom:
                return "自定义 OpenAI 兼容 API"
            }
        }
    }

    // MARK: - 私有属性
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: URLSessionDataTask?

    // MARK: - 初始化
    private init() {}

    // MARK: - 公开方法

    /// 润色文本
    /// - Parameters:
    ///   - text: 原始识别文本
    ///   - config: AI 配置（可选，默认从 SettingsStore 读取）
    ///   - completion: 完成回调
    func polishText(
        _ text: String,
        config: AIConfig? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !text.isEmpty else {
            completion(.success(text))
            return
        }

        // 获取配置
        let aiConfig: AIConfig
        if let config = config {
            aiConfig = config
        } else {
            guard let storedConfig = loadConfigFromSettings() else {
                completion(.failure(AIPolishError.configurationMissing))
                return
            }
            aiConfig = storedConfig
        }

        guard !aiConfig.apiKey.isEmpty else {
            completion(.failure(AIPolishError.apiKeyMissing))
            return
        }

        isPolishing = true
        lastError = nil

        // 构建请求
        let request = buildPolishRequest(text: text, config: aiConfig)

        // 发送请求
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isPolishing = false

                if let error = error {
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    let error = AIPolishError.noData
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                    return
                }

                do {
                    let polishedText = try self?.parseResponse(data: data, provider: aiConfig.provider)
                    if let polishedText = polishedText {
                        self?.lastPolishedText = polishedText
                        completion(.success(polishedText))
                    } else {
                        let error = AIPolishError.parseError
                        self?.lastError = error.localizedDescription
                        completion(.failure(error))
                    }
                } catch {
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }

        currentTask?.resume()
    }

    /// 取消当前的润色请求
    func cancelPolishing() {
        currentTask?.cancel()
        currentTask = nil
        isPolishing = false
    }

    /// 翻译文本
    /// - Parameters:
    ///   - text: 原始文本
    ///   - targetLanguage: 目标语言（"中文" 或 "English"）
    ///   - config: AI 配置（可选，默认从 SettingsStore 读取）
    ///   - completion: 完成回调
    func translateText(
        _ text: String,
        targetLanguage: String,
        config: AIConfig? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !text.isEmpty else {
            completion(.success(text))
            return
        }

        // 获取配置
        let aiConfig: AIConfig
        if let config = config {
            aiConfig = config
        } else {
            guard let storedConfig = loadConfigFromSettings() else {
                completion(.failure(AIPolishError.configurationMissing))
                return
            }
            aiConfig = storedConfig
        }

        guard !aiConfig.apiKey.isEmpty else {
            completion(.failure(AIPolishError.apiKeyMissing))
            return
        }

        isPolishing = true
        lastError = nil

        // 构建请求
        let request = buildTranslateRequest(text: text, targetLanguage: targetLanguage, config: aiConfig)

        // 发送请求
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isPolishing = false

                if let error = error {
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    let error = AIPolishError.noData
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                    return
                }

                do {
                    let translatedText = try self?.parseResponse(data: data, provider: aiConfig.provider)
                    if let translatedText = translatedText {
                        self?.lastPolishedText = translatedText
                        completion(.success(translatedText))
                    } else {
                        let error = AIPolishError.parseError
                        self?.lastError = error.localizedDescription
                        completion(.failure(error))
                    }
                } catch {
                    self?.lastError = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }

        currentTask?.resume()
    }

    /// 构建翻译请求
    private func buildTranslateRequest(text: String, targetLanguage: String, config: AIConfig) -> URLRequest {
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        // 构建系统提示词
        let systemPrompt = buildTranslationSystemPrompt(targetLanguage: targetLanguage)

        // 构建请求体
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 4096
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        return request
    }

    /// 构建翻译系统提示词
    private func buildTranslationSystemPrompt(targetLanguage: String) -> String {
        return """
        你是一个专业的翻译助手。请将用户输入的文本翻译成\(targetLanguage)。

        请遵循以下规则：
        1. 保持原文的意思不变
        2. 翻译要自然流畅，符合\(targetLanguage)的表达习惯
        3. 保留原文的语气和风格
        4. 对于专业术语，确保翻译准确
        5. 只输出翻译后的文本，不要添加任何解释
        6. 如果原文已经是\(targetLanguage)，直接返回原文
        """
    }

    // MARK: - 私有方法

    /// 从 SettingsStore 加载配置
    private func loadConfigFromSettings() -> AIConfig? {
        let settings = AISettingsStore.shared

        guard let provider = AIProvider(rawValue: settings.selectedProvider) else {
            return nil
        }

        return AIConfig(
            apiKey: settings.apiKey,
            baseURL: settings.baseURL.isEmpty ? provider.defaultBaseURL : settings.baseURL,
            model: settings.modelName.isEmpty ? provider.defaultModel : settings.modelName,
            provider: provider
        )
    }

    /// 构建润色请求
    private func buildPolishRequest(text: String, config: AIConfig) -> URLRequest {
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        // 构建系统提示词
        let systemPrompt = buildSystemPrompt()

        // 构建请求体
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 4096
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        return request
    }

    /// 构建系统提示词
    private func buildSystemPrompt() -> String {
        return """
        你是一个专业的文本润色助手。你的任务是对语音识别后的文本进行优化和修正。

        请遵循以下规则：
        1. 修正语音识别中的错误（同音字、错别字等）
        2. 添加适当的标点符号（逗号、句号、问号等）
        3. 优化句子结构，使其更通顺自然
        4. 保持原文的核心意思不变
        5. 删除无意义的重复词语
        6. 将口语化表达适当转为书面语（但不要过于正式）
        7. 保持段落结构清晰

        注意：
        - 只输出润色后的文本，不要添加任何解释
        - 不要改变原文的语气和风格
        - 如果原文已经是正确的，直接返回原文
        """
    }

    /// 解析响应
    private func parseResponse(data: Data, provider: AIProvider) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIPolishError.parseError
        }

        // 检查错误
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw AIPolishError.apiError(message: message)
        }

        // 解析 choices
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIPolishError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 错误类型

enum AIPolishError: LocalizedError {
    case configurationMissing
    case apiKeyMissing
    case noData
    case parseError
    case apiError(message: String)
    case networkError

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "AI 配置缺失，请在设置中配置 AI 服务"
        case .apiKeyMissing:
            return "API Key 未设置，请在设置中配置 API Key"
        case .noData:
            return "未收到响应数据"
        case .parseError:
            return "解析响应失败"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .networkError:
            return "网络错误"
        }
    }
}

// MARK: - AI 设置存储

/// AI 设置存储 - 管理 AI 润色相关的配置
class AISettingsStore: ObservableObject {
    static let shared = AISettingsStore()

    // MARK: - Keys
    private enum Keys {
        static let selectedProvider = "aiSelectedProvider"
        static let apiKey = "aiApiKey"
        static let baseURL = "aiBaseURL"
        static let modelName = "aiModelName"
        static let isEnabled = "aiPolishEnabled"
    }

    // MARK: - Published Properties
    @Published var selectedProvider: String {
        didSet {
            UserDefaults.standard.set(selectedProvider, forKey: Keys.selectedProvider)
            // 切换 provider 时，如果 baseURL 和 modelName 为空，使用默认值
            if baseURL.isEmpty {
                if let provider = AITextPolishService.AIProvider(rawValue: selectedProvider) {
                    baseURL = provider.defaultBaseURL
                    modelName = provider.defaultModel
                }
            }
        }
    }

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: Keys.apiKey)
        }
    }

    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: Keys.baseURL)
        }
    }

    @Published var modelName: String {
        didSet {
            UserDefaults.standard.set(modelName, forKey: Keys.modelName)
        }
    }

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled)
        }
    }

    // MARK: - 初始化
    private init() {
        self.selectedProvider = UserDefaults.standard.string(forKey: Keys.selectedProvider) ?? AITextPolishService.AIProvider.deepseek.rawValue
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""
        self.baseURL = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        self.modelName = UserDefaults.standard.string(forKey: Keys.modelName) ?? ""
        self.isEnabled = UserDefaults.standard.object(forKey: Keys.isEnabled) as? Bool ?? false

        // 初始化默认值
        if baseURL.isEmpty {
            if let provider = AITextPolishService.AIProvider(rawValue: selectedProvider) {
                baseURL = provider.defaultBaseURL
                modelName = provider.defaultModel
            }
        }
    }

    // MARK: - 方法

    /// 重置为默认值
    func resetToDefaults() {
        selectedProvider = AITextPolishService.AIProvider.deepseek.rawValue
        apiKey = ""
        baseURL = AITextPolishService.AIProvider.deepseek.defaultBaseURL
        modelName = AITextPolishService.AIProvider.deepseek.defaultModel
        isEnabled = false
    }

    /// 验证配置是否完整
    var isConfigurationValid: Bool {
        !apiKey.isEmpty && !baseURL.isEmpty && !modelName.isEmpty
    }
}
