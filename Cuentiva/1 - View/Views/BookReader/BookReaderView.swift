//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct BookReaderView: View {
    let book: Book
    let chapterTwo: Bool
    let onChapterFinished: ((Int) async -> Void)?
    let onFinish: (() -> Void)?
    @State private var viewModel: BookReaderViewModel
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(book: Book, chapterTwo: Bool = false, onChapterFinished: ((Int) async -> Void)? = nil,
         onFinish: (() -> Void)? = nil) {
        self.book = book; self.chapterTwo = chapterTwo
        self.onChapterFinished = onChapterFinished; self.onFinish = onFinish
        _viewModel = State(initialValue: BookReaderViewModel(chapterTwo: chapterTwo))
    }
    private func highlighted(_ sentence: Sentence, at index: Int) -> Text {
        var value = AttributedString(sentence.spanish)
        if viewModel.activeIndex == index, let spokenRange = viewModel.highlightedRange,
           let range = Range(spokenRange, in: value) {
            value[range].foregroundColor = theme.theme.accent
            value[range].font = .system(.title2, design: .serif, weight: .bold)
        }
        return Text(value)
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if !chapterTwo {
                        VStack(spacing: 24) {
                            BookCover(book: book, compact: false).frame(maxWidth: 280)
                            Text(book.englishTitle).font(.system(.largeTitle, design: .serif))
                            Text("Tap a sentence whenever you need its English meaning.")
                                .font(.subheadline).foregroundStyle(theme.theme.muted)
                        }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                    ForEach(Array(viewModel.passages(book).enumerated()), id: \.element.id) { index, sentence in
                        if let title = viewModel.chapterTitle(book, at: index) {
                            Text(title)
                                .font(.system(.title, design: .serif)).padding(.top, 20)
                                .accessibilityAddTraits(.isHeader)
                        }
                        Group {
                            if chapterTwo {
                                if book.kind == .movieScript {
                                    ScriptDialogueRow(sentence: sentence, onRight: sentence.speaker != book.cast.first,
                                        spokenRange: viewModel.activeIndex == index ? viewModel.audio.spokenRange : nil)
                                } else {
                                    StoryParagraphRow(sentence: sentence,
                                        spokenRange: viewModel.activeIndex == index ? viewModel.audio.spokenRange : nil)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    if let speaker = sentence.speaker {
                                        Text(speaker).font(.headline).foregroundStyle(theme.theme.accent)
                                    }
                                    Button {
                                        if viewModel.revealed.contains(sentence.id) { viewModel.revealed.remove(sentence.id) }
                                        else { viewModel.revealed.insert(sentence.id) }
                                    } label: {
                                        highlighted(sentence, at: index).font(.system(.title2, design: .serif)).lineSpacing(7)
                                            .foregroundStyle(theme.theme.ink)
                                            .frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                                            .environment(\.locale, Locale(identifier: "es-ES"))
                                    }.buttonStyle(.plain).accessibilityHint("Tap to reveal or hide English")
                                    if viewModel.revealed.contains(sentence.id) {
                                        Text(sentence.english).foregroundStyle(theme.theme.muted)
                                    }
                                }
                            }
                        }.id(sentence.id)
                    }
                    if !chapterTwo {
                        VStack(spacing: 20) {
                            Text("End of book").font(.system(.largeTitle, design: .serif))
                            AuthorPortrait(author: book.storyteller, size: 100)
                            Text("Written by \(book.storytellerName)").font(.title3)
                        }.frame(maxWidth: .infinity).padding(.vertical, 50)
                    }
                    InlineError(message: viewModel.error ?? viewModel.audio.error)
                    Button(chapterTwo ? "Continue to Chapter 3 →" : "Finish reading ✓") {
                        if chapterTwo {
                            Task {
                                if let position = await viewModel.finishChapter(book) { await onChapterFinished?(position) }
                            }
                        } else if let onFinish { onFinish() }
                        else { dismiss() }
                    }.buttonStyle(PrimaryButton()).disabled(viewModel.busy)
                }.padding(24)
            }
            .onChange(of: viewModel.activeIndex) { _, index in
                guard let index, viewModel.passages(book).indices.contains(index) else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    proxy.scrollTo(viewModel.passages(book)[index].id, anchor: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !chapterTwo {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button(viewModel.isPlaying ? "Pause" : "Begin") { viewModel.toggleGuide(book) }
                            .buttonStyle(PrimaryButton())
                        Button { viewModel.toggleAudio(book) } label: {
                            Image(systemName: viewModel.audioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.title2).frame(minWidth: 44, minHeight: 44)
                        }.accessibilityLabel(viewModel.audioEnabled ? "Turn audio off" : "Turn audio on")
                    }
                    if !viewModel.audioEnabled {
                        HStack {
                            Image(systemName: "speedometer").accessibilityHidden(true)
                            Slider(value: $viewModel.wordsPerMinute, in: 80...240, step: 10)
                                .accessibilityLabel("Reading pace, words per minute")
                            Text("\(Int(viewModel.wordsPerMinute)) wpm").font(.caption).monospacedDigit()
                        }
                    }
                }.padding(16).background(theme.theme.paper).dockedAreaBorder()
            }
        }
        .toolbar {
            if chapterTwo {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.toggleAudio(book) } label: {
                        Image(systemName: viewModel.audioEnabled ? "speaker.wave.2" : "speaker.slash")
                    }.accessibilityLabel(viewModel.audioEnabled ? "Pause reading guide" : "Start reading guide")
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
