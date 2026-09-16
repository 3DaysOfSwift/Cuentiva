import SwiftUI
struct PaywallView: View {
    @State private var viewModel = PaywallViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("YOUR FIRST BOOK IS YOURS", systemImage: "checkmark.seal.fill").font(.caption.weight(.bold)).tracking(1)
                Text(viewModel.declined ? "Your stories will\nbe here." : viewModel.title).font(.system(.largeTitle, design: .serif, weight: .medium))
                Text(viewModel.declined ? "Your first achievement is saved. Subscribe whenever you’re ready to keep learning." : "Small stories. Real progress. Build a collection you can be proud of.").foregroundStyle(theme.theme.muted)
                ForEach(["Explore every story in the library", "Listen, speak, and write in Spanish", "Collect completed books", "Share a story of your own"], id: \.self) { item in Label(item, systemImage: "checkmark").font(.body) }
                Divider()
                Text(viewModel.trial ? "7 days free, then \(viewModel.price)." : viewModel.price).font(.headline)
                Text("Automatically renews until cancelled. Manage or cancel in your Apple subscription settings.").font(.footnote).foregroundStyle(theme.theme.muted)
                Button(viewModel.button) { Task { await viewModel.purchase() } }.buttonStyle(PrimaryButton()).disabled(viewModel.busy || !viewModel.available)
                if viewModel.busy { ProgressView().frame(maxWidth: .infinity) }
                Button("Restore purchases") { Task { await viewModel.restore() } }.frame(maxWidth: .infinity).disabled(viewModel.busy)
                if !viewModel.declined { Button("Not now") { viewModel.declined = true }.frame(maxWidth: .infinity).foregroundStyle(theme.theme.muted) }
                InlineError(message: viewModel.error ?? viewModel.storeMessage)
                if !viewModel.available { Button("Reload purchase options") { Task { await viewModel.reload() } } }
                #if DEBUG
                Text("DEMO • The Xcode StoreKit scheme uses a test price. No real payment is taken in local StoreKit testing.").font(.caption2).foregroundStyle(theme.theme.muted)
                #endif
                HStack { Link("Terms of use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!); Spacer(); Text("Privacy: audio stays on device") }.font(.caption2)
            }.padding(28)
        }.background(theme.theme.paper).task { await viewModel.reload() }
    }
}
