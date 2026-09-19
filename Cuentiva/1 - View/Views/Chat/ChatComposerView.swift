import SwiftUI

struct ChatComposerView: View {
    @Binding var draft: String
    @FocusState.Binding var composing: Bool
    let sending: Bool
    let canSend: Bool
    let send: () -> Void
    let cancel: () -> Void
    @Environment(ThemeManager.self) private var theme
    private var characterCount: Int { ChatLimits.normalizedMessage(draft).count }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                TextField("Say something in Spanish…", text: $draft, axis: .vertical)
                    .lineLimit(1...4).focused($composing).disabled(sending)
                if sending {
                    Button("Stop") { cancel() }
                } else {
                    Button { composing = false; send() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }.accessibilityLabel("Send message").disabled(!canSend)
                }
            }
            if characterCount > ChatLimits.message - 50 {
                Text("\(characterCount)/\(ChatLimits.message) characters").font(.caption)
            }
        }.padding().background(theme.theme.surface).dockedAreaBorder()
    }
}
