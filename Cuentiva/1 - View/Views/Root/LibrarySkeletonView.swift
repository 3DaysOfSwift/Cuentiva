import SwiftUI

/// Layout-only placeholders: no books, balances or access are assumed before loading.
struct LibrarySkeletonView: View {
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        TabView {
            Tab("Discover", systemImage: "books.vertical") {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            RoundedRectangle(cornerRadius: 20).fill(theme.theme.muted.opacity(0.10)).frame(height: 40)
                            HStack {
                                Label("Day streak", systemImage: "flame.fill").font(.headline)
                                Spacer()
                                ForEach(0..<7) { _ in Circle().fill(theme.theme.muted.opacity(0.12)).frame(width: 10, height: 10) }
                            }.redacted(reason: .placeholder).padding(.vertical, 18)
                            Divider()
                            Text("A little Spanish.\nA new perspective.").font(.system(.largeTitle, design: .serif, weight: .medium))
                            Text("Small stories. Ideas for everyday life.").font(.subheadline).foregroundStyle(theme.theme.muted)
                            RoundedRectangle(cornerRadius: 20).fill(theme.theme.muted.opacity(0.10)).frame(height: 32)
                            RoundedRectangle(cornerRadius: 20).fill(theme.theme.muted.opacity(0.10)).frame(height: 32)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 20)], spacing: 26) {
                                ForEach(0..<4) { _ in
                                    VStack(alignment: .leading, spacing: 12) {
                                        RoundedRectangle(cornerRadius: 8).fill(theme.theme.accent.opacity(0.10)).frame(height: 220)
                                        RoundedRectangle(cornerRadius: 4).fill(theme.theme.muted.opacity(0.12)).frame(height: 16)
                                        RoundedRectangle(cornerRadius: 4).fill(theme.theme.muted.opacity(0.08)).frame(width: 95, height: 12)
                                    }
                                }
                            }
                        }.padding(.horizontal, 23).padding(.bottom, 30)
                    }.background(theme.theme.paper)
                        .navigationTitle("Cuentiva").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Image(systemName: "gearshape").foregroundStyle(theme.theme.ink) } }
                }
            }
            Tab("Nearby", systemImage: "location") { Color.clear }
            Tab("Completed", systemImage: "checkmark.seal") { Color.clear }
            Tab("Contribute", systemImage: "square.and.pencil") { Color.clear }
        }.allowsHitTesting(false).accessibilityElement(children: .ignore).accessibilityLabel("Loading your library")
    }
}
