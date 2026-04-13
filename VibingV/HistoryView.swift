import SwiftUI
import AppKit

struct HistoryItem: Identifiable {
    let id = UUID()
    let time: String
    let duration: String
    let content: String
    let date: String
}

struct HistoryView: View {
    @State private var saveHistoryDuration: String = "永远"
    @State private var showingClearAlert: Bool = false

    // 示例历史数据
    @State private var historyItems: [HistoryItem] = [
        HistoryItem(
            time: "03:58",
            duration: "8.5s",
            content: "你好。",
            date: "2026-03-30"
        ),
        HistoryItem(
            time: "03:57",
            duration: "8.6s",
            content: "你现在看见什么了？",
            date: "2026-03-30"
        ),
        HistoryItem(
            time: "03:56",
            duration: "41.6s",
            content: "你可以做什么事情吗？",
            date: "2026-03-30"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("历史记录")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    showingClearAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("清除")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    // 保存历史设置卡片
                    saveHistoryCard

                    // 历史记录列表
                    historyList
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $showingClearAlert) {
            Alert(
                title: Text("清除历史记录"),
                message: Text("确定要清除所有历史记录吗？此操作不可撤销。"),
                primaryButton: .destructive(Text("清除")) {
                    historyItems.removeAll()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // 保存历史设置卡片
    var saveHistoryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "display")
                .font(.system(size: 20))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("保存历史")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text("您希望在设备上保存口述历史多久？")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 下拉选择
            Menu {
                Button("永远") {
                    saveHistoryDuration = "永远"
                }
                Button("30天") {
                    saveHistoryDuration = "30天"
                }
                Button("7天") {
                    saveHistoryDuration = "7天"
                }
                Button("1天") {
                    saveHistoryDuration = "1天"
                }
            } label: {
                HStack(spacing: 8) {
                    Text(saveHistoryDuration)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
        .padding(15)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // 历史记录列表
    var historyList: some View {
        VStack(spacing: 0) {
            // 日期分组
            let groupedItems = groupByDate(items: historyItems)

            ForEach(groupedItems.keys.sorted(by: >), id: \.self) { date in
                VStack(alignment: .leading, spacing: 0) {
                    // 日期标题
                    Text(date)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)

                    // 该日期下的记录
                    ForEach(groupedItems[date]!) { item in
                        HistoryRow(item: item)

                        if item.id != groupedItems[date]!.last?.id {
                            Divider()
                                .padding(.leading, 15)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // 按日期分组
    func groupByDate(items: [HistoryItem]) -> [String: [HistoryItem]] {
        Dictionary(grouping: items, by: { $0.date })
    }
}

// 历史记录行
struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 时间和时长
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.time)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(item.duration)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(width: 50)

            // 内容
            Text(item.content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // 复制按钮
            Button(action: {
                // 复制到剪贴板
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.content, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
