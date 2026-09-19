import SwiftUI

/// An invitation, not a preview of the creature the reader will draw.
struct MysteryStorytellerView: View {
    @State private var appeared = false
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let portraits = ["StorytellerPipa", "StorytellerBrasa", "StorytellerNube", "StorytellerTilo"]

    var body: some View {
        let motionReduced = reduceMotion
        return ZStack {
            Circle().fill(theme.theme.surface).frame(width: 144, height: 144)
                .overlay { Circle().strokeBorder(theme.theme.accent.opacity(0.25), lineWidth: 1) }
            Image(systemName: "person.fill")
                .font(.system(size: 96)).foregroundStyle(theme.theme.accent.opacity(0.2))
                .offset(y: 12)
            Text("?").font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(theme.theme.ink)
            ForEach(Array(portraits.enumerated()), id: \.offset) { index, portrait in
                Image(portrait).resizable().scaledToFill()
                    .frame(width: 64, height: 64).clipShape(Circle())
                    .overlay { Circle().strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1) }
                    .offset(x: index.isMultiple(of: 2) ? -100 : 100,
                            y: index < 2 ? -78 : 78)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 240)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .easeIn(duration: 0.5), value: appeared)
        .keyframeAnimator(initialValue: 1.0, trigger: appeared) { content, scale in
            content.scaleEffect(motionReduced ? 1 : scale)
        } keyframes: { _ in
            LinearKeyframe(0.9, duration: 0.01)
            SpringKeyframe(1.1, duration: 0.4, spring: .bouncy)
            SpringKeyframe(0.95, duration: 0.3, spring: .smooth)
            SpringKeyframe(1, duration: 0.4, spring: .smooth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your mystery storyteller, surrounded by Pipa and friends. Your character has not been chosen yet.")
        .task {
            guard !appeared else { return }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            }
            appeared = true
        }
    }
}
