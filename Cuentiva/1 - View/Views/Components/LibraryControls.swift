import SwiftUI

struct LibraryControls: View {
    @Binding var format: BookFormat?
    @Binding var sort: BookSort
    @Environment(ThemeManager.self) private var theme
    let counts: [BookFormat: Int]
    var horizontalInset: CGFloat = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button { format = nil } label: {
                        Text("All types (\(counts.values.reduce(0, +)))")
                    }.buttonStyle(.bordered).tint(format == nil ? theme.theme.accent : theme.theme.muted)
                        .accessibilityAddTraits(format == nil ? .isSelected : [])
                    ForEach(BookFormat.allCases) { kind in
                        Button { format = kind } label: {
                            Text("\(kind == .movieScript ? "Scripts" : kind.title) (\(counts[kind, default: 0]))")
                        }.buttonStyle(.bordered).tint(format == kind ? theme.theme.accent : theme.theme.muted)
                            .accessibilityAddTraits(format == kind ? .isSelected : [])
                    }
                }.padding(.vertical, 4)
            }
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -horizontalInset)
            HStack {
                Text("Sort by").font(.caption)
                Picker("Sort books", selection: $sort) {
                    ForEach(BookSort.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.menu)
                Spacer()
            }
        }
    }
}
