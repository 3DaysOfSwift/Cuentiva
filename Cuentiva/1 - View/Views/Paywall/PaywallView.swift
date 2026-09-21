//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct PaywallView: View {
    @State private var viewModel = PaywallViewModel()
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("YOUR FIRST BOOK, COMPLETED", systemImage: "checkmark.seal.fill").font(.caption.weight(.bold))
                    .tracking(1)
                Image("StorytellerPipa").resizable().scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel("Pipa, Cuentiva’s storyteller")
                Text(viewModel.title).font(.system(.largeTitle, design: .serif, weight: .medium))
                Text("Small stories. Real progress. Build a collection you can be proud of.")
                    .foregroundStyle(theme.theme.muted)
                ForEach(
                    [
                        "Explore every story in the library", "Listen, speak, and write in Spanish",
                        "Collect completed books", "Keep your learning on this device",
                    ], id: \.self
                ) { item in Label(item, systemImage: "checkmark").font(.body) }
                Divider()
                Label("EVERYTHING YOUR SPANISH NEEDS", systemImage: "sparkles")
                    .font(.caption.weight(.bold)).tracking(1)
                Text("A reason to come back tomorrow.")
                    .font(.system(.title2, design: .serif, weight: .medium))
                VStack(alignment: .leading, spacing: 18) {
                    subscriptionReason(
                        "Read a complete Spanish library",
                        detail: "Follow stories from the first sentence to the final page.",
                        symbol: "books.vertical.fill")
                    subscriptionReason(
                        "Practise for real conversations",
                        detail: "Chat with storytellers and rehearse everyday life in Mexico.",
                        symbol: "bubble.left.and.bubble.right.fill")
                    subscriptionReason(
                        "Turn sentences into instinct",
                        detail: "Train vocabulary, listening, verbs and word order through play.",
                        symbol: "brain.head.profile.fill")
                    subscriptionReason(
                        "Earn rewards by learning",
                        detail: "Complete books and games to collect doubloons and thoughtful gifts.",
                        symbol: "medal.fill")
                    subscriptionReason(
                        "Learn privately on your device",
                        detail: "Keep your progress and supported AI conversations with you.",
                        symbol: "lock.shield.fill")
                }
                Divider()
                ForEach(InAppPurchases.allCases) { plan in
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
                if let trialNotice = viewModel.trialNotice {
                    Text(trialNotice).font(.footnote).foregroundStyle(theme.theme.muted)
                }
                Button(viewModel.button) { Task { await viewModel.purchase() } }.buttonStyle(PrimaryButton()).disabled(
                    viewModel.busy || !viewModel.available)
                if viewModel.busy { ProgressView().frame(maxWidth: .infinity) }
                Button("Restore purchases") { Task { await viewModel.restore() } }.frame(maxWidth: .infinity).disabled(
                    viewModel.busy)
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

    private func subscriptionReason(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(theme.theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(theme.theme.muted)
            }
        }
    }
}
