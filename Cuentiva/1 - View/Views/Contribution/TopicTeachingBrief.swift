import SwiftUI

struct TopicTeachingBrief: View {
    let topic: TopicRequest
    @Bindable var viewModel: ContributionViewModel
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR TOPIC REQUEST").font(.caption.bold()).foregroundStyle(theme.theme.accent)
            Text(topic.title).font(.system(.title2, design: .serif))
            Text(topic.brief).font(.subheadline)
            DisclosureGroup("Teaching brief and scope") { Text(topic.scope).font(.subheadline).padding(.top, 8) }
            Text("Teach it in your own words").font(.headline)
            Text("Explain the meaning and why your examples are useful. Write this reader-facing note in English; write the story below in Spanish.")
                .font(.footnote).foregroundStyle(theme.theme.muted)
            TextField("Help a new learner understand…", text: $viewModel.teachingNote, axis: .vertical)
                .lineLimit(3...8).autocorrectionDisabled().padding(12)
                .background(theme.theme.paper, in: RoundedRectangle(cornerRadius: 10))
            if !topic.forms.isEmpty {
                Text("Use each form twice in meaningful sentences").font(.subheadline.bold())
                let counts = topic.occurrences(in: viewModel.draft.spanish)
                ForEach(Array(topic.forms.enumerated()), id: \.element) { index, form in
                    Label("\(form) · \(counts[index]) / 2 occurrences", systemImage: counts[index] >= 2 ? "checkmark.circle" : "circle")
                        .font(.footnote).foregroundStyle(counts[index] >= 2 ? theme.theme.accent : theme.theme.muted)
                }
                Text("Counts find exact words, including accents. They cannot judge grammar, meaning, or whether two examples are genuinely different. A reviewer must check those.")
                    .font(.caption).foregroundStyle(theme.theme.muted)
            }
            Text("Author’s self-review").font(.subheadline.bold())
            ForEach(topic.requirements, id: \.self) { requirement in
                Toggle(requirement, isOn: Binding(get: { viewModel.checked(requirement) }, set: { viewModel.setChecked(requirement, value: $0) }))
                    .font(.footnote)
            }
            Text("Your checklist prepares a submission; it does not approve it or complete the topic.")
                .font(.caption).foregroundStyle(theme.theme.muted)
        }.padding(18).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
