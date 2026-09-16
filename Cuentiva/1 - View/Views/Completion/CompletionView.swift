import SwiftUI
struct CompletionView: View {
    let receipt: CompletionReceipt
    @State private var viewModel = CompletionViewModel()
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
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .task { viewModel.prepare(receipt); if !reduceMotion { try? await Task.sleep(for: .milliseconds(450)) }; withAnimation(reduceMotion ? nil : .spring(duration: 0.7)) { viewModel.celebrate(receipt) } }
    }
}
