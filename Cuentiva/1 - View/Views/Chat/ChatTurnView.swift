import SwiftUI

struct ChatTurnView: View {
    let turn: ChatTurn
    let name: String
    let translated: Bool
    let translate: () -> Void
    let listen: () -> Void
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("You").font(.caption.bold()).foregroundStyle(theme.theme.muted)
                Text(turn.question).textSelection(.enabled)
            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 12) {
                Text(name).font(.caption.bold()).foregroundStyle(theme.theme.accent)
                Text(turn.spanish).font(.system(.title3, design: .serif)).textSelection(.enabled)
                HStack {
                    Button(translated ? "Hide English" : "Show English", action: translate)
                    Spacer()
                    Button(action: listen) { Label("Listen", systemImage: "speaker.wave.2") }
                }.font(.subheadline)
                if translated { Text(turn.english).foregroundStyle(theme.theme.muted).textSelection(.enabled) }
                if !turn.correction.isEmpty {
                    Divider()
                    Text("A little language help").font(.caption.bold())
                    Text(turn.correction).font(.subheadline).textSelection(.enabled)
                }
            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
