//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

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
                            HStack { Label("CUENTIVA", systemImage: "book.pages").font(.subheadline.weight(.bold)).tracking(2); Spacer(); Text("LITTLE STORIES ABOUT LIFE").font(.system(size: 9, weight: .semibold, design: .monospaced)) }
                            Image("StorytellerPipa").resizable().scaledToFit()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 32))
                                .frame(maxWidth: .infinity).accessibilityLabel("Pipa, your travelling companion")
                            Text("¡Hola! I’m Pipa.").font(.system(.largeTitle, design: .serif, weight: .medium))
                            Text("Welcome to Cuentiva. Your life has stories. Let’s learn to tell them in Spanish.")
                                .font(.title2).fixedSize(horizontal: false, vertical: true)
                            Text("Spanish has a whole world of words to meet. Don’t hide from the unfamiliar ones—say hello! Meeting them again in real sentences helps them feel familiar.")
                                .foregroundStyle(theme.theme.muted)
                            Text("Our storytellers are always returning with tales of their wildest adventures. Read along, listen and speak. One little tale at a time, practise the words to talk about your own life.")
                                .foregroundStyle(theme.theme.muted)
                            if viewModel.book != nil {
                                Text("Join me for a coffee and a journey through the Americas. I’ve saved my first story for you.")
                                    .font(.headline)
                            }
                            if let book = viewModel.book {
                                BookCover(book: book).frame(maxWidth: 250).rotationEffect(.degrees(-3)).frame(maxWidth: .infinity).padding(.vertical, 8)
                                BookDetailsView(book: book)
                            }
                            Text("One complete book, free. Counts towards today’s 3 recommended books.").font(.footnote).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                            Button("Already a member? Restore purchases") { Task { await viewModel.restore() } }.font(.footnote).frame(maxWidth: .infinity)
                            InlineError(message: viewModel.error)
                        }.padding(26)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if let book = viewModel.book {
                            VStack(spacing: 8) {
                                if let error = viewModel.preparationError {
                                    InlineError(message: error)
                                    Button("Try preparing again") { Task { await viewModel.prepareProgress() } }
                                        .disabled(viewModel.preparing)
                                }
                                Button(action: viewModel.startReading) {
                                    VStack(spacing: 4) {
                                        Text(viewModel.progressReady ? "Read Pipa's story  →" : "Preparing your story…")
                                        Text("Told by \(book.storytellerName)").font(.caption)
                                    }.frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PrimaryButton())
                                .disabled(!viewModel.canStartReading)
                            }
                            .padding(.horizontal, 26).padding(.vertical, 12)
                            .background(theme.theme.paper)
                            .dockedAreaBorder()
                        }
                    }
                }
            }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
                .task { await viewModel.prepareProgress() }
                .fullScreenCover(item: $viewModel.lesson) { book in NavigationStack { LessonView(book: book) } }
        }
    }
}
