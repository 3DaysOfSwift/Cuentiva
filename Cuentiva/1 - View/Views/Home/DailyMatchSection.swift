//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct DailyMatchSection: View {
    let books: [Book]
    let challenge: DailyMatchChallenge
    let onPlay: (Book) -> Void
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                let completed = challenge.completedBookIDs.contains(book.id)
                Button { onPlay(book) } label: {
                    HStack(spacing: 16) {
                        BookCover(book: book, compact: true).frame(width: 140)
                            .scaleEffect(0.5).frame(width: 70, height: 110).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.englishTitle).font(.headline)
                            if completed {
                                Label("COMPLETED", systemImage: "checkmark.seal.fill")
                                    .font(.caption.bold()).foregroundStyle(theme.theme.rewardGold)
                            }
                            if challenge.paidBookIDs.contains(book.id) {
                                HStack(spacing: 6) {
                                    DoubloonIcon(size: 36).accessibilityHidden(true)
                                    Text(challenge.rewardedBookIDs?.contains(book.id) == true ? "+1 doubloon earned" : "Reward collected")
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
                        if !completed {
                            Image(systemName: "play.circle.fill")
                                .font(.title).foregroundStyle(theme.theme.accent)
                        }
                    }.padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 20).fill(theme.theme.surface)
                                .overlay {
                                    if completed {
                                        RoundedRectangle(cornerRadius: 20).fill(theme.theme.rewardGold.opacity(0.12))
                                    }
                                }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(completed ? theme.theme.rewardGold : theme.theme.accent.opacity(0.2), lineWidth: completed ? 2 : 1)
                        }
                }.buttonStyle(.plain)
                    .accessibilityHint(completed ? "Play again without earning another daily reward" : "Complete 30 pairs to earn one doubloon")
            }
        }.padding(.vertical, 12)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: challenge.completedBookIDs)
    }
}
