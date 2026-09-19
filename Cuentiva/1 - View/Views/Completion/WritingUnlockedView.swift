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
                            Text("A free gift.\nJust for you.")
                                .font(.system(.largeTitle, design: .serif))
                                .accessibilityAddTraits(.isHeader)
                            Text("To celebrate your first five books, we’ve unlocked something new for you. Ready to discover it?")
                            Button("See my gift  →") { model.next() }
                                .buttonStyle(PrimaryButton())
                        } else if model.stage == .gift {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 150, weight: .light))
                                .foregroundStyle(theme.theme.accent)
                                .frame(maxWidth: .infinity, minHeight: 300)
                                .accessibilityLabel("A wrapped gift, waiting for you to open")
                            Button("Open my gift  →") { model.next() }
                                .buttonStyle(PrimaryButton())
                        } else {
                            Image(FantasyCreature.fox.portrait)
                                .resizable().scaledToFill().frame(width: 150, height: 150)
                                .clipShape(Circle())
                                .overlay { Circle().strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1) }
                                .accessibilityHidden(true)
                            Text("You’re invited to\nbecome a storyteller.")
                                .font(.system(.largeTitle, design: .serif))
                                .accessibilityAddTraits(.isHeader)
                            Text("Your free gift: Write is now unlocked.")
                                .font(.headline).foregroundStyle(theme.theme.accent)
                            Text("Choose your character. Turn a memory or a wonderfully silly idea into a cute, bite-sized fantasy story in Spanish.")
                            Text("Your tales carry your fantasy name, not your real name. We publish them straight back to YOU — in your private Books library, never a public feed.")
                            Text("Learn by writing and reading stories that are yours, on your most personal device: your phone.")
                            Text("Story generation uses Apple Intelligence on a supported device. You can set up your character now and write when it’s available.")
                                .font(.footnote).foregroundStyle(theme.theme.muted)
                            Button("Choose my character  →") { model.next() }
                                .buttonStyle(PrimaryButton())
                            Button("Explore this later", action: onContinue)
                                .foregroundStyle(theme.theme.accent)
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
