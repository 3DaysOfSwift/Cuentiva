//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct TopicContributionTests {
    @Test func topicSubmissionChecksTeachingButDoesNotFillCoverage() async throws {
        let purchases = TestPurchases(); purchases.hasAccess = true
        let progress = ProgressManager(repository: MemoryProgress()); try await progress.load()
        let book = sample(); try await progress.recordEncounter(book: book, sentence: book.sentences[0]); _ = try await progress.complete(book: book)
        let repo = MemoryContributions()
        let manager = ContributionManager(repository: repo, purchases: purchases, progress: progress)
        try await manager.load()
        let topic = try #require(manager.topics.first { $0.id == "haber-introductions" })
        var draft = Contribution(); draft.title = "Una bienvenida"; draft.topicID = topic.id
        try await manager.save(draft, submit: false)
        await #expect(throws: AppFailure.self) { try await manager.save(draft, submit: true) }
        draft.spanish = "He venido. He hablado. Has venido. Has hablado. Ha venido. Ha hablado. Hemos venido. Hemos hablado. Habéis venido. Habéis hablado. Han venido. Han hablado."
        draft.teachingNote = "Haber helps form compound tenses; explain each example in the story."
        draft.checkedRequirements = topic.requirements
        #expect(topic.ready(draft))
        try await manager.save(draft, submit: true)
        #expect(manager.drafts.count == 1)
        #expect(manager.drafts[0].status == "Pending review · local demo")
        #expect(manager.publishedCount == 0); #expect(!topic.covered); #expect(topic.reviewedBooks == 0)
        let reloaded = ContributionManager(repository: repo, purchases: purchases, progress: progress); try await reloaded.load()
        #expect(reloaded.drafts.first?.topicID == topic.id)
        #expect(reloaded.drafts.first?.teachingNote == draft.teachingNote)
        draft.spanish = draft.spanish.replacingOccurrences(of: "Habéis", with: "Habeis")
        #expect(!topic.ready(draft))
    }
    @Test func coverageAndWordEvidenceAreNotDraftCounts() async throws {
        let topic = TopicRequest(id: "test", title: "Test", category: "Verbs", priority: "Test", brief: "Test", scope: "Present", forms: ["ha"], requirements: [], target: 2, reviewedBooks: 1, demoExamples: 8)
        #expect(!topic.covered)
        #expect(topic.occurrences(in: "hablar hacer ha ¡Ha!") == [2])
        let complete = TopicRequest(id: "done", title: "Done", category: "Test", priority: "Test", brief: "Test", scope: "Test", forms: [], requirements: [], target: 2, reviewedBooks: 2, demoExamples: 0)
        #expect(complete.covered); #expect(complete.coverageLabel == "Covered")
    }
    @Test func legacyDraftStillDecodes() throws {
        let data = Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"title\":\"Mi historia\",\"spanish\":\"Hola\",\"status\":\"Draft\"}".utf8)
        let draft = try JSONDecoder().decode(Contribution.self, from: data)
        #expect(draft.topicID == nil); #expect(draft.teachingNote == nil)
    }
}
