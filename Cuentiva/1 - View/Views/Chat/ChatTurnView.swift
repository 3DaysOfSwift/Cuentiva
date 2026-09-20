import SwiftUI

struct ChatTurnView: View {
    let turn: ChatMessage
    let name: String
    let translated: Bool
    let translate: () -> Void
    let listen: () -> Void
    @Environment(ThemeManager.self) private var theme
    private var fromLearner: Bool { turn.role == .learner }

    var body: some View {
        HStack {
            if fromLearner { Spacer(minLength: 32) }
            VStack(alignment: .leading, spacing: 10) {
                Text(fromLearner ? "You" : name).font(.caption.bold())
                    .foregroundStyle(theme.theme.muted)
                Text(turn.text).textSelection(.enabled)
                if fromLearner {
                    if turn.delivery == .pending {
                        Text("Waiting for reply…").font(.caption).foregroundStyle(theme.theme.muted)
                    } else if turn.delivery == .failed {
                        Label("No reply received. Try sending again.", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(theme.theme.error)
                    }
                } else {
                    HStack {
                        Button(translated ? "Hide English" : "Show English", action: translate)
                        Spacer()
                        Button(action: listen) { Image(systemName: "speaker.wave.2") }
                            .accessibilityLabel("Listen to message")
                    }.font(.subheadline)
                    if translated { Text(turn.english).foregroundStyle(theme.theme.muted).textSelection(.enabled) }
                    if !turn.correction.isEmpty {
                        Divider()
                        Text("A little language help").font(.caption.bold())
                        Text(turn.correction).font(.subheadline).textSelection(.enabled)
                    }
                }
            }.padding()
                .background(fromLearner ? theme.theme.accent.opacity(0.12) : theme.theme.surface,
                            in: RoundedRectangle(cornerRadius: 18))
            if !fromLearner { Spacer(minLength: 32) }
        }
    }
}
