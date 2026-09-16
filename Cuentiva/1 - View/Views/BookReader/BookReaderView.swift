import SwiftUI

struct BookReaderView: View {
    let book: Book
    @State private var viewModel = BookReaderViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let receipt = viewModel.receipt { CompletionView(receipt: receipt) }
            else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: book.kind == .movieScript ? 30 : 24) {
                            ForEach(Array(book.fullText.enumerated()), id: \.element.id) { index, sentence in
                                Group {
                                    if book.kind == .movieScript {
                                        ScriptDialogueRow(sentence: sentence,
                                            onRight: sentence.speaker != book.cast.first,
                                            spokenRange: viewModel.activeIndex == index ? viewModel.audio.spokenRange : nil)
                                    } else {
                                        StoryParagraphRow(sentence: sentence,
                                            spokenRange: viewModel.activeIndex == index ? viewModel.audio.spokenRange : nil)
                                    }
                                }.id(sentence.id)
                            }
                            InlineError(message: viewModel.error ?? viewModel.audio.error)
                            Button("Mark as read  ✓") { Task { await viewModel.finish(book) } }
                                .buttonStyle(.bordered).disabled(viewModel.busy).padding(.vertical, 20)
                        }.padding(24)
                    }
                    .onChange(of: viewModel.activeIndex) { _, index in
                        guard let index else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                            proxy.scrollTo(book.fullText[index].id, anchor: .center)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { viewModel.toggleAudio(book) } label: {
                            Image(systemName: viewModel.audioEnabled ? "speaker.wave.2" : "speaker.slash")
                        }
                        .accessibilityLabel(viewModel.audioEnabled ? "Turn off reading audio" : "Read aloud slowly")
                        .accessibilityValue(viewModel.audioEnabled ? "On" : "Off")
                    }
                }
            }
        }
        .navigationTitle(book.englishTitle).navigationBarTitleDisplayMode(.inline)
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .onAppear { viewModel.start(book) }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.stop() } }
    }
}
