import SwiftUI

struct ChatTurnView: View {
    let turn: ChatMessage
    let spokenRange: NSRange?
    let translated: Bool
    let translate: () -> Void
    let listen: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(ThemeManager.self) private var theme
    private var fromLearner: Bool { turn.role == .learner }

    private var spokenText: Text {
        var text = AttributedString(turn.text)
        if let spokenRange, let range = Range(spokenRange, in: text) {
            text[range].backgroundColor = theme.theme.chatAction
            text[range].foregroundColor = theme.theme.chatSent
        }
        return Text(text)
    }

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
                                    Text(turn.english).foregroundStyle(theme.theme.chatSecondaryText)
                                } else {
                                    Text(turn.delivery == .pending ? "English will be available with the reply." : "English translation is unavailable for this message.")
                                        .font(.subheadline).foregroundStyle(theme.theme.chatSecondaryText)
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle()).multilineTextAlignment(.leading)
                    }.buttonStyle(.plain)
                        .accessibilityHint(translated ? "Hide English translation" : "Show English translation")
                    if turn.delivery == .failed {
                        Label("No reply received. Try sending again.", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(theme.theme.chatError)
                    }
                } else {
                    spokenText.font(.title).textSelection(.enabled)
                    HStack {
                        Button(translated ? "Hide English" : "Show English", action: translate)
                        Spacer()
                        Button(action: listen) { Label("Listen", systemImage: "speaker.wave.2") }
                            .accessibilityLabel("Listen to message")
                    }.font(.subheadline.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.theme.chatAction).padding(.top, 16)
                    if translated { Text(turn.english).foregroundStyle(theme.theme.chatSecondaryText).textSelection(.enabled) }
                }
            }.padding().foregroundStyle(theme.theme.chatText)
                .background(fromLearner ? theme.theme.chatSent : theme.theme.chatReceived,
                            in: ChatBubbleShape(tailOnRight: fromLearner == (layoutDirection == .leftToRight)))
            if !fromLearner { Spacer(minLength: 32) }
        }
    }
}
