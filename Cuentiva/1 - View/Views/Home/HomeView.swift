//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var carouselWidth: CGFloat = 0
    @Namespace private var revivalCoinAnimation

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StreakBar(days: viewModel.week)
                if viewModel.hasVerbGift {
                    Button { viewModel.showingVerbGift = true } label: {
                        Label("Your day-20 gift · Verb Training", systemImage: "gift.fill")
                            .font(.title3.bold()).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }
                if viewModel.showingRevival {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.revivalPhase == .success {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(theme.theme.checkButtonForeground)
                                    .frame(width: 80, height: 80)
                                    .background(theme.theme.checkButtonBackground, in: Circle())
                                    .matchedGeometryEffect(id: "admission-coin", in: revivalCoinAnimation,
                                        properties: reduceMotion ? [] : .frame)
                                    .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                                Text("Revival paid").font(.headline)
                                DoubloonBalance(count: viewModel.revivalBalance)
                                    .contentTransition(.numericText())
                            }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
                        } else {
                            Label("Keep your streak going", systemImage: "flame.fill").font(.title2.bold())
                            Text("Missed yesterday? Revive your streak for 4 doubloons before today ends. You must also complete a book today.")
                                .foregroundStyle(theme.theme.muted)
                            DoubloonBalance(count: viewModel.revivalBalance)
                            if viewModel.revivalPhase == .slide || viewModel.revivalPhase == .paying {
                                SlideToStartView(confirm: viewModel.confirmRevivalPayment,
                                    coinAnimation: revivalCoinAnimation, title: "Slide to revive", cost: 4,
                                    paymentHint: "Pay 4 doubloons to revive yesterday. Complete a book today to keep your streak.")
                                    .id(viewModel.revivalAttempt)
                                    .disabled(viewModel.revivalPhase == .paying)
                                if viewModel.reviving { Text("Saving payment…").font(.caption) }
                            } else {
                                Button("Revive streak · 4 doubloons", action: viewModel.offerRevivalPayment)
                                    .buttonStyle(PrimaryButton())
                                    .disabled(viewModel.revivalBalance < 4)
                            }
                            if viewModel.revivalBalance < 4 {
                                Text("You need 4 doubloons. Earn more by reading or playing Match Pairs.").font(.caption)
                            }
                        }
                    }.padding().background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.85), value: viewModel.revivalPhase)
                    .sensoryFeedback(.success, trigger: viewModel.revivalSuccess)
                } else if viewModel.revivalNeedsBook {
                    Label("Complete a book today to restore your streak.", systemImage: "flame.fill")
                }
                InlineError(message: viewModel.revivalError)
                if let notice = viewModel.revivalNotice { Text(notice).foregroundStyle(theme.theme.accent) }
                Divider()
                if viewModel.dailyReads.count == 3 {
                    Label("Missing Words", systemImage: "puzzlepiece.extension.fill")
                        .font(.system(.largeTitle, design: .serif, weight: .medium))
                    DailyPracticeCard(completed: viewModel.dailyPracticeSession?.completed.count ?? 0,
                        rewarded: viewModel.dailyPracticeSession?.rewarded ?? false) { viewModel.showingDailyPractice = true }
                    Divider()
                }
                if let challenge = viewModel.dailyChallenge, viewModel.challengeBooks.count == 3 {
                    DailyMatchSection(books: viewModel.challengeBooks, challenge: challenge, onPlay: viewModel.playDailyGame)
                    Divider()
                }
                if !viewModel.dailyReads.isEmpty {
                    HStack(alignment: .top, spacing: 16) {
                        HStack {
                            if viewModel.dailyReadsCompleted {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.theme.accent)
                            }
                            Text(viewModel.dailyReadsCompleted ? "Today completed" : "Your next book")
                        }.font(.system(.largeTitle, design: .serif, weight: .medium))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(viewModel.dailyReadsCompleted ? "Today completed" : "Your next book")
                        Spacer(minLength: 0)
                        VStack(spacing: 2) {
                            Text("\(viewModel.total)")
                                .font(.system(.title, design: .serif, weight: .medium))
                                .monospacedDigit()
                            Text(viewModel.total == 1 ? "BOOK READ" : "BOOKS READ").font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.theme.muted)
                        }.accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(viewModel.total) \(viewModel.total == 1 ? "book" : "books") read in total")
                        PersonalStorytellerButton(feature: AppModel.shared.fantasy, size: 44)
                    }
                    dailyCarousel

                }
                if let book = viewModel.focusedRead {
                    Text(book.englishTitle).font(.title2.weight(.semibold))
                    Text(book.summary).font(.subheadline).foregroundStyle(theme.theme.muted)
                    Text("\(book.level) · \(book.fullText.count) \(book.unitName)")
                        .font(.caption).foregroundStyle(theme.theme.muted)
                    if viewModel.dailyReadsCompleted {
                        Text("Today’s reading is complete. Explore the Bookstore whenever you’re ready for another adventure.")
                            .font(.subheadline).foregroundStyle(theme.theme.muted)
                    }
                } else {
                    Text("New stories will appear here as the library grows.")
                        .foregroundStyle(theme.theme.muted)
                }
                if let notice = viewModel.dailyReadingNotice {
                    Text(notice).font(.caption).foregroundStyle(theme.theme.muted)
                }
                if let error = viewModel.dailyReadingError {
                    Text(error).font(.caption).foregroundStyle(theme.theme.muted)
                    Button("Retry") { Task { await viewModel.retryDailyReads() } }.disabled(viewModel.preparingDailyReads)
                }
                if viewModel.revisiting {
                    Text("A fresh look at your collection. Your reading progress is safely kept.")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                }
                Divider()
                CommunityAuthors(authors: viewModel.authors, horizontalInset: 23)
                Divider()
                Text("Three types of books").font(.system(.largeTitle, design: .serif, weight: .medium))
                Text("Stories, movie scripts, and information about verbs.")
                    .font(.subheadline).foregroundStyle(theme.theme.muted)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(viewModel.formatShowcase) { book in
                            Button { viewModel.selectedBook = book } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(book.kind == .movieScript ? "Scripts" : book.kind == .verbs ? "Verb training" : "Stories")
                                        .font(.headline)
                                    BookCover(book: book, completed: viewModel.completed(book), compact: true)
                                    Text(book.englishTitle).font(.subheadline.weight(.semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(width: 190, alignment: .topLeading)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 12)
                }.contentMargins(.horizontal, 23, for: .scrollContent)
                    .scrollIndicators(.hidden).padding(.horizontal, -23)
                Divider()
                if !viewModel.furtherRecommendations.isEmpty {
                    Text("More adventures for you").font(.system(.title2, design: .serif, weight: .medium))
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(viewModel.furtherRecommendations) { book in
                                Button { viewModel.selectedBook = book } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        BookCover(book: book, compact: true)
                                        Text(book.englishTitle).font(.headline)
                                        Text(book.summary).font(.caption).foregroundStyle(theme.theme.muted)
                                    }.frame(width: 190, alignment: .topLeading)
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 12)
                    }.contentMargins(.horizontal, 23, for: .scrollContent)
                        .scrollIndicators(.hidden).padding(.horizontal, -23)
                }
                Text(
                    "Open source • Original illustrative stories • Lightweight local AI-enabled library of Spanish stories & tales."
                ).font(.caption2).foregroundStyle(theme.theme.muted).padding(.top, 8)
            }.padding(.horizontal, 23).padding(.bottom, 30)
                .overlay(alignment: .top) {
                    HiddenProgressView()
                        .fixedSize(horizontal: false, vertical: true)
                        .alignmentGuide(.top) { dimensions in dimensions[.bottom] + 110 }
                }
        }.scrollBounceBehavior(.always, axes: .vertical)
            .background(theme.theme.paper).foregroundStyle(theme.theme.ink).navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "flame.fill")
                            Text("\(viewModel.streak)").monospacedDigit()
                        }
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.theme.accent)
                        .fixedSize()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(viewModel.streak) day streak")
                    }
                    .accessibilityHint("View your reading statistics")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }.accessibilityLabel("Settings")
                }
            }
            // Persist the daily selection after this screen is mounted, never from library loading.
            .task { await viewModel.prepareDailyReads() }
            .task(id: viewModel.refreshID) { await viewModel.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await viewModel.prepareDailyReads() } }
            }
            .fullScreenCover(isPresented: $viewModel.showingVerbGift) {
                NavigationStack {
                    VerbTrainingView()
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { viewModel.showingVerbGift = false } } }
                }
            }
            .fullScreenCover(isPresented: $viewModel.showingDailyPractice) {
                NavigationStack { DailyPracticeView(books: viewModel.dailyReads, feature: AppModel.shared.dailyPractice) }
            }
            .fullScreenCover(item: $viewModel.practiceBook) { book in
                NavigationStack { PracticeView(book: book, match: true, challengeDay: viewModel.challengeDay) }
            }
            .fullScreenCover(item: $viewModel.selectedBook, onDismiss: { Task { await viewModel.readingDismissed() } }) { book in
                NavigationStack { LessonView(book: book) }
            }
    }

    private var dailyCarousel: some View {
        ScrollViewReader { carousel in
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.dailyReads) { book in
                            Button {
                                viewModel.tapDailyRead(book)
                            } label: {
                                BookCover(book: book, completed: viewModel.completed(book), compact: true,
                                    showsReadingAction: viewModel.focusedRead?.id == book.id,
                                    readingCelebration: viewModel.readCelebration)
                                    .frame(width: 190)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                theme.theme.paper.opacity(
                                                    viewModel.focusedRead?.id == book.id ? 0 : 0.6)
                                            )
                                            .allowsHitTesting(false)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(theme.theme.accent, lineWidth: 3)
                                            .opacity(viewModel.focusedRead?.id == book.id ? 1 : 0)
                                            .allowsHitTesting(false)
                                    }
                                    .animation(
                                        reduceMotion ? nil : .easeInOut(duration: 0.2),
                                        value: viewModel.focusedRead?.id
                                    )
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .id(book.id)
                            .accessibilityAddTraits(viewModel.focusedRead?.id == book.id ? .isSelected : [])
                            .accessibilityLabel(
                                "\(book.englishTitle), by \(book.storytellerName)\(viewModel.completed(book) ? ", completed" : ", unread")")
                            .accessibilityHint(viewModel.focusedRead?.id == book.id ? "Open this book to read" : "Select this book")
                        }
                    }.scrollTargetLayout()
                    // Outside the book targets: scrolling here never selects a fourth book.
                    if viewModel.showTomorrowFooter {
                        TomorrowFooter()
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { carouselWidth = $0 }
            .contentMargins(.leading, 23, for: .scrollContent)
            // Leave enough room for the final book to reach the same leading position.
            .contentMargins(.trailing, max(23, carouselWidth - 23 - 190), for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $viewModel.focusedBookID, anchor: .leading)
            .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: viewModel.focusedBookID)
            .padding(.horizontal, -23)
            .task(id: carouselWidth) {
                // Let the measured trailing margin settle before changing scroll position.
                // A newer size cancels this alignment instead of scrolling during layout.
                guard carouselWidth > 0 else { return }
                await Task.yield()
                guard !Task.isCancelled, let id = viewModel.focusedRead?.id else { return }
                carousel.scrollTo(id, anchor: .leading)
            }
        }
    }
}
