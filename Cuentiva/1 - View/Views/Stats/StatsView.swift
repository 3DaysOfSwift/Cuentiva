//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI
import Charts

struct StatsView: View {
    @State private var viewModel = StatsViewModel()
    @Environment(ThemeManager.self) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var streakSize = 76

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "flame.fill")
                        Text("\(viewModel.streak)").monospacedDigit()
                    }
                    .font(.system(size: streakSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.theme.accent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(viewModel.streak) day streak")
                    Text(viewModel.streak == 1 ? "Day streak" : "Days in a row")
                        .font(.title3.weight(.semibold))
                    Text(viewModel.streak == 0 ? "Your next chapter can start a new streak." : "A little practice, day after day.")
                        .foregroundStyle(theme.theme.muted)
                        .multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.top, 16)

                VStack(alignment: .leading, spacing: 16) {
                    Text("This week").font(.headline)
                    StreakBar(days: viewModel.week)
                }
                if !viewModel.readerBadges.isEmpty {
                    ReaderBadgesView(badges: viewModel.readerBadges)
                }
                Divider()
                VStack(spacing: 22) {
                    stat(viewModel.booksRead == 1 ? "Book read" : "Books read", value: "\(viewModel.booksRead)", symbol: "books.vertical")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Doubloons available").font(.headline)
                        DoubloonBalance(count: viewModel.doubloons, size: 40).font(.title2)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    stat("Days practised", value: "\(viewModel.practiceDays)", symbol: "calendar")
                    stat("Days practised in the last 30 days", value: "\(viewModel.daysPractised(inLast: 30))", symbol: "calendar")
                    stat("Days practised in the last 365 days", value: "\(viewModel.daysPractised(inLast: 365))", symbol: "calendar")
                    stat("Distinct Spanish words encountered", value: "\(viewModel.exposedWords)", symbol: "text.book.closed")
                    if !viewModel.exposureHistory.isEmpty {
                        Chart(viewModel.exposureHistory) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Words", point.count))
                            PointMark(x: .value("Date", point.date), y: .value("Words", point.count))
                        }
                        .foregroundStyle(theme.theme.accent)
                        .chartYScale(domain: 0...max(10, viewModel.exposedWords))
                        .frame(height: 200)
                        .accessibilityLabel("Word exposure over time")
                    }
                    Text("Exposure counts distinct written words you have encountered, not words mastered. Chart history begins when tracking is available; earlier reading is included in your starting total.")
                        .font(.caption).foregroundStyle(theme.theme.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("First recorded practice", systemImage: "sunrise").font(.headline)
                        if let date = viewModel.firstPractice {
                            Text(date, format: .dateTime.day().month(.wide).year())
                                .foregroundStyle(theme.theme.muted)
                        } else {
                            Text("Your first practice is still ahead of you.")
                                .foregroundStyle(theme.theme.muted)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
            }.padding(.horizontal, 23).padding(.bottom, 30)
        }
        .background(theme.theme.paper)
        .foregroundStyle(theme.theme.ink)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.headline)
            Text(value).font(.system(.largeTitle, design: .serif)).monospacedDigit()
                .foregroundStyle(theme.theme.accent)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
