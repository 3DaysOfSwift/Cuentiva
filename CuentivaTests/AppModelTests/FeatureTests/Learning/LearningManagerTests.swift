import Foundation
import Testing
#if canImport(CuentivaAppModel)
@testable import CuentivaAppModel
#else
@testable import Cuentiva
#endif

@Suite @MainActor struct LearningManagerTests {
    @Test func movingAndFinishingRespectAccessAndCommittedProgress() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases(); purchases.hasAccess = true
        let feature = LearningManager(purchases: purchases, progress: progress)
        let book = sample("paid", sentences: 2)
        try await feature.move(book: book, position: 1)
        #expect(feature.position(book) == 1)
        await repository.setFailure(true)
        await #expect(throws: AppFailure.self) { try await feature.move(book: book, position: 0) }
        #expect(feature.position(book) == 1)
        await repository.setFailure(false)
        for sentence in book.sentences {
            _ = try await feature.check(book: book, sentence: sentence, answer: sentence.spanish)
        }
        let receipt = try await feature.finish(book)
        #expect(receipt.total == 1)
        #expect(feature.position(book) == 0)
        purchases.hasAccess = false
        await #expect { try await feature.move(book: book, position: 1) } throws: { error in
            guard case AppFailure.locked = error else { return false }
            return true
        }
        await #expect { try await feature.finish(book) } throws: { error in
            guard case AppFailure.locked = error else { return false }
            return true
        }
    }

    @Test func invalidOrEmptyAnswersNeverSaveAnEncounter() async throws {
        let repository = MemoryProgress()
        let progress = ProgressManager(repository: repository)
        try await progress.load()
        let purchases = TestPurchases()
        let feature = LearningManager(purchases: purchases, progress: progress)
        let book = sample()
        let foreign = Sentence(id: "foreign", spanish: "Hola", english: "Hello")
        await #expect { try await feature.check(book: book, sentence: foreign, answer: "Hola") } throws: { error in
            guard case AppFailure.invalidBook = error else { return false }
            return true
        }
        await #expect { try await feature.check(book: book, sentence: book.sentences[0], answer: "   ") } throws: { error in
            guard case AppFailure.emptyAnswer = error else { return false }
            return true
        }
        #expect(await repository.saveAttempts == 0)
        #expect(progress.snapshot.completed.isEmpty)
    }
}
