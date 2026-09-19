import Foundation
import Testing
@testable import Cuentiva

@Suite @MainActor struct ContributionViewModelTests {
    @Test func contributionRetainsInvalidDraft() async throws {
        let (_,_,_,_,f) = try await makeViewModelTestGraph(); let vm = ContributionViewModel(feature: f)
        vm.draft.title = "My memory"; await vm.save(submit: true)
        #expect(vm.draft.title == "My memory"); #expect(vm.error != nil)
    }

    @Test func changingPathsPreservesWorkAndResumesTicket() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let book = sample(); try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        let manager = ContributionManager(repository: MemoryContributions(), purchases: purchases, progress: progress)
        let vm = ContributionViewModel(feature: manager); await vm.load()
        vm.draft.spanish = "Mi historia sin título."
        let topic = try #require(vm.topics.first)
        await vm.choose(topic)
        #expect(vm.selectedTopic?.id == topic.id)
        #expect(manager.drafts.contains { $0.spanish == "Mi historia sin título." })
        let identifier = vm.draft.id
        vm.teachingNote = "My own explanation."
        await vm.freestyle()
        #expect(vm.draft.topicID == nil); #expect(vm.draft.spanish.isEmpty)
        await vm.choose(topic)
        #expect(vm.draft.id == identifier); #expect(vm.teachingNote == "My own explanation.")
        #expect(manager.drafts.filter { $0.topicID == topic.id }.count == 1)
    }
}
