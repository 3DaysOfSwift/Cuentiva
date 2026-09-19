import SwiftUI
import StoreKit
struct CompletionView: View {
    let receipt: CompletionReceipt
    @State private var viewModel: CompletionViewModel
    @State private var contentVisible = false
    @State private var confettiStart: Date?
    @Environment(\.requestReview) private var requestReview
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
                VStack(spacing: 5) {
                    Text("\(viewModel.displayedTotal)").font(.system(size: 72, weight: .medium, design: .serif)).contentTransition(.numericText())
                    Text("BOOKS LEARNED").font(.caption.bold()).tracking(3)
                    Text(receipt.isNew ? "+1 to your collection" : "A familiar story, practiced again").font(.subheadline).foregroundStyle(theme.theme.accent)
                }
                if receipt.isNew {
                    Label("+1 doubloon", systemImage: "circle.circle.fill")
                        .font(.subheadline).foregroundStyle(theme.theme.rewardGold)
                }
                if receipt.offersChat {
                    Button {
                        viewModel.showingChat = true
                    } label: {
                        Label("Chat with \(receipt.book.storyteller.name) · 1 doubloon",
                              systemImage: "bubble.left.and.bubble.right")
                    }.buttonStyle(.bordered).tint(theme.theme.accent)
                    Text("Keep practising Spanish together. One doubloon covers this chat until you leave its screen.")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                        .multilineTextAlignment(.center)
                }
                if let gift = receipt.streakThemeGift {
                    Label("Your first 10-day streak!", systemImage: "flame.fill")
                        .font(.title2).foregroundStyle(theme.theme.accent)
                    Text("You’ve earned an exclusive VIP colour theme. A little gift for your persistence.")
                        .multilineTextAlignment(.center)
                    Button("Open my streak gift  →") { viewModel.showingThemePack = gift }
                        .buttonStyle(PrimaryButton())
                }
                if receipt.unlocksWriting {
                    Text("Five books.\nLook how far you’ve come.")
                        .font(.system(.largeTitle, design: .serif))
                        .multilineTextAlignment(.center)
                    Text("Five little adventures in Spanish. Every story is another step on your journey.")
                        .multilineTextAlignment(.center)
                } else if receipt.themePackGift != nil {
                    Text("\(receipt.total) books.\nA new gift awaits.")
                        .font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                    Text("You’ve earned a pack of five colour themes. Make your next chapter feel a little more yours.")
                        .multilineTextAlignment(.center)
                } else if receipt.celebratesHundredBooks {
                    Text("One hundred books.\nThat’s something to celebrate.")
                        .font(.system(.largeTitle, design: .serif))
                        .multilineTextAlignment(.center)
                    Text("You’ve made time to grow, discover new words and build new skills. Your curiosity and persistence deserve to be celebrated.")
                        .multilineTextAlignment(.center)
                    ReaderBadgesView(badges: ReaderBadge.allCases)
                    Text("Your badges are waiting in your reading stats. Here’s to your next chapter.")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                        .multilineTextAlignment(.center)
                } else {
                    Label(receipt.book.kind == .movieScript ? "SCRIPT COMPLETED" : "BOOK COMPLETED", systemImage: "checkmark.seal.fill").font(.caption.bold()).tracking(2)
                    Text("One more story.\nA little more you.").font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                    BookCover(book: receipt.book, completed: true, compact: true).frame(width: 155)
                    Text("\(receipt.book.fullText.count) \(receipt.book.unitName) · \(receipt.book.wordCount) Spanish words").font(.subheadline).foregroundStyle(theme.theme.muted)
                    if AppModel.shared.practice.allowed(receipt.book) {
                        Button("Your turn · read it in Spanish") { viewModel.showingPractice = true }
                        Button("Finish for today") { dismiss() }
                    }
                }
                BookDetailsView(book: receipt.book, completed: true)
            }.padding(28).frame(maxWidth: .infinity)
        }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Continue reading →", action: continueJourney)
                    .buttonStyle(PrimaryButton()).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(theme.theme.paper)
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
            .task(id: viewModel.hasCelebrated) {
                guard viewModel.hasCelebrated else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard !Task.isCancelled, !viewModel.showingPractice, !viewModel.showingChat else { return }
                if viewModel.takeReviewRequest(receipt) { requestReview() }
            }
            .fullScreenCover(isPresented: $viewModel.showingWritingMilestone, onDismiss: { dismiss() }) {
                WritingUnlockedView { viewModel.showingWritingMilestone = false }
            }
            .fullScreenCover(item: $viewModel.showingThemePack, onDismiss: { dismiss() }) { pack in
                ThemePackGiftView(pack: pack) { viewModel.showingThemePack = nil }
            }
            .navigationDestination(isPresented: $viewModel.showingChat) {
                ChatView(author: receipt.book.storyteller)
            }
            .onDisappear { confettiStart = nil }
            .fullScreenCover(isPresented: $viewModel.showingPractice, onDismiss: { dismiss() }) {
                NavigationStack { PracticeView(book: receipt.book, streak: receipt.streakCelebration) }
            }
    }

    private func continueJourney() {
        if viewModel.continueJourney(receipt, practiceAllowed: AppModel.shared.practice.allowed(receipt.book)) {
            dismiss()
        }
    }
}
