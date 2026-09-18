import Foundation

@MainActor final class AppModel {
    static let shared = live()
    let library: any LibraryFeature
    let progress: any ProgressFeature
    let purchases: any PurchaseFeature
    let learning: any LearningFeature
    let contributions: any ContributionFeature
    let languageTerms: any LanguageTermsFeature = LanguageTermsManager()
    let practice: any PracticeFeature
    let nearby: any NearbyFeature
    let chat: any ChatFeature
    let fantasy: any FantasyFeature
    let makeAudio: () -> any LessonAudio
    init(library: any LibraryFeature, progress: any ProgressFeature, purchases: any PurchaseFeature,
         learning: any LearningFeature, contributions: any ContributionFeature, fantasy: any FantasyFeature, chat: any ChatFeature, makeAudio: @escaping () -> any LessonAudio) {
        self.chat = chat
        self.fantasy = fantasy
        self.practice = PracticeManager(progress: progress, purchases: purchases)
        self.nearby = NearbyManager(library: library, purchases: purchases)
        self.library = library; self.progress = progress; self.purchases = purchases
        self.learning = learning; self.contributions = contributions; self.makeAudio = makeAudio
    }
    static func live() -> AppModel {
        let directory = URL.applicationSupportDirectory.appending(path: "Cuentiva")
        let progress = ProgressManager(repository: LocalProgressRepository(url: directory.appending(path: "progress.json")))
        let purchases = PurchaseManager()
        let repository = SyncedBookRepository(bundled: BundledBookRepository(),
            transport: GitHubCatalogueTransport(endpoint: URL(string: "https://github.com/3DaysOfSwift/GlobalEnglish-SpanishLearningBooksCollection")!),
            cacheURL: directory.appending(path: "catalogue.json"))
        let fantasy = FantasyManager(repository: LocalFantasyRepository(url: directory.appending(path: "fantasy.json")), generator: AppleFantasyGenerator())
        let library = LibraryManager(repository: repository, purchases: purchases, progress: progress, personalLibrary: fantasy)
        let learning = LearningManager(purchases: purchases, progress: progress)
        let contributions = ContributionManager(repository: LocalContributionRepository(url: directory.appending(path: "drafts.json")), purchases: purchases, progress: progress, topicRepository: LocalTopicRequestRepository())
        let chat = ChatManager(purchases: PurchaseManager(productID: PurchaseManager.storytellerChatProductID),
            generator: AppleChatGenerator(), repository: LocalChatRepository(url: directory.appending(path: "chat.json")))
        return .init(library: library, progress: progress, purchases: purchases, learning: learning, contributions: contributions, fantasy: fantasy, chat: chat, makeAudio: { AppleLessonAudio() })
    }
}
