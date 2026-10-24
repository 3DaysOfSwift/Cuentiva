// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.

import SwiftUI

struct PagedBookReaderView: View {
    let book: Book
    @State private var viewModel = PagedBookReaderViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $viewModel.page) {
                ForEach(viewModel.pages) { page in
                    pageContent(page, size: geometry.size)
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded { toggleControls() })
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityAction(named: Text(viewModel.controlsVisible ? "Hide reading controls" : "Show reading controls")) {
                toggleControls()
            }
            .task(id: "\(geometry.size):\(textScale):\(viewModel.showsEnglish)") {
                viewModel.layout(book: book, size: geometry.size, scale: textScale)
            }
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .navigationTitle(book.englishTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            // Keep every item mounted so hiding the chrome cannot change the safe area.
            ToolbarItem(placement: .principal) {
                Text(book.englishTitle).font(.headline).lineLimit(1)
                    .opacity(viewModel.controlsVisible ? 1 : 0)
                    .accessibilityHidden(!viewModel.controlsVisible)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) { dismiss() } label: {
                    Image(systemName: "xmark")
                }.accessibilityLabel("Close reader")
                    .opacity(viewModel.controlsVisible ? 1 : 0)
                    .disabled(!viewModel.controlsVisible)
                    .accessibilityHidden(!viewModel.controlsVisible)
            }.sharedBackgroundVisibility(viewModel.controlsVisible ? .visible : .hidden)
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.showsEnglish ? "Hide English" : "Show English") { viewModel.showsEnglish.toggle() }
                    .font(.subheadline.weight(.semibold))
                    .opacity(viewModel.controlsVisible ? 1 : 0)
                    .disabled(!viewModel.controlsVisible)
                    .accessibilityHidden(!viewModel.controlsVisible)
            }.sharedBackgroundVisibility(viewModel.controlsVisible ? .visible : .hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                InlineError(message: viewModel.error)
                HStack {
                    Button { turnPage(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.disabled(viewModel.page == 0).accessibilityLabel("Previous page")
                    Spacer()
                    Text(viewModel.pages.isEmpty ? "" : "\(viewModel.page + 1) of \(viewModel.pages.count)")
                        .font(.system(.footnote, design: .serif)).monospacedDigit()
                        .accessibilityLabel("Page \(viewModel.page + 1) of \(viewModel.pages.count)")
                    Spacer()
                    Button { turnPage(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }.disabled(viewModel.page >= viewModel.pages.count - 1).accessibilityLabel("Next page")
                }
            }.padding(.horizontal, 28).padding(.vertical, 8)
                .background(theme.theme.paper).dockedAreaBorder()
                // Retain the space so toggling controls never repaginates the book.
                .opacity(viewModel.controlsVisible ? 1 : 0)
                .allowsHitTesting(viewModel.controlsVisible)
                .accessibilityHidden(!viewModel.controlsVisible)
        }
    }

    private func pageContent(_ page: PagedBookReaderViewModel.Page, size: CGSize) -> some View {
        lineColumn(page)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 28).padding(.vertical, 24)
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .leading) {
            LinearGradient(colors: [theme.theme.ink.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 12).allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func lineColumn(_ page: PagedBookReaderViewModel.Page) -> some View {
        VStack(alignment: .leading, spacing: viewModel.rowSpacing) {
            ForEach(Array(page.lines.enumerated()), id: \.element.id) { index, line in
                VStack(alignment: .leading, spacing: viewModel.translationSpacing) {
                    if let speaker = line.speaker {
                        Text(speaker).font(Font(viewModel.englishFont).weight(.semibold))
                            .foregroundStyle(theme.theme.accent)
                    }
                    if !line.spanish.isEmpty {
                        Text(line.spanish).font(Font(viewModel.spanishFont))
                            .frame(height: ceil(viewModel.spanishFont.lineHeight), alignment: .leading)
                            .environment(\.locale, Locale(identifier: "es-MX"))
                    }
                    if viewModel.showsEnglish, !line.english.isEmpty {
                        Text(line.english).font(Font(viewModel.englishFont))
                            .frame(height: ceil(viewModel.englishFont.lineHeight), alignment: .leading)
                            .foregroundStyle(theme.theme.muted)
                            .environment(\.locale, Locale(identifier: "en-US"))
                    }
                }
                .lineLimit(1)
                .padding(.top, index > 0 && line.startsSentence ? viewModel.sentenceSpacing : 0)
                .accessibilityElement(children: .combine)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleControls() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { viewModel.toggleControls() }
    }

    private func turnPage(_ offset: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { viewModel.move(offset) }
    }
}
