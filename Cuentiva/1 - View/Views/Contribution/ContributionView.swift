import SwiftUI

/// A read-only archive preserves writing from the retired submission experiment.
struct ContributionView: View {
    @State private var viewModel = ContributionViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("Your earlier drafts").font(.system(.largeTitle, design: .serif))
                Text("Your earlier writing is kept here privately on this device. Create new tales from the Write screen.")
                    .foregroundStyle(theme.theme.muted)
                ForEach(viewModel.drafts) { draft in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(draft.title.isEmpty ? "Untitled draft" : draft.title)
                            .font(.system(.title2, design: .serif))
                        Text(draft.spanish).textSelection(.enabled)
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                InlineError(message: viewModel.error)
            }.padding(25)
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .navigationTitle("Earlier drafts").navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
