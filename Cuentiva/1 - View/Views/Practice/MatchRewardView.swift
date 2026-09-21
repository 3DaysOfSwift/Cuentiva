//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct MatchRewardView: View {
    @State private var model: MatchRewardViewModel
    let onContinue: () -> Void
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(receipt: MatchRewardReceipt, onContinue: @escaping () -> Void) {
        _model = State(initialValue: MatchRewardViewModel(receipt: receipt))
        self.onContinue = onContinue
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                DoubloonIcon(size: 140)
                    .scaleEffect(model.revealed || reduceMotion ? 1 : 0.85)
                    .accessibilityHidden(true)
                Text("You earned 1 doubloon!")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                Text("Thirty pairs matched. One more gold coin for your adventures.")
                    .foregroundStyle(theme.theme.muted)
                VStack(spacing: 12) {
                    Text("Your gold coins").font(.headline)
                    DoubloonBalance(count: model.displayedBalance, size: 44)
                        .font(.largeTitle.bold())
                        .contentTransition(.numericText())
                        .foregroundStyle(theme.theme.rewardGold)
                    Text("\(model.receipt.previousBalance) → \(model.receipt.balance) doubloons")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                    Label("Saved to your balance", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(theme.theme.accent)
                }
                .padding(24).frame(maxWidth: .infinity)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
            }
            .multilineTextAlignment(.center).padding(.horizontal, 24).padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Continue", action: onContinue).buttonStyle(PrimaryButton())
                .padding(24).background(theme.theme.paper).dockedAreaBorder()
        }
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .task {
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.3)) { model.reveal() }
        }
    }
}
