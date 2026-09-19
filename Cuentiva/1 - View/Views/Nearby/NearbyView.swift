import SwiftUI

struct NearbyView: View {
    @State private var viewModel = NearbyViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Every place\nhas a story.").font(.system(.largeTitle, design: .serif))
                Text("Discover stories from the collection connected to places around you.").foregroundStyle(theme.theme.muted)
                Button { viewModel.findStories() } label: {
                    Label(viewModel.busy ? "Finding your place…" : "Find stories near me", systemImage: "location")
                }.buttonStyle(PrimaryButton()).disabled(viewModel.busy)
                Text("Location is requested only when you tap. Your browsing location is not saved. Apple’s location service identifies the place name.")
                    .font(.caption).foregroundStyle(theme.theme.muted)
                Picker("Distance", selection: $viewModel.radius) {
                    ForEach([5.0, 25, 100], id: \.self) { Text("\(Int($0)) km").tag($0) }
                    Text("1,000 mi").tag(1609.344)
                }.pickerStyle(.segmented)
                InlineError(message: viewModel.error)
                if let place = viewModel.location {
                    Label(place.placeName, systemImage: "mappin.and.ellipse").font(.headline)
                    Text("Approximate distances. Location accuracy: about \(Int(place.accuracy)) metres.").font(.caption).foregroundStyle(theme.theme.muted)
                    if viewModel.books.isEmpty {
                        Text("A little further afield.").font(.system(.title2, design: .serif))
                        Text("No stories from your collection are nearby yet. Try a wider distance.").foregroundStyle(theme.theme.muted)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 24)], alignment: .leading, spacing: 28) {
                    ForEach(viewModel.books) { book in
                        Button { viewModel.selectedBook = book } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                BookCover(book: book, completed: viewModel.completed(book), compact: true)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(book.englishTitle).font(.headline)
                                    Text(book.submissionLocation?.placeName ?? "").font(.subheadline)
                                    Text(book.level).font(.caption)
                                    if book.isDemoLocation == true { Text("EXAMPLE STORY · DEMO LOCATION").font(.caption2).foregroundStyle(theme.theme.muted) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                    }
                }
                Text("Finish a nearby story to keep it in Completed wherever you travel. Three fictional Thailand stories have example locations for exploring Nearby.")
                    .font(.caption).foregroundStyle(theme.theme.muted)
            }.padding(25)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .navigationTitle("Nearby Stories").navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $viewModel.selectedBook) { book in NavigationStack { LessonView(book: book) } }
            .onDisappear { viewModel.clearLocation() }
            .onChange(of: phase) { _, value in if value == .background { viewModel.clearLocation() } }
    }
}
