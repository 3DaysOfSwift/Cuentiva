//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct DailyWelcomeView: View {
    let viewModel: DailyWelcomeViewModel
    let ready: Bool
    let onBegin: () -> Void
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 96)).foregroundStyle(theme.theme.accent)
                .accessibilityHidden(true)
            Text("\(viewModel.welcome.streak)")
                .font(.system(size: 72, weight: .medium, design: .serif)).monospacedDigit()
            Text("Day streak")
                .font(.title2)
            Text(viewModel.welcome.streak == 0
                 ? "A little story is a lovely place to begin."
                 : "One little story at a time. Look how far you’ve come.")
                .foregroundStyle(theme.theme.muted)
            Spacer()
            InlineError(message: viewModel.error)
            Button(viewModel.buttonTitle, action: onBegin)
                .buttonStyle(PrimaryButton())
                .opacity(viewModel.buttonVisible ? 1 : 0)
                .disabled(!viewModel.buttonVisible || !ready || viewModel.saving)
                .accessibilityHidden(!viewModel.buttonVisible)
        }
        .multilineTextAlignment(.center).padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
        .task { await viewModel.revealButton() }
    }
}
