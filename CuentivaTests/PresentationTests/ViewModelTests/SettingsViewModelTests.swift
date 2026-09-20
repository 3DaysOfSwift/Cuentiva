import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct SettingsViewModelTests {
    #if DEBUG
    @Test func verbPreviewCanBeEnabledAndDisabledWithoutAddingDays() async throws {
        let (p, s, l, _, _) = try await makeViewModelTestGraph()
        let model = SettingsViewModel(library: l, progress: s, purchases: p)
        #expect(!model.verbTrainingPreview)
        await model.toggleVerbTrainingPreview()
        #expect(model.verbTrainingPreview)
        #expect(s.snapshot.verbTrainingUnlocked)
        #expect(s.snapshot.practiceDays.isEmpty)
        await model.toggleVerbTrainingPreview()
        #expect(!model.verbTrainingPreview)
        #expect(!s.snapshot.verbTrainingUnlocked)
    }
    #endif
    @Test func settingsRestoreExplainsExistingAndRecoveredAccess() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph()
        let vm = SettingsViewModel(library: l, progress: s, purchases: p)
        p.hasAccess = true
        await vm.restore()
        #expect(vm.restoreMessage?.contains("already have full access") == true)
        #expect(vm.restoreError == nil)
        #expect(!vm.restoring)
        p.hasAccess = false; p.restoresAccess = true
        await vm.restore()
        #expect(vm.restoreMessage?.contains("Purchase restored") == true)
        #expect(vm.hasAccess)
    }

    @Test func settingsRestoreReplacesStaleFeedbackAndNeverInventsSuccess() async throws {
        let (p,s,l,_,_) = try await makeViewModelTestGraph()
        let vm = SettingsViewModel(library: l, progress: s, purchases: p)
        await vm.restore()
        #expect(vm.restoreError != nil)
        #expect(vm.restoreMessage == nil)
        p.restoreFailure = .unavailable("Store unavailable")
        await vm.restore()
        #expect(vm.restoreError == "Store unavailable")
        #expect(!vm.restoring)
        p.restoreFailure = nil; p.hasAccess = true
        await vm.restore()
        #expect(vm.restoreError == nil)
        #expect(vm.restoreMessage != nil)
    }
}
