import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var selectedTab: SidebarItem = .home

    enum SidebarItem: String, CaseIterable {
        case home = "首页"
        case hotwords = "热词"
        case history = "历史记录"

        var icon: String {
            switch self {
            case .home: return "house"
            case .hotwords: return "calendar"
            case .history: return "clock"
            }
        }
    }

    var body: some View {
        NavigationView {
            // 侧边栏
            VStack(spacing: 0) {
                List(SidebarItem.allCases, id: \.self) { item in
                    SidebarRow(
                        icon: item.icon,
                        title: item.rawValue,
                        isSelected: selectedTab == item
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTab = item
                    }
                    // .onHover { ishover in
                    //     print(ishover)
                    //     if ishover {
                    //         selectedTab = item
                    //     }
                    // }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200)

                Spacer()

                // 底部版本信息
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("VibingV by")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("IOLOII")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                if let url = URL(string: "https://github.com/IOLOII/VibingV") {
                                    openURL(url)
                                }
                            }
                    }
                    Text("v0.1.0")
                        .font(.caption)
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Text("Inspired by")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Vibing")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                if let url = URL(string: "https://github.com/VibingJustSpeakIt/Vibing") {
                                    openURL(url)
                                }
                            }
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(minWidth: 200)

            // 主内容区
            switch selectedTab {
            case .home:
                HomeView()
            case .hotwords:
                HotwordsView()
            case .history:
                HistoryView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

// 侧边栏行组件
struct SidebarRow: View {
    let icon: String
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(title)
                .font(.system(size: 15))
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
        .foregroundColor(isSelected ? .blue : .primary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct SideBarRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SidebarRow(icon: "house", title: "home", isSelected: false)

            SidebarRow(icon: "house", title: "home", isSelected: true)
        }

    }


}
