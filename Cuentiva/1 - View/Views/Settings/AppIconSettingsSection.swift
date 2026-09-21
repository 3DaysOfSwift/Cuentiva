import SwiftUI

struct AppIconSettingsSection: View {
    @State private var model = StorytellerRevealViewModel(feature: AppModel.shared.fantasy)
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Section {
            Button { Task { await model.restorePipaIcon() } } label: {
                HStack(spacing: 16) {
                    Image("OriginalAppIconPreview").resizable().scaledToFit()
                        .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Original Cuentiva").font(.headline)
                        Text("The original app icon").font(.caption).foregroundStyle(theme.theme.muted)
                    }
                    Spacer()
                    if model.selectedIcon == nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.theme.accent) }
                }.padding(.vertical, 6)
            }.buttonStyle(.plain).disabled(model.changingIcon)
            Button { Task { await model.useStorytellerIcon() } } label: {
                HStack(spacing: 16) {
                    if let creature = model.creature {
                        Image(creature.portrait).resizable().scaledToFill()
                            .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: "person.crop.square").font(.largeTitle).frame(width: 60, height: 60)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.identity?.name ?? "Your storyteller").font(.headline)
                        Text(model.creature == nil ? "Meet your storyteller to unlock this icon" : "Your personal storyteller icon")
                            .font(.caption).foregroundStyle(theme.theme.muted)
                    }
                    Spacer()
                    if model.usesStorytellerIcon { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.theme.accent) }
                }.padding(.vertical, 6)
            }.buttonStyle(.plain).disabled(!model.canOfferIcon || model.changingIcon)
            if let message = model.iconMessage { Text(message).font(.footnote).foregroundStyle(theme.theme.muted) }
        } header: { Text("App icon") }
        footer: { Text("Choose how Cuentiva appears on your Home Screen. You can change it back whenever you like.") }
        .listRowBackground(theme.theme.surface)
        .task { await model.prepare() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.prepare() } }
        }
    }
}
