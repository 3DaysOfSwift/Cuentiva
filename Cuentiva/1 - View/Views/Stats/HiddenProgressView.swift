import SwiftUI

/// Lives above the scroll content; the normal scroll bounce reveals it.
struct HiddenProgressView: View {
    @State private var viewModel = StatsViewModel()
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 110, weight: .semibold))
                .foregroundStyle(theme.theme.accent)
            Text("\(viewModel.streak) day streak")
                .font(.system(.title2, design: .serif, weight: .medium))
            HStack {
                Text("\(viewModel.booksRead) \(viewModel.booksRead == 1 ? "book" : "books") read")
                DoubloonBalance(count: viewModel.doubloons, size: 20)
            }
                .font(.subheadline)
            Text("\(viewModel.practiceDays) days practised")
                .font(.subheadline)
            if let date = viewModel.firstPractice {
                Text("First recorded practice: \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
            } else {
                Text("Your first practice is still ahead of you.").font(.caption)
            }
        }
        .foregroundStyle(theme.theme.ink)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 23)
        .padding(.bottom, 20)
        .allowsHitTesting(false)
        // The same information is accessible through the visible streak button.
        .accessibilityHidden(true)
    }
}
