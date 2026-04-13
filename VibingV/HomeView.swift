import SwiftUI
import AppKit

struct HomeView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var aiSettings = AISettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题栏
                headerCard

                // 统计卡片
                statsRow

                // 录音热键设置
                hotkeySettingsCard

                // AI 润色设置
                aiPolishSettingsCard

                // 功能开关
                toggleSettingsCard

                // 其他设置
                generalSettingsCard
            }
            .padding(30)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // 标题栏
    var headerCard: some View {
        HStack {
            HStack(spacing: 15) {
                // Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color.black, Color.gray],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)

                    Text("V")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(.white)
                }

                Text("VibingV – Just Speak It!")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("准备开始录音")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .cardBackground()
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // 统计行
    var statsRow: some View {
        HStack(spacing: 20) {
            StatCard(
                icon: "🎤",
                value: "\(settings.todayWords)",
                unit: "words",
                label: "今日字数"
            )

            StatCard(
                icon: "📝",
                value: formatNumber(settings.totalWords),
                unit: "words",
                label: "总字数"
            )
        }
    }

    // 录音热键设置
    var hotkeySettingsCard: some View {
        VStack(spacing: 0) {
            SettingRow {
                VStack(alignment: .leading, spacing: 3) {
                    Text("录音热键")
                        .font(.system(size: 15, weight: .medium))
                    Text("长按 = 按住模式 · 短按 = 切换模式")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                KeyBadge(text: "⌥ Right Option")
            }

            Divider()

            SettingRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text("翻译")
                        .font(.system(size: 15, weight: .medium))
                    if !aiSettings.isConfigurationValid {
                        Text("需要配置 AI 才能使用翻译")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                TranslationModePicker()
            }

            Divider()

            SettingRow {
                Text("取消录音")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                KeyBadge(text: "Esc")
            }
        }
        .cardBackground()
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // 功能开关
    var toggleSettingsCard: some View {
        VStack(spacing: 0) {
            SettingRow {
                Text("音效反馈")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Toggle("", isOn: $settings.isSoundEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .labelsHidden()
            }
        }
        .cardBackground()
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // AI 润色设置
    var aiPolishSettingsCard: some View {
        VStack(spacing: 0) {
            // AI 润色开关
            SettingRow {
                HStack(spacing: 8) {
                    Text("AI 文本润色")
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                Spacer()
                Toggle("", isOn: $aiSettings.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
            }

            if aiSettings.isEnabled {
                Divider()

                // AI 提供商选择
                SettingRow {
                    Text("AI 提供商")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    AIProviderPicker()
                }

                Divider()

                // API Key 输入
                SettingRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.system(size: 15, weight: .medium))
                        if aiSettings.isConfigurationValid {
                            Text("配置有效 ✓")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        } else {
                            Text("请配置 API Key")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                    SecureField("sk-...", text: $aiSettings.apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }

                // 高级设置（仅在自定义模式下显示）
                if aiSettings.selectedProvider == AITextPolishService.AIProvider.custom.rawValue {
                    Divider()

                    SettingRow {
                        Text("Base URL")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        TextField("https://...", text: $aiSettings.baseURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                    }

                    Divider()

                    SettingRow {
                        Text("模型名称")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        TextField("模型名称", text: $aiSettings.modelName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                    }
                }

                Divider()

                // 重置按钮
                SettingRow {
                    Button(action: {
                        aiSettings.resetToDefaults()
                    }) {
                        Text("重置为默认值")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
            }
        }
        .cardBackground()
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // 其他设置
    var generalSettingsCard: some View {
        VStack(spacing: 0) {
            // 语言设置
            SettingRow {
                Text("语言")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                LanguagePicker()
            }

            Divider()

            // 外观设置
            SettingRow {
                Text("外观")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                AppearancePicker()
            }

            Divider()

            // 麦克风设置
            SettingRow {
                Text("麦克风")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                MicrophonePicker()
            }
        }
        .cardBackground()
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // 数字格式化
    func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Translation Mode Picker
struct TranslationModePicker: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var aiSettings = AISettingsStore.shared

    var body: some View {
        Menu {
            ForEach(SettingsStore.TranslationMode.allCases) { mode in
                Button(action: {
                    settings.translationMode = mode
                }) {
                    HStack {
                        Text(mode.displayName)
                            .font(.system(size: 14))
                        if settings.translationMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SelectBox(
                text: settings.translationMode.displayName,
                showIcon: true
            )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 120)
        .disabled(!aiSettings.isConfigurationValid)
    }
}

// MARK: - Language Picker
struct LanguagePicker: View {
    var body: some View {
        Menu {
            ForEach(SettingsStore.Language.allCases, id: \.rawValue) { language in
                Button(action: {
                    SettingsStore.shared.selectedLanguage = language
                }) {
                    HStack {
                        Text(language.rawValue)
                        if SettingsStore.shared.selectedLanguage == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SelectBox(text: SettingsStore.shared.selectedLanguage.rawValue, showIcon: true)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 120)
    }
}

// MARK: - Appearance Picker
struct AppearancePicker: View {
    var body: some View {
        Menu {
            ForEach(SettingsStore.AppearanceMode.allCases, id: \.rawValue) { mode in
                Button(action: {
                    SettingsStore.shared.appearanceMode = mode
                }) {
                    HStack {
                        Text(mode.title)
                        if SettingsStore.shared.appearanceMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SelectBox(text: SettingsStore.shared.appearanceMode.title, showIcon: true)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 120)
    }
}

// MARK: - Microphone Picker
struct MicrophonePicker: View {
    var body: some View {
        Menu {
            Button(action: {
                SettingsStore.shared.refreshAvailableMicrophones()
            }) {
                Label("刷新麦克风列表", systemImage: "arrow.clockwise")
            }

            Divider()

            ForEach(SettingsStore.shared.availableMicrophones) { mic in
                Button(action: {
                    SettingsStore.shared.selectedMicrophoneID = mic.id
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mic.name)
                            if mic.isDefault {
                                Text("系统默认")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if SettingsStore.shared.selectedMicrophoneID == mic.id || (mic.id.isEmpty && SettingsStore.shared.selectedMicrophoneID.isEmpty) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SelectBox(text: SettingsStore.shared.selectedMicrophoneName, showIcon: true)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 150)
    }
}

// MARK: - Adaptive Card Background
extension View {
    func cardBackground() -> some View {
        self.background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - SettingsStore Extension for Stats
extension SettingsStore {
    // 今日字数统计（临时用固定值，之后可以从历史记录计算）
    var todayWords: Int {
        return 0
    }

    // 总字数统计（临时用固定值）
    var totalWords: Int {
        return 4448
    }
}

// 统计卡片组件
struct StatCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String

    var body: some View {
        HStack(spacing: 15) {
            Text(icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 32, weight: .semibold))
                    Text(unit)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(25)
        .cardBackground()
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// 设置行容器
struct SettingRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
}

// 快捷键标签
struct KeyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(6)
    }
}

// 选择框
struct SelectBox: View {
    let text: String
    let showIcon: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            if showIcon {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - AI Provider Picker
struct AIProviderPicker: View {
    @StateObject private var aiSettings = AISettingsStore.shared

    var body: some View {
        Menu {
            ForEach(AITextPolishService.AIProvider.allCases) { provider in
                Button(action: {
                    aiSettings.selectedProvider = provider.rawValue
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.rawValue)
                                .font(.system(size: 14))
                            Text(provider.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        if aiSettings.selectedProvider == provider.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SelectBox(text: aiSettings.selectedProvider, showIcon: true)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 150)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
