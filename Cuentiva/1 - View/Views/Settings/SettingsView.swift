import SwiftUI
import StoreKit
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var subscriptions = false
    var body: some View {
        List {
            Section("Membership") {
                Button("Manage subscription") { subscriptions = true }
                Button("Restore purchases") { Task { await viewModel.restore() } }
            }
            Section("Your vocabulary") {
                if viewModel.words.isEmpty { Text("Words you practice will appear here.") }
                ForEach(viewModel.words, id: \.self) { word in
                    Picker(word, selection: Binding(get: { viewModel.state(word) }, set: { state in Task { await viewModel.set(word, state: state) } })) {
                        ForEach(VocabularyState.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
            }
            Section("Privacy") {
                Text("Your progress and drafts are stored on this device. Speech recognition is on-device where supported. Recordings are not saved. There are no analytics or advertising SDKs.")
                Text("Device backups may include app data. Deleting the app removes its local data; purchases remain with your Apple Account.")
                Button("Reset learning progress", role: .destructive) { viewModel.resetConfirmation = true }
            }
            Section { InlineError(message: viewModel.error) }
        }.navigationTitle("Settings")
            .manageSubscriptionsSheet(isPresented: $subscriptions)
            .confirmationDialog("Delete learning progress from this device?", isPresented: $viewModel.resetConfirmation, titleVisibility: .visible) { Button("Reset progress", role: .destructive) { Task { await viewModel.reset() } } }
    }
}
