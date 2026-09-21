//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct ThemePackGiftView: View {
    @State private var model: ThemePackGiftViewModel
    @Environment(ThemeManager.self) private var theme
    let onContinue: () -> Void
    private var palette: AppColourTheme { model.previewTheme?.palette ?? theme.theme }

    init(pack: ThemePack, onContinue: @escaping () -> Void) {
        _model = State(initialValue: ThemePackGiftViewModel(pack: pack))
        self.onContinue = onContinue
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: model.installationConfirmed ? "checkmark.seal.fill" : "gift.fill")
                    .font(.system(size: 90)).foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                Text(model.installationConfirmed ? "Your new colours are ready." : "A little colour for your next chapter.")
                    .font(.system(.largeTitle, design: .serif))
                Text(model.pack.giftReason)
                    .foregroundStyle(palette.muted)
                if model.opened || model.installed {
                    Text("\(model.pack.title) · \(model.pack.themes.count) \(model.pack.themes.count == 1 ? "colour theme" : "colour themes")").font(.headline)
                    Text("Tap a colour to preview it here. Install to make it your app theme.")
                        .font(.footnote).foregroundStyle(palette.muted)
                    ForEach(model.pack.themes) { choice in
                        Button { model.previewTheme = choice } label: {
                            HStack {
                                Circle().fill(choice.palette.accent).frame(width: 28, height: 28)
                                    .overlay { Circle().strokeBorder(palette.muted.opacity(0.5), lineWidth: 1) }
                                Text(choice.title)
                                Spacer()
                                if model.previewTheme == choice {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(palette.accent)
                                }
                            }
                            .padding(14)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.installing || model.installationConfirmed)
                        .accessibilityAddTraits(model.previewTheme == choice ? .isSelected : [])
                        .accessibilityHint("Preview this colour theme on this screen only")
                    }
                    if model.installationConfirmed {
                        Label("Installed — your new theme is ready.", systemImage: "checkmark.circle.fill")
                            .font(.headline).foregroundStyle(palette.accent)
                    } else {
                        Button(model.installing ? "Installing…" : "Install") {
                            model.installationRequested = true
                        }.buttonStyle(PrimaryButton(palette: palette)).disabled(!model.canInstall)
                            .opacity(model.canInstall ? 1 : 0.45)
                        Text("Ready on this device. No download or purchase needed.")
                            .font(.footnote).foregroundStyle(palette.muted)
                    }
                } else {
                    Button("Open my gift  →") { model.opened = true }.buttonStyle(PrimaryButton(palette: palette))
                }
                if let error = model.error {
                    Text(error).font(.footnote).foregroundStyle(palette.error)
                }

            }.multilineTextAlignment(.center).padding(28).padding(.top, 30)
        }.background(palette.paper).foregroundStyle(palette.ink)
            .tint(palette.accent)
            .environment(\.colorScheme, palette.colorScheme)
            .interactiveDismissDisabled(model.installing)
            .task(id: model.installationRequested) {
                if model.installationRequested { await model.install(using: theme) }
            }
            .onChange(of: model.shouldDismiss) { _, dismiss in
                if dismiss { onContinue() }
            }
    }
}
