import SwiftUI
struct CompletionView: View {
    let receipt: CompletionReceipt
    @State private var viewModel: CompletionViewModel
    @State private var showPractice = false
    @State private var contentVisible = false
    @State private var confettiStart: Date?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var theme
    init(receipt: CompletionReceipt) {
        self.receipt = receipt
        // Seed the previous total before the first rendered frame, not in onAppear.
        _viewModel = State(initialValue: CompletionViewModel(receipt: receipt))
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                Label(receipt.book.kind == .movieScript ? "SCRIPT COMPLETED" : "BOOK COMPLETED", systemImage: "checkmark.seal.fill").font(.caption.bold()).tracking(2)
                Text("One more story.\nA little more you.").font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                BookCover(book: receipt.book, completed: true, compact: true).frame(width: 155)
                Text(receipt.book.englishTitle).font(.title3.weight(.semibold))
                Text("\(receipt.book.fullText.count) \(receipt.book.unitName) · \(receipt.book.wordCount) Spanish words").font(.subheadline).foregroundStyle(theme.theme.muted)
                VStack(spacing: 5) {
                    Text("\(viewModel.displayedTotal)").font(.system(size: 72, weight: .medium, design: .serif)).contentTransition(.numericText())
                    Text("BOOKS LEARNED").font(.caption.bold()).tracking(3)
                    Text(receipt.isNew ? "+1 to your collection" : "A familiar story, practiced again").font(.subheadline).foregroundStyle(theme.theme.accent)
                }
                Button("Continue  →") { if receipt.streakCelebration != nil && AppModel.shared.practice.allowed(receipt.book) { showPractice = true } else { dismiss() } }.buttonStyle(PrimaryButton())
                if AppModel.shared.practice.allowed(receipt.book) {
                    Button("Your turn · read it in Spanish") { showPractice = true }
                    Button("Finish for today") { dismiss() }
                }
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
            .task(id: receipt.id) {
                viewModel.prepare(receipt)
                guard !viewModel.hasCelebrated else { contentVisible = true; return }
                if reduceMotion {
                    contentVisible = true
                    viewModel.celebrate(receipt)
                    return
                }
                // Give a newly inserted screen a rendered starting state. On a cold
                // appearance, animating immediately can collapse into its first frame.
                contentVisible = false
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withAnimation(.easeOut(duration: 0.4), completionCriteria: .removed) {
                        contentVisible = true
                    } completion: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled else { return }
                // Let the reader see the old number after the entrance has finished.
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                guard !Task.isCancelled, !viewModel.hasCelebrated else { return }
                withAnimation(reduceMotion ? nil : .spring(duration: 0.7)) {
                    viewModel.celebrate(receipt)
                }
                if !reduceMotion { confettiStart = .now }
                do { try await Task.sleep(for: .seconds(ConfettiBurst.duration)) } catch { return }
                confettiStart = nil
            }
            .onChange(of: reduceMotion) { _, enabled in
                if enabled {
                    contentVisible = true
                    confettiStart = nil
                    viewModel.celebrate(receipt)
                }
            }
            .onDisappear { confettiStart = nil }
            .fullScreenCover(isPresented: $showPractice, onDismiss: { dismiss() }) {
                NavigationStack { PracticeView(book: receipt.book, streak: receipt.streakCelebration) }
            }
    }
}
