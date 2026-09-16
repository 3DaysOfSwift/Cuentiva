import SwiftUI
struct ContributionView: View {
    @State private var viewModel = ContributionViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text("Your life could be\nsomeone’s next lesson.").font(.system(.largeTitle, design: .serif)); Spacer() }
                Text("\(viewModel.count) / 5 books contributed").font(.headline).foregroundStyle(theme.theme.accent)
                Text("Write about a person, a place, or a moment that stayed with you. Fiction is welcome too.").foregroundStyle(theme.theme.muted)
                if viewModel.eligible {
                    TextField("Your story’s title", text: $viewModel.draft.title).font(.title3).padding().background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                    TextEditor(text: $viewModel.draft.spanish).frame(minHeight: 210).padding(10).scrollContentBackground(.hidden).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Your story in Spanish")
                    HStack { Button("Preview") { viewModel.preview.toggle() }; Spacer(); Button("Coaching prompts") { viewModel.coach() } }
                    if viewModel.preview { VStack(alignment: .leading, spacing: 10) { Text(viewModel.draft.title).font(.title2); Text(viewModel.draft.spanish) }.padding().background(theme.theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12)) }
                    if !viewModel.tips.isEmpty {
                        Text("DEMO COACH · GUIDED PROMPTS").font(.caption.bold())
                        ForEach(viewModel.tips, id: \.self) { Text($0).font(.subheadline) }
                        Text("These are local prompts, not an AI review. A future AI editor will suggest changes for you to accept; it will not write your story for you.").font(.caption).foregroundStyle(theme.theme.muted)
                    }
                    Button("Save draft") { Task { await viewModel.save(submit: false) } }.buttonStyle(.bordered).disabled(viewModel.busy)
                    Button("Submit for review · demo") { Task { await viewModel.save(submit: true) } }.buttonStyle(PrimaryButton()).disabled(viewModel.busy)
                    if let notice = viewModel.notice { Text(notice).font(.footnote).foregroundStyle(theme.theme.accent) }
                    Text("Local demo only. Review and publishing are not connected. Only accepted, published books count toward your goal.").font(.caption).foregroundStyle(theme.theme.muted)
                    if !viewModel.drafts.isEmpty { Text("YOUR DRAFTS").font(.caption.bold()); ForEach(viewModel.drafts) { draft in Button { viewModel.edit(draft) } label: { HStack { Text(draft.title); Spacer(); Text(draft.status).font(.caption) } }.padding(.vertical, 8) } }
                } else {
                    Label("Complete your first book to try contributing.", systemImage: "lock.fill").padding()
                }
                Text("Demo unlock: one completed book. This is a product demonstration, not a language proficiency assessment.").font(.caption2).foregroundStyle(theme.theme.muted)
                InlineError(message: viewModel.error)
            }.padding(25)
        }.background(theme.theme.paper).navigationTitle("Contribute").navigationBarTitleDisplayMode(.inline).task { await viewModel.load() }
    }
}
