import SwiftUI

struct DailyMatchSection: View {
    let books: [Book]
    let challenge: DailyMatchChallenge
    let onPlay: (Book) -> Void
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                DoubloonIcon(size: 44)
                Text(challenge.rewarded ? "Daily rewards complete" : "Earn doubloons")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
            }
            Text(challenge.rewarded ? "Three stories. Ninety pairs. A day well read." : "Keep those words with you. Complete a 30-pair game for each of today’s three books to earn 1 gold coin per game. Three games, three doubloons.")
                .foregroundStyle(theme.theme.muted)
            Text("\(challenge.completedBookIDs.count) of 3 games completed").font(.headline)
            ForEach(books) { book in
                Button { onPlay(book) } label: {
                    HStack(spacing: 16) {
                        BookCover(book: book, compact: true).frame(width: 140)
                            .scaleEffect(0.5).frame(width: 70, height: 110).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.englishTitle).font(.headline)
                            if challenge.paidBookIDs.contains(book.id) {
                                HStack(spacing: 6) {
                                    DoubloonIcon(size: 24).accessibilityHidden(true)
                                    Text(challenge.rewardedBookIDs?.contains(book.id) == true ? "1 doubloon earned" : "Reward collected")
                                        .font(.subheadline.weight(.semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                }.foregroundStyle(theme.theme.rewardGold)
                                Text("Play again").font(.subheadline).foregroundStyle(theme.theme.muted)
                            } else {
                                Text("30 pairs · Earn 1 doubloon")
                                    .font(.subheadline).foregroundStyle(theme.theme.muted)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: challenge.completedBookIDs.contains(book.id) ? "checkmark.circle.fill" : "play.circle.fill")
                            .font(.title).foregroundStyle(theme.theme.accent)
                    }.padding(16).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
        }.padding(.vertical, 12)
    }
}
