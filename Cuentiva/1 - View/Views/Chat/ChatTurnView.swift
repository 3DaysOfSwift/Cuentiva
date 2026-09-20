import SwiftUI

struct ChatTurnView: View {
    let turn: ChatMessage
    let translated: Bool
    let translate: () -> Void
    let listen: () -> Void
    @Environment(ThemeManager.self) private var theme
    private var fromLearner: Bool { turn.role == .learner }

    var body: some View {
        HStack {
            if fromLearner { Spacer(minLength: 32) }
            VStack(alignment: .leading, spacing: 10) {
                if fromLearner {
                    Button(action: translate) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(turn.text)
                            if translated {
                                if !turn.english.isEmpty {
                                    Text(turn.english).foregroundStyle(theme.theme.muted)
                                } else {
                                    Text(turn.delivery == .pending ? "English will be available with the reply." : "English translation is unavailable for this message.")
                                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle()).multilineTextAlignment(.leading)
                    }.buttonStyle(.plain)
                        .accessibilityHint(translated ? "Hide English translation" : "Show English translation")
                    if turn.delivery == .pending {
                        Text("Waiting for reply…").font(.caption).foregroundStyle(theme.theme.muted)
                    } else if turn.delivery == .failed {
                        Label("No reply received. Try sending again.", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(theme.theme.error)
                    }
                } else {
                    Text(turn.text).textSelection(.enabled)
                    HStack {
                        Button(translated ? "Hide English" : "Show English", action: translate)
                        Spacer()
                        Button(action: listen) { Label("Listen", systemImage: "speaker.wave.2") }
                            .accessibilityLabel("Listen to message")
                    }.font(.subheadline.weight(.semibold))
                        .buttonStyle(.bordered).tint(theme.theme.accent)
                        .foregroundStyle(theme.theme.accent).padding(.top, 16)
                    if translated { Text(turn.english).foregroundStyle(theme.theme.muted).textSelection(.enabled) }
                }
            }.padding()
                .background(fromLearner ? theme.theme.accent.opacity(0.12) : theme.theme.surface,
                            in: RoundedRectangle(cornerRadius: 18))
            if !fromLearner { Spacer(minLength: 32) }
        }
    }
}
