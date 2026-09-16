import Foundation

@MainActor protocol NearbyFeature: AnyObject {
    func stories(around location: StoryLocation, kilometers: Double) -> [Book]
}
@MainActor final class NearbyManager: NearbyFeature {
    private let library: any LibraryFeature
    private let purchases: any PurchaseFeature
    init(library: any LibraryFeature, purchases: any PurchaseFeature) {
        self.library = library; self.purchases = purchases
    }
    func stories(around location: StoryLocation, kilometers: Double) -> [Book] {
        guard purchases.hasAccess, location.fresh(), kilometers.isFinite, kilometers > 0 else { return [] }
        return library.books.filter {
            guard let submitted = $0.submissionLocation, submitted.valid else { return false }
            return location.kilometers(to: submitted) <= kilometers
        }.sorted {
            let lhs = location.kilometers(to: $0.submissionLocation!)
            let rhs = location.kilometers(to: $1.submissionLocation!)
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
    }
}
