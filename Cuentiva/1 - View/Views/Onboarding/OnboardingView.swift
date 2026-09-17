import SwiftUI
struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.completed { PaywallView() }
                else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            HStack { Label("CUENTIVA", systemImage: "book.pages").font(.subheadline.weight(.bold)).tracking(2); Spacer(); Text("YOUR FIRST CHAPTER").font(.system(size: 9, weight: .semibold, design: .monospaced)) }
                            Text("Every life has\na story.\nLearn through it.").font(.system(.largeTitle, design: .serif, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                            Text("Bring Spanish to life through a world of curious creatures and memorable stories.").font(.body).foregroundStyle(theme.theme.muted)
                            if let book = viewModel.book {
                                BookCover(book: book).frame(maxWidth: 250).rotationEffect(.degrees(-3)).frame(maxWidth: .infinity).padding(.vertical, 8)
                                HStack { Label("A1 · Beginner", systemImage: "leaf"); Spacer(); Text("\(book.sentences.count) sentences") }.font(.caption).foregroundStyle(theme.theme.muted)
                                Button("Read my first book  →") { viewModel.lesson = book }.buttonStyle(PrimaryButton())
                            }
                            Text("One complete book, free. No purchase needed to begin.").font(.footnote).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                            Button("Already a member? Restore purchases") { Task { await viewModel.restore() } }.font(.footnote).frame(maxWidth: .infinity)
                            InlineError(message: viewModel.error)
                        }.padding(26)
                    }
                }
            }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
                .fullScreenCover(item: $viewModel.lesson) { book in NavigationStack { LessonView(book: book) } }
        }
    }
}
