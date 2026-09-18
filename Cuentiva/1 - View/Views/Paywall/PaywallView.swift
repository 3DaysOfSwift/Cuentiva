import SwiftUI

struct PaywallView: View {
    @State private var viewModel = PaywallViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("YOUR FIRST BOOK, COMPLETED", systemImage: "checkmark.seal.fill").font(.caption.weight(.bold))
                    .tracking(1)
                Text(viewModel.declined ? "Your stories will\nbe here." : viewModel.title).font(
                    .system(.largeTitle, design: .serif, weight: .medium))
                Text(
                    viewModel.declined
                        ? "Your first achievement is saved. Unlock Cuentiva whenever you’re ready to keep learning."
                        : "Small stories. Real progress. Build a collection you can be proud of."
                ).foregroundStyle(theme.theme.muted)
                ForEach(
                    [
                        "Explore every story in the library", "Listen, speak, and write in Spanish",
                        "Collect completed books", "Keep your learning on this device",
                    ], id: \.self
                ) { item in Label(item, systemImage: "checkmark").font(.body) }
                Divider()
                ForEach(LibraryPlan.allCases) { plan in
                    Button { viewModel.selectedPlan = plan } label: {
                        HStack {
                            Image(systemName: viewModel.selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading, spacing: 6) {
                                Text(plan.title).font(.headline)
                                Text(viewModel.price(for: plan)).font(.title3.bold())
                                Text(plan == .annual ? "Billed yearly, in one payment" : "Billed monthly")
                                    .font(.footnote)
                                if plan == .annual && viewModel.annualSaves {
                                    Text("Ahorra con el plan anual").font(.subheadline)
                                    Text("Save with the annual plan").font(.caption)
                                }
                            }
                            Spacer()
                        }.padding().frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered).tint(theme.theme.accent)
                        .disabled(viewModel.busy || !viewModel.available(plan))
                        .accessibilityAddTraits(viewModel.selectedPlan == plan ? .isSelected : [])
                }
                Text("Both plans include the same library access. Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends. Payment is charged to your Apple Account. Manage or cancel in your App Store account settings.")
                    .font(.footnote).foregroundStyle(theme.theme.muted)
                Button(viewModel.button) { Task { await viewModel.purchase() } }.buttonStyle(PrimaryButton()).disabled(
                    viewModel.busy || !viewModel.available)
                if viewModel.busy { ProgressView().frame(maxWidth: .infinity) }
                Button("Restore purchases") { Task { await viewModel.restore() } }.frame(maxWidth: .infinity).disabled(
                    viewModel.busy)
                if !viewModel.declined {
                    Button("Not now") { viewModel.declined = true }.frame(maxWidth: .infinity).foregroundStyle(
                        theme.theme.muted)
                }
                InlineError(message: viewModel.error ?? viewModel.storeMessage)
                if !viewModel.available { Button("Reload purchase options") { Task { await viewModel.reload() } } }
                #if DEBUG
                    Text(
                        "DEMO • The Xcode StoreKit scheme uses a test price. No real payment is taken in local StoreKit testing."
                    ).font(.caption2).foregroundStyle(theme.theme.muted)
                #endif
                HStack {
                    if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        Link("Terms of use", destination: termsURL)
                    } else {
                        Text("Terms link unavailable")
                    }
                    Spacer()
                    if let privacyURL = URL(string: "https://swiftsimplified.wixsite.com/appstore-support/privacy-policy") {
                        Link("Privacy policy", destination: privacyURL)
                    }
                }.font(.caption2)
            }.padding(28)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink).task { await viewModel.reload() }
    }
}
