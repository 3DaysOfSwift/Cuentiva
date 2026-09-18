import SwiftUI

struct ThemePackGiftView: View {
    @State private var model: ThemePackGiftViewModel
    @Environment(ThemeManager.self) private var theme
    let onContinue: () -> Void

    init(pack: ThemePack, onContinue: @escaping () -> Void) {
        _model = State(initialValue: ThemePackGiftViewModel(pack: pack))
        self.onContinue = onContinue
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: model.installed ? "checkmark.seal.fill" : "gift.fill")
                    .font(.system(size: 90)).foregroundStyle(theme.theme.accent)
                    .accessibilityHidden(true)
                Text(model.installed ? "Your new colours are ready." : "A little colour for your next chapter.")
                    .font(.system(.largeTitle, design: .serif))
                Text(model.pack.giftReason)
                    .foregroundStyle(theme.theme.muted)
                if model.opened || model.installed {
                    Text("\(model.pack.title) · \(model.pack.themes.count) \(model.pack.themes.count == 1 ? "colour theme" : "colour themes")").font(.headline)
                    ForEach(model.pack.themes) { choice in
                        HStack {
                            Circle().fill(choice.palette.accent).frame(width: 28, height: 28)
                                .overlay { Circle().strokeBorder(theme.theme.muted.opacity(0.5), lineWidth: 1) }
                            Text(choice.title)
                            Spacer()
                        }
                    }
                    if model.installed {
                        Text("Find your installed colours in Settings → Colour theme. Your current theme stays selected.")
                        Button("Continue  →", action: onContinue).buttonStyle(PrimaryButton())
                    } else {
                        Button(model.installing ? "Installing…" : "Install") {
                            Task { await model.install(keeping: theme) }
                        }.buttonStyle(PrimaryButton()).disabled(model.installing)
                        Text("Ready on this device. No download or purchase needed.")
                            .font(.footnote).foregroundStyle(theme.theme.muted)
                    }
                } else {
                    Button("Open my gift  →") { model.opened = true }.buttonStyle(PrimaryButton())
                }
                InlineError(message: model.error)
                if !model.installed {
                    Button("Save for later", action: onContinue).disabled(model.installing)
                    Text("Your earned pack will be waiting in Settings.")
                        .font(.footnote).foregroundStyle(theme.theme.muted)
                }
            }.multilineTextAlignment(.center).padding(28).padding(.top, 30)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .interactiveDismissDisabled(model.installing)
    }
}
