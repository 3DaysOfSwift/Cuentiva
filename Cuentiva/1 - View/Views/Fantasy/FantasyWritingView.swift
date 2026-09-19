import SwiftUI

struct FantasyWritingView: View {
    @State private var model: FantasyWritingViewModel
    @State private var operation: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    private let feature: any FantasyFeature
    @Environment(ThemeManager.self) private var theme
    private let placeholder = "Once, I flew to Mexico and danced all night long in a beach festival. Tell the tale as if I were a turtle in a fantasy story."

    init(feature: any FantasyFeature) {
        self.feature = feature
        _model = State(initialValue: FantasyWritingViewModel(feature: feature))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your memory.\nA little magic.").font(.system(.largeTitle, design: .serif))
                ZStack(alignment: .topLeading) {
                    if model.memory.isEmpty {
                        Text(placeholder).foregroundStyle(theme.theme.muted)
                            .padding(.horizontal, 15).padding(.vertical, 18)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    TextEditor(text: $model.memory).frame(minHeight: 210).padding(10)
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("Your memory and fantasy idea")
                        .accessibilityHint(placeholder)
                }.background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 16))
                Button(model.busy ? "Imagining your tale…" : "Tell my tale") {
                    operation = Task { await model.generate() }
                }.buttonStyle(PrimaryButton()).disabled(model.busy || model.needsProfile || model.availabilityMessage != nil || model.memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Created privately with Apple Intelligence on this device.")
                    .font(.caption).foregroundStyle(theme.theme.muted)
                if model.needsProfile {
                    Button("Reveal my storyteller") { model.showingProfile = true }
                }
                if let message = model.availabilityMessage {
                    Text(message).font(.footnote).foregroundStyle(theme.theme.muted)
                    Button("Check again") { Task { await model.refreshAvailability() } }
                }
                InlineError(message: model.error)
                if let story = model.story {
                    Text(story.title).font(.system(.title, design: .serif))
                    Text(story.englishTitle).foregroundStyle(theme.theme.muted)
                    ForEach(Array(story.sentences.enumerated()), id: \.offset) { _, sentence in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sentence.spanish).font(.title3)
                            Text(sentence.english).foregroundStyle(theme.theme.muted)
                        }
                    }
                    Text("Saved privately on this device.").font(.caption).foregroundStyle(theme.theme.muted)
                    if model.storyIsPublished {
                        Label("In your Books library", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(theme.theme.accent)
                    } else {
                        Button("Publish to my library") { Task { await model.publish() } }
                            .buttonStyle(PrimaryButton())
                            .disabled(model.busy || model.nextPublicationDate != nil)
                        Text("One personal book every seven days. Only you can see it on this device.")
                            .font(.footnote).foregroundStyle(theme.theme.muted)
                        if let date = model.nextPublicationDate {
                            Text("Your next book can be published on \(date.formatted(date: .abbreviated, time: .shortened)).")
                                .font(.footnote).foregroundStyle(theme.theme.muted)
                        }
                    }
                    if let notice = model.publicationNotice {
                        Text(notice).font(.footnote).foregroundStyle(theme.theme.accent)
                    }
                }
                NavigationLink("My earlier drafts") { ContributionView() }
                    .font(.footnote)
                if !model.stories.isEmpty {
                    DisclosureGroup("My saved tales") {
                        ForEach(model.stories) { story in
                            Button(story.englishTitle) { model.story = story }.padding(.vertical, 8)
                        }
                    }
                }
            }.padding(25)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .navigationTitle("Write").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { model.showingProfile = true } label: {
                    if let creature = model.creature {
                        Image(creature.portrait).resizable().scaledToFill()
                            .frame(width: 44, height: 44).clipShape(Circle())
                            .overlay {
                                Circle().strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1)
                            }
                    } else {
                        Image(systemName: "person.crop.circle")
                            .frame(width: 44, height: 44)
                    }
                }.buttonStyle(.plain).accessibilityLabel("My storyteller")
            }.sharedBackgroundVisibility(.hidden) }
            .sheet(isPresented: $model.showingProfile) {
                StorytellerRevealView(feature: feature) { model.showingProfile = false }
            }
            .task { await model.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.refreshAvailability() } }
            }
            .onDisappear { operation?.cancel() }
    }
}
