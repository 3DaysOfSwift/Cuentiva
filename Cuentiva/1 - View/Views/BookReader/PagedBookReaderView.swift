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
                    pageContent(page, size: geometry.size).tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .task(id: "\(geometry.size):\(textScale):\(viewModel.showsEnglish)") {
                viewModel.layout(book: book, size: geometry.size, scale: textScale)
            }
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .navigationTitle(book.englishTitle).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button(viewModel.showsEnglish ? "Hide English" : "Show English") { viewModel.showsEnglish.toggle() }
                    .font(.subheadline.weight(.semibold))
            }
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
        }
    }

    private func pageContent(_ page: PagedBookReaderViewModel.Page, size: CGSize) -> some View {
        // ViewThatFits preserves large, accessible type on ordinary pages while
        // accommodating an unusually long single passage on a finite book page.
        ViewThatFits(in: .vertical) {
            passageColumn(page, factor: 1)
            passageColumn(page, factor: 0.85)
            passageColumn(page, factor: 0.7)
            passageColumn(page, factor: 0.55)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 28).padding(.vertical, 24)
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .leading) {
            LinearGradient(colors: [theme.theme.ink.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 12).allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func passageColumn(_ page: PagedBookReaderViewModel.Page, factor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: viewModel.passageSpacing) {
            ForEach(page.passages) { passage in
                VStack(alignment: .leading, spacing: viewModel.translationSpacing) {
                    if let speaker = passage.speaker {
                        Text(speaker).font(.system(size: viewModel.englishSize * textScale * factor, weight: .semibold))
                            .foregroundStyle(theme.theme.accent)
                    }
                    Text(passage.spanish)
                        .font(.system(size: viewModel.spanishSize * textScale * factor, design: .serif))
                        .environment(\.locale, Locale(identifier: "es-MX"))
                    if viewModel.showsEnglish {
                        Text(passage.english)
                            .font(.system(size: viewModel.englishSize * textScale * factor))
                            .foregroundStyle(theme.theme.muted)
                            .environment(\.locale, Locale(identifier: "en-US"))
                    }
                }.fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func turnPage(_ offset: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { viewModel.move(offset) }
    }
}
