import SwiftUI

struct TopicRequestBoard: View {
    @Bindable var viewModel: ContributionViewModel
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Help write what’s missing.").font(.system(.title2, design: .serif))
            Text("Editorial priorities · local demo. These are suggested needs, not live community demand. Only reviewed, accepted books fill the coverage target.")
                .font(.footnote).foregroundStyle(theme.theme.muted)
            TextField("Find a topic", text: $viewModel.topicQuery).textFieldStyle(.roundedBorder)
            Toggle("Outstanding only", isOn: $viewModel.outstandingOnly)
            if viewModel.topics.isEmpty { Text("No topics match this filter.").foregroundStyle(theme.theme.muted) }
            ForEach(viewModel.topics) { topic in
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text(topic.category).font(.caption); Spacer(); Text(topic.priority).font(.caption.bold()) }
                    Text(topic.title).font(.headline)
                    Label(topic.coverageLabel, systemImage: topic.covered ? "checkmark.seal" : "text.badge.plus").font(.subheadline)
                    ProgressView(value: Double(min(topic.reviewedBooks, topic.target)), total: Double(max(1, topic.target)))
                    Text("\(topic.reviewedBooks) / \(topic.target) reviewed books · \(topic.demoExamples) demo examples")
                        .font(.caption).foregroundStyle(theme.theme.muted)
                    Text(topic.brief).font(.subheadline)
                    if let status = viewModel.topicStatus(topic) { Text("Your contribution: \(status)").font(.caption).foregroundStyle(theme.theme.accent) }
                    Button(viewModel.topicStatus(topic) == nil ? "Pick this request" : "Continue my draft") {
                        Task { await viewModel.choose(topic) }
                    }.buttonStyle(.bordered).disabled(viewModel.busy || topic.covered)
                }.padding(18).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
