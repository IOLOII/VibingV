import Foundation
import AppKit
import AVFoundation

/// 应用设置管理器
/// 使用 UserDefaults 持久化存储
class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    // MARK: - Keys
    private enum Keys {
        static let appearanceMode = "appearanceMode"  // 0=系统, 1=浅色, 2=深色
        static let selectedMicrophoneID = "selectedMicrophoneID"  // 麦克风设备ID
        static let selectedLanguage = "selectedLanguage"  // 语言
        static let isTextPolishEnabled = "isTextPolishEnabled"  // 文本润色
        static let isSoundEnabled = "isSoundEnabled"  // 音效反馈
        static let translationMode = "translationMode"  // 翻译模式
    }
    
    // MARK: - Appearance Mode
    enum AppearanceMode: Int, CaseIterable {
        case system = 0
        case light = 1
        case dark = 2
        
        var title: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
        
        var nsAppearanceName: NSAppearance.Name? {
            switch self {
            case .system: return nil  // 使用系统默认
            case .light: return .init("NSAppearanceNameAqua")
            case .dark: return .init("NSAppearanceNameDarkAqua")
            }
        }
    }
    
    // MARK: - Language
    enum Language: String, CaseIterable, Identifiable {
        case chinese = "中文"
        case english = "English"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
        
        /// 根据系统时区判断默认语言
        static var defaultBasedOnLocale: Language {
            let preferredLanguage = Locale.preferredLanguages.first ?? "zh-Hans"
            if preferredLanguage.hasPrefix("zh") {
                return .chinese
            } else {
                return .english
            }
        }
    }
    
    // MARK: - Translation Mode
    enum TranslationMode: String, CaseIterable, Identifiable {
        case none = "不翻译"
        case toEnglish = "翻译成英文"
        case toChinese = "翻译成中文"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
        
        var targetLanguage: String {
            switch self {
            case .none:
                return ""
            case .toEnglish:
                return "English"
            case .toChinese:
                return "中文"
            }
        }
    }
    
    // MARK: - Published Properties
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
            applyAppearance()
        }
    }
    
    @Published var selectedMicrophoneID: String {
        didSet {
            UserDefaults.standard.set(selectedMicrophoneID, forKey: Keys.selectedMicrophoneID)
        }
    }
    
    @Published var selectedLanguage: Language {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
        }
    }
    
    @Published var isTextPolishEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isTextPolishEnabled, forKey: Keys.isTextPolishEnabled)
        }
    }
    
    @Published var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: Keys.isSoundEnabled)
        }
    }

    @Published var translationMode: TranslationMode {
        didSet {
            UserDefaults.standard.set(translationMode.rawValue, forKey: Keys.translationMode)
        }
    }

    // MARK: - Available Microphones
    @Published var availableMicrophones: [MicrophoneInfo] = []
    
    struct MicrophoneInfo: Identifiable, Hashable {
        let id: String  // AVCaptureDevice.uniqueID
        let name: String
        let isDefault: Bool
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: MicrophoneInfo, rhs: MicrophoneInfo) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Initialization
    private init() {
        // 从 UserDefaults 加载设置
        let appearanceRawValue = UserDefaults.standard.integer(forKey: Keys.appearanceMode)
        self.appearanceMode = AppearanceMode(rawValue: appearanceRawValue) ?? .system
        
        self.selectedMicrophoneID = UserDefaults.standard.string(forKey: Keys.selectedMicrophoneID) ?? ""
        
        let languageRawValue = UserDefaults.standard.string(forKey: Keys.selectedLanguage) ?? "中文"
        self.selectedLanguage = Language(rawValue: languageRawValue) ?? .chinese
        
        self.isTextPolishEnabled = UserDefaults.standard.object(forKey: Keys.isTextPolishEnabled) as? Bool ?? true
        self.isSoundEnabled = UserDefaults.standard.object(forKey: Keys.isSoundEnabled) as? Bool ?? true

        let translationModeRawValue = UserDefaults.standard.string(forKey: Keys.translationMode) ?? "不翻译"
        self.translationMode = TranslationMode(rawValue: translationModeRawValue) ?? .none

        // 加载可用麦克风
        refreshAvailableMicrophones()
        
        // 应用外观设置
        applyAppearance()
    }
    
    // MARK: - Methods
    
    /// 刷新可用麦克风列表
    func refreshAvailableMicrophones() {
        var microphones: [MicrophoneInfo] = []
        
        // 获取默认输入设备
        let defaultDevice = AVCaptureDevice.default(for: .audio)
        let defaultID = defaultDevice?.uniqueID ?? ""
        
        microphones.append(MicrophoneInfo(
            id: "",
            name: "系统默认",
            isDefault: true
        ))
        
        // 枚举所有音频输入设备
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        
        for device in discoverySession.devices {
            microphones.append(MicrophoneInfo(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultID
            ))
        }
        
        DispatchQueue.main.async {
            self.availableMicrophones = microphones
        }
    }
    
    /// 获取当前选中的麦克风名称
    var selectedMicrophoneName: String {
        if selectedMicrophoneID.isEmpty {
            return "系统默认"
        }
        return availableMicrophones.first { $0.id == selectedMicrophoneID }?.name ?? "系统默认"
    }
    
    /// 获取选中的麦克风设备
    var selectedMicrophoneDevice: AVCaptureDevice? {
        if selectedMicrophoneID.isEmpty {
            return AVCaptureDevice.default(for: .audio)
        }
        return AVCaptureDevice(uniqueID: selectedMicrophoneID)
    }
    
    /// 应用外观设置
    func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearanceMode {
            case .system:
                NSApp.appearance = nil  // 使用系统默认
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    /// 重置所有设置为默认值
    func resetToDefaults() {
        appearanceMode = .system
        selectedMicrophoneID = ""
        selectedLanguage = .chinese
        isTextPolishEnabled = true
        isSoundEnabled = true
        refreshAvailableMicrophones()
    }
}
