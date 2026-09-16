import SwiftUI
struct CompletionView: View {
    let receipt: CompletionReceipt
    @State private var viewModel = CompletionViewModel()
    @State private var contentVisible = false
    @State private var isOnScreen = false
    @State private var confettiStart: Date?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Label("BOOK COMPLETED", systemImage: "checkmark.seal.fill").font(.caption.bold()).tracking(2)
                Text("One more story.\nA little more you.").font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                BookCover(book: receipt.book, completed: true, compact: true).frame(width: 155)
                Text(receipt.book.englishTitle).font(.title3.weight(.semibold))
                Text("\(receipt.book.sentences.count) sentences · \(receipt.book.wordCount) Spanish words").font(.subheadline).foregroundStyle(theme.theme.muted)
                VStack(spacing: 5) {
                    Text("\(viewModel.displayedTotal)").font(.system(size: 72, weight: .medium, design: .serif)).contentTransition(.numericText())
                    Text("BOOKS LEARNED").font(.caption.bold()).tracking(3)
                    Text(receipt.isNew ? "+1 to your collection" : "A familiar story, practiced again").font(.subheadline).foregroundStyle(theme.theme.accent)
                }
                Button("Continue  →") { dismiss() }.buttonStyle(PrimaryButton())
            }.padding(28).frame(maxWidth: .infinity)
        }
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 18)
            .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .overlay {
                if let confettiStart, !reduceMotion {
                    ConfettiBurst(start: confettiStart)
                        .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .onAppear {
                isOnScreen = true
                viewModel.prepare(receipt)
            }
            .task {
                guard !contentVisible else { return }
                if reduceMotion {
                    contentVisible = true
                    viewModel.celebrate(receipt)
                } else {
                    // Completion is inserted into an already visible lesson. Its own
                    // SwiftUI animation completion is the reliable appearance signal.
                    withAnimation(.easeOut(duration: 0.4), completionCriteria: .removed) {
                        contentVisible = true
                    } completion: {
                        guard isOnScreen else { return }
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.7)) {
                            viewModel.celebrate(receipt)
                        }
                        if !reduceMotion { confettiStart = .now }
                    }
                }
            }
            .task(id: confettiStart) {
                guard confettiStart != nil else { return }
                do { try await Task.sleep(for: .seconds(ConfettiBurst.duration)) } catch { return }
                confettiStart = nil
            }
            .onDisappear {
                isOnScreen = false
                confettiStart = nil
            }
    }
}
