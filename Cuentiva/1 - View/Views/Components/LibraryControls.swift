import SwiftUI

struct LibraryControls: View {
    @Binding var format: BookFormat?
    @Binding var sort: BookSort
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Book type", selection: $format) {
                Text("All types").tag(BookFormat?.none)
                ForEach(BookFormat.allCases) { Text($0.title).tag(Optional($0)) }
            }.pickerStyle(.segmented)
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
