import SwiftUI

struct NearbyView: View {
    @State private var viewModel = NearbyViewModel()
    @Environment(ThemeManager.self) private var theme
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Every place\nhas a story.").font(.system(.largeTitle, design: .serif))
                Text("Read the moments people left here. Leave one for the next traveller.").foregroundStyle(theme.theme.muted)
                Button { Task { await viewModel.refresh() } } label: {
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
                        Text("A place waiting for a voice.").font(.system(.title2, design: .serif))
                        Text("There are no published stories nearby in this local demo. Tell the next traveller what you discovered.").foregroundStyle(theme.theme.muted)
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
                NavigationLink { ContributionView(nearby: true) } label: { Label("Leave a story here", systemImage: "square.and.pencil") }
                Text("Finish a nearby story to keep it in Completed wherever you travel. Three fictional Thailand stories have example locations for exploring Nearby. Community publishing is not connected yet.")
                    .font(.caption).foregroundStyle(theme.theme.muted)
            }.padding(25)
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            .navigationTitle("Nearby Stories").navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $viewModel.selectedBook) { book in NavigationStack { LessonView(book: book) } }
            .onChange(of: phase) { _, value in if value == .background { viewModel.clearLocation() } }
    }
}
