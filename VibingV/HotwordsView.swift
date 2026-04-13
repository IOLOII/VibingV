import SwiftUI
import AppKit

struct HotwordsView: View {
    @State private var hotwords: [String] = [
        "OpenClaw", "VibeVoice", "Vibing", "VibingV"
    ]
    @State private var newHotword: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("热词")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    // 热词增强提示卡片
                    enhancementCard

                    // 添加热词输入框
                    addHotwordRow

                    // 热词列表
                    hotwordsList
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // 热词增强提示卡片
    var enhancementCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 20))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("热词增强")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text("添加专有名词、术语、人名等热词可以提高语音识别准确率。自动热词由截图分析自动提取。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(15)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // 添加热词行
    var addHotwordRow: some View {
        HStack(spacing: 12) {
            TextField("输入新热词...", text: $newHotword)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Button(action: addHotword) {
                Text("添加")
                    .font(.system(size: 14))
                    .foregroundColor(newHotword.isEmpty ? .secondary : .blue)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(newHotword.isEmpty)
        }
    }

    // 热词列表
    var hotwordsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(hotwords.enumerated()), id: \.element) { index, word in
                HStack {
                    Text(word)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        removeHotword(at: index)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))

                if index < hotwords.count - 1 {
                    Divider()
                        .padding(.leading, 15)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // 添加热词
    func addHotword() {
        guard !newHotword.isEmpty else { return }
        hotwords.append(newHotword)
        newHotword = ""
    }

    // 删除热词
    func removeHotword(at index: Int) {
        hotwords.remove(at: index)
    }
}

struct HotwordsView_Previews: PreviewProvider {
    static var previews: some View {
        HotwordsView()
    }
}
