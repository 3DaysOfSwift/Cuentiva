import SwiftUI

struct ChatComposerView: View {
    @Binding var draft: String
    @FocusState.Binding var composing: Bool
    let notice: String?
    let canSend: Bool
    let send: () -> Void
    @Environment(ThemeManager.self) private var theme
    private var characterCount: Int { ChatLimits.normalizedMessage(draft).count }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notice {
                Text(notice).font(.footnote).foregroundStyle(theme.theme.error)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            HStack(alignment: .bottom) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4).focused($composing)
                Button { send() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title)
                    }.accessibilityLabel("Send message").disabled(!canSend)
            }
            if characterCount > ChatLimits.message - 50 {
                Text("\(characterCount)/\(ChatLimits.message) characters").font(.caption)
            }
        }.padding().background(theme.theme.surface).dockedAreaBorder()
    }
}
