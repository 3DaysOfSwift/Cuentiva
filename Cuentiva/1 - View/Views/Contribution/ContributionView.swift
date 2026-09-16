import SwiftUI
struct ContributionView: View {
    @State private var viewModel: ContributionViewModel
    init(nearby: Bool = false) {
        let model = ContributionViewModel(); model.attachLocation = nearby
        _viewModel = State(initialValue: model)
    }
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text("Your life could be\nsomeone’s next lesson.").font(.system(.largeTitle, design: .serif)); Spacer() }
                Text("\(viewModel.count) / 5 books contributed").font(.headline).foregroundStyle(theme.theme.accent)
                Text("Write about a person, a place, or a moment that stayed with you. Fiction is welcome too.").foregroundStyle(theme.theme.muted)
                if viewModel.eligible {
                    HStack {
                        Button("Write freely") { Task { await viewModel.freestyle() } }.buttonStyle(.bordered)
                        Button("Topic requests") { viewModel.browsingTopics = true }.buttonStyle(.bordered)
                    }.disabled(viewModel.busy)
                    if viewModel.browsingTopics { TopicRequestBoard(viewModel: viewModel) }
                    else {
                    if let topic = viewModel.selectedTopic { TopicTeachingBrief(topic: topic, viewModel: viewModel) }

                    TextField("Your story’s title in Spanish", text: $viewModel.draft.title)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .font(.title3).padding().background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    ZStack(alignment: .topLeading) {
                        if viewModel.draft.spanish.isEmpty {
                            Text("Write your story in Spanish…")
                                .foregroundStyle(theme.theme.muted)
                                .padding(.horizontal, 15).padding(.vertical, 18)
                                .allowsHitTesting(false).accessibilityHidden(true)
                        }
                        TextEditor(text: $viewModel.draft.spanish)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .frame(minHeight: 210).padding(10)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel("Your story in Spanish")
                    }.background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    Text("Autocorrection is off, so your words stay yours. Remember accents, capitals, and punctuation.")
                        .font(.footnote).foregroundStyle(theme.theme.muted)
                    Label("Add a Spanish keyboard in Settings for easy access to ñ, accents, ¿ and ¡.", systemImage: "keyboard")
                        .font(.footnote).foregroundStyle(theme.theme.muted)
                    HStack { Button("Preview") { viewModel.preview.toggle() }; Spacer(); Button("Coaching prompts") { viewModel.coach() } }
                    if viewModel.preview { VStack(alignment: .leading, spacing: 10) { Text(viewModel.draft.title).font(.title2); if let note = viewModel.draft.teachingNote { Text(note).font(.subheadline) }; Text(viewModel.draft.spanish) }.padding().background(theme.theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12)) }
                    if !viewModel.tips.isEmpty {
                        Text("DEMO COACH · GUIDED PROMPTS").font(.caption.bold())
                        ForEach(viewModel.tips, id: \.self) { Text($0).font(.subheadline) }
                        Text("These are local prompts, not an AI review. A future AI editor will suggest changes for you to accept; it will not write your story for you.").font(.caption).foregroundStyle(theme.theme.muted)
                    }
                    if let place = viewModel.draft.submissionLocation {
                        Label("Submitted near \(place.placeName) · location locked", systemImage: "mappin.and.ellipse").font(.subheadline)
                    } else {
                        Toggle("Leave this story here", isOn: $viewModel.attachLocation)
                        Text("On submission, confirm your current place. Its coordinates stay fixed; readers see only the approximate place name. You can also submit without a location.").font(.caption).foregroundStyle(theme.theme.muted)
                    }
                    Button("Save draft") { Task { await viewModel.save(submit: false) } }.buttonStyle(.bordered).disabled(viewModel.busy)
                    Button("Submit for review · demo") { Task { await viewModel.requestSubmission() } }.buttonStyle(PrimaryButton()).disabled(viewModel.busy)
                    if viewModel.drafts.contains(where: { $0.id == viewModel.draft.id }) {
                        Button("Delete local story and location", role: .destructive) { viewModel.confirmingRemoval = true }.disabled(viewModel.busy)
                    }
                    if let notice = viewModel.notice { Text(notice).font(.footnote).foregroundStyle(theme.theme.accent) }
                    Text("Local demo only. Review and publishing are not connected. Only accepted, published books count toward your goal.").font(.caption).foregroundStyle(theme.theme.muted)
                    if !viewModel.drafts.isEmpty { Text("YOUR DRAFTS").font(.caption.bold()); ForEach(viewModel.drafts) { draft in Button { viewModel.edit(draft) } label: { HStack { Text(draft.title); Spacer(); Text(draft.status).font(.caption) } }.padding(.vertical, 8) } }
                    }
                } else {
                    Label("Complete your first book to try contributing.", systemImage: "lock.fill").padding()
                }
                Text("Demo unlock: one completed book. This is a product demonstration, not a language proficiency assessment.").font(.caption2).foregroundStyle(theme.theme.muted)
                InlineError(message: viewModel.error)
            }.padding(25)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("Contribute").navigationBarTitleDisplayMode(.inline).task { await viewModel.load() }
            .alert("Delete this local story?", isPresented: $viewModel.confirmingRemoval) {
                Button("Delete", role: .destructive) { Task { await viewModel.removeDraft() } }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Its text and submission location will be removed from this device. This cannot be undone.") }
            .confirmationDialog("Leave this story near \(viewModel.locationToConfirm?.placeName ?? "here")?", isPresented: $viewModel.confirmingLocation, titleVisibility: .visible) {
                Button("Confirm location and submit") { Task { await viewModel.confirmSubmission() } }
                Button("Cancel", role: .cancel) { viewModel.locationToConfirm = nil }
            } message: {
                Text("This submission location stays fixed. Only the approximate place name is shown to readers. In this demo, the story and its location stay on this device pending review.")
            }
    }
}
