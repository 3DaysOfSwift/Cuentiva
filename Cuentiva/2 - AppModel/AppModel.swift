import Foundation

@MainActor final class AppModel {
    static let shared = live()
    let library: any LibraryFeature
    let progress: any ProgressFeature
    let purchases: any PurchaseFeature
    let learning: any LearningFeature
    let contributions: any ContributionFeature
    let nearby: any NearbyFeature
    let makeAudio: () -> any LessonAudio
    init(library: any LibraryFeature, progress: any ProgressFeature, purchases: any PurchaseFeature,
         learning: any LearningFeature, contributions: any ContributionFeature, makeAudio: @escaping () -> any LessonAudio) {
        self.nearby = NearbyManager(library: library, purchases: purchases)
        self.library = library; self.progress = progress; self.purchases = purchases
        self.learning = learning; self.contributions = contributions; self.makeAudio = makeAudio
    }
    static func live() -> AppModel {
        let directory = URL.applicationSupportDirectory.appending(path: "Cuentiva")
        let progress = ProgressManager(repository: LocalProgressRepository(url: directory.appending(path: "progress.json")))
        let purchases = PurchaseManager()
        let library = LibraryManager(repository: BundledBookRepository(), purchases: purchases, progress: progress)
        let learning = LearningManager(purchases: purchases, progress: progress)
        let contributions = ContributionManager(repository: LocalContributionRepository(url: directory.appending(path: "drafts.json")), purchases: purchases, progress: progress, topicRepository: LocalTopicRequestRepository())
        return .init(library: library, progress: progress, purchases: purchases, learning: learning, contributions: contributions, makeAudio: { AppleLessonAudio() })
    }
}
