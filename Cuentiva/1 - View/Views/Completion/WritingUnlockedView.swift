//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct WritingUnlockedView: View {
    let onContinue: () -> Void
    @State private var model = WritingUnlockedViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if model.stage == .character {
                StorytellerRevealView(feature: AppModel.shared.fantasy, onContinue: onContinue)
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        if model.stage == .announcement {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 120, weight: .light))
                                .foregroundStyle(theme.theme.accent)
                                .frame(maxWidth: .infinity)
                                .accessibilityHidden(true)
                            Text("\(ReadingMilestones.writingBookCount) books completed")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(theme.theme.accent)
                            Text("A free gift.\nJust for you.")
                                .font(.system(.largeTitle, design: .serif))
                                .accessibilityAddTraits(.isHeader)
                            Text("You’ve made time to learn through \(ReadingMilestones.writingBookCount) complete stories. That’s worth celebrating! Your free gift is a character of your own to accompany your reading adventures.")
                            Button("Open my gift  →") { model.next() }
                                .buttonStyle(PrimaryButton())
                        } else {
                            MysteryStorytellerView()
                            Text("You’re invited to\nbecome a storyteller.")
                                .font(.system(.largeTitle, design: .serif))
                                .accessibilityAddTraits(.isHeader)
                            Text("Your free gift: your own storyteller character.")
                                .font(.headline).foregroundStyle(theme.theme.accent)
                            Text("Reveal your character, choose a name, and make Cuentiva feel like yours.")
                            Text("Your character will appear beside your reading progress. You can even make it your app icon.")
                            Text("Keep reading to discover more adventures and unlock Spanish conversation practice.")
                            Button("Select  →") { model.next() }
                                .buttonStyle(PrimaryButton())
                        }
                    }.multilineTextAlignment(.center).padding(28).padding(.top, 36)
                        .frame(maxWidth: .infinity)
                        .id(model.stage)
                        .transition(.opacity)
                }
            }
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: model.stage)
    }
}
