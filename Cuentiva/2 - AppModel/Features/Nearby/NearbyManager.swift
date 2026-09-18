import Foundation

@MainActor protocol NearbyFeature: AnyObject {
    func stories(around location: StoryLocation, kilometers: Double) -> [Book]
}
@MainActor final class NearbyManager: NearbyFeature {
    private let library: any LibraryFeature
    private let purchases: any PurchaseFeature
    init(library: any LibraryFeature, purchases: any PurchaseFeature) {
        self.library = library
        self.purchases = purchases
    }
    func stories(around location: StoryLocation, kilometers: Double) -> [Book] {
        guard purchases.hasAccess, location.fresh(), kilometers.isFinite, kilometers > 0 else { return [] }
        return library.books.compactMap { book -> (book: Book, distance: Double)? in
            guard let submitted = book.submissionLocation, submitted.valid else { return nil }
            let distance = location.kilometers(to: submitted)
            guard distance <= kilometers else { return nil }
            return (book, distance)
        }.sorted {
            $0.distance == $1.distance ? $0.book.id < $1.book.id : $0.distance < $1.distance
        }.map(\.book)
    }
}
