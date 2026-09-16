import SwiftUI

struct ScriptReaderView: View {
    let book: Book
    @State private var viewModel = ScriptReaderViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let receipt = viewModel.receipt { CompletionView(receipt: receipt) }
            else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 30) {
                            ForEach(Array(book.fullScript.enumerated()), id: \.element.id) { index, sentence in
                                ScriptDialogueRow(sentence: sentence,
                                    onRight: sentence.speaker != book.cast.first,
                                    spokenRange: viewModel.activeIndex == index ? viewModel.audio.spokenRange : nil)
                                    .id(sentence.id)
                            }
                            InlineError(message: viewModel.error ?? viewModel.audio.error)
                            Button("Mark as read  ✓") { Task { await viewModel.finish(book) } }
                                .buttonStyle(.bordered).disabled(viewModel.busy).padding(.vertical, 20)
                        }.padding(24)
                    }
                    .onChange(of: viewModel.activeIndex) { _, index in
                        guard let index else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                            proxy.scrollTo(book.fullScript[index].id, anchor: .center)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { viewModel.toggleAudio(book) } label: {
                            Image(systemName: viewModel.audioEnabled ? "speaker.wave.2" : "speaker.slash")
                        }
                        .accessibilityLabel(viewModel.audioEnabled ? "Turn off script audio" : "Play script slowly")
                        .accessibilityValue(viewModel.audioEnabled ? "On" : "Off")
                    }
                }
            }
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .onAppear { viewModel.start(book) }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.stop() } }
    }
}
