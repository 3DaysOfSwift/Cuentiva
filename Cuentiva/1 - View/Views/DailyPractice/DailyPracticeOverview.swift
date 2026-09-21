//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct DailyPracticeOverview: View {
    let session: DailyPracticeSession
    let select: (DailyPracticeGame) -> Void
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var earned: Int { session.rewardedGames?.count ?? (session.rewarded ? 1 : 0) }
    private var finished: Bool { session.completed.count == 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(finished ? "You did it!" : "Missing words.")
                .font(.system(.largeTitle, design: .serif, weight: .medium))
            Text(finished ? "Today’s practice is complete. Look what you earned." : "One game, one doubloon. Make all three yours today.")
                .foregroundStyle(theme.theme.muted)
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    ForEach(0..<3) { index in
                        VStack(spacing: 8) {
                            if index < earned {
                                DoubloonIcon(size: 64)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Circle()
                                    .strokeBorder(theme.theme.rewardGold.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                    .overlay { Image(systemName: "plus").font(.title2).foregroundStyle(theme.theme.rewardGold) }
                                    .frame(width: 64, height: 64)
                            }
                            Text(index < earned ? "Earned" : "To earn")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(index < earned ? theme.theme.rewardGold : theme.theme.muted)
                        }
                    }
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(earned) of 3 doubloons earned today")
                Text("\(session.completed.count) of 3 games completed")
                    .font(.headline).contentTransition(.numericText())
                ProgressView(value: Double(session.completed.count), total: 3)
                    .tint(theme.theme.rewardGold)
                Text(finished ? "All done for today. Come back tomorrow!" : session.completed.isEmpty ? "Your first coin is one game away." : "\(3 - session.completed.count) more \(session.completed.count == 2 ? "game" : "games") to complete today’s set!")
                    .font(.subheadline).foregroundStyle(theme.theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(22).frame(maxWidth: .infinity)
            .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))

            ForEach(DailyPracticeGame.allCases) { game in
                let complete = session.completed.contains(game)
                let started = game == .missingWord ? session.missingIndex > 0 : game == .sentenceBuilder ? session.builderIndex > 0 || !session.builderTokens.isEmpty : session.trailScore > 0
                Button { select(game) } label: {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: game.symbol)
                                .font(.title).frame(width: 38)
                                .foregroundStyle(complete ? theme.theme.rewardGold : theme.theme.accent)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(game.title).font(.title3.bold())
                                if complete {
                                    Label("COMPLETED", systemImage: "checkmark.seal.fill")
                                        .font(.caption.bold()).foregroundStyle(theme.theme.rewardGold)
                                } else {
                                    Text(started ? "Keep going · Your coin is waiting" : "A fresh challenge · Earn 1 doubloon")
                                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        HStack(spacing: 12) {
                            if complete {
                                DoubloonIcon(size: 44)
                                Text(session.rewardedGames?.contains(game) == true ? "+1 doubloon earned" : "Reward collected")
                                    .font(.headline).foregroundStyle(theme.theme.rewardGold)
                                Spacer(minLength: 0)
                            } else {
                                Text(started ? "Continue game" : "Let’s play").font(.headline)
                                Spacer(minLength: 0)
                                Image(systemName: "play.circle.fill").font(.title)
                            }
                        }
                    }
                    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 24).fill(theme.theme.surface)
                            .overlay {
                                if complete { RoundedRectangle(cornerRadius: 24).fill(theme.theme.rewardGold.opacity(0.12)) }
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(complete ? theme.theme.rewardGold : theme.theme.accent.opacity(0.2), lineWidth: complete ? 2 : 1)
                    }
                }.buttonStyle(.plain)
                    .accessibilityHint(complete ? "View your completed practice reward" : "Play to earn one doubloon")
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: session.completed)
    }
}
