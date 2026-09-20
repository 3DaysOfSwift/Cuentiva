import SwiftUI

struct VerbWorkoutCelebration: View {
    let summary: VerbWorkoutSummary
    let busy: Bool
    let error: String?
    let continueWorkout: () -> Void
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 110)).foregroundStyle(theme.theme.rewardGold)
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                    .accessibilityHidden(true)
                Text("Verb training complete!")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                Text("You finished all 12 reps. Well done!").foregroundStyle(theme.theme.muted)
                VStack(spacing: 16) {
                    Text("\(summary.verbs.count) \(summary.verbs.count == 1 ? "verb" : "verbs") practised")
                        .font(.title2.bold())
                    Text(summary.verbs.joined(separator: " · "))
                        .font(.title3).foregroundStyle(theme.theme.rewardGold)
                    Divider()
                    Text("\(summary.past) past-tense \(summary.past == 1 ? "conjugation" : "conjugations")")
                        .font(.headline)
                    Text("\(summary.future) future-tense \(summary.future == 1 ? "conjugation" : "conjugations")")
                        .font(.headline)
                    Text("Counts include repeated practice. Compound forms count as one expression.")
                        .font(.caption).foregroundStyle(theme.theme.muted)
                }.padding(24).frame(maxWidth: .infinity)
                    .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
                Button("Continue", action: continueWorkout)
                    .buttonStyle(PrimaryButton()).disabled(busy).padding(.top, 12)
                InlineError(message: error)
            }.multilineTextAlignment(.center).padding(24).padding(.top, 40)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .interactiveDismissDisabled()
    }
}
