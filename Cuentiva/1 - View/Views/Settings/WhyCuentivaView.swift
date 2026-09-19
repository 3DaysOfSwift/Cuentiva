import SwiftUI

struct WhyCuentivaView: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Little stories.\nShared knowledge.")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                Text("Cuentiva brings two ideas together: learning Spanish through stories, and sharing the craft behind the app that tells them.")
                    .font(.title3)

                section("Words with a life around them", text: "Stories, scripts and verb practice put Spanish words into sentences you can read, hear and say. Our aim is to help you recognise more words and become more comfortable telling the stories of your own life.")

                section("Open for everyone to explore", text: "The app’s source code and core book dataset are freely available to read on GitHub. You can explore how Cuentiva works, read the learning material and follow its development—even without buying the app.")
                VStack(alignment: .leading, spacing: 18) {
                    repositoryLink("Explore the app’s source code", address: "https://github.com/3DaysOfSwift/Cuentiva")
                    repositoryLink("Explore the book dataset", address: "https://github.com/3DaysOfSwift/GlobalEnglish-SpanishLearningBooksCollection")
                }

                section("A learning resource for developers, too", text: "Cuentiva shares iOS engineering experience through a real app. It uses Cooperative Feature Architecture to keep screens, feature decisions and storage clearly separated. SwiftUI describes the interface; Swift Concurrency helps coordinate the work behind it. The goal is simple, readable code that other developers can study and discuss.")
                repositoryLink("Discover Cooperative Feature Architecture", address: "https://github.com/3DaysOfSwift/cooperative-feature-architecture")

                section("Prepared books, ready on your phone", text: "The bundled library is prepared as compact binary files before it reaches your device. This avoids repeatedly decoding the original text files at launch. Your reading progress is stored separately, so displaying the library does not require importing every book into a database. We measure and refine startup performance to keep the experience responsive.")

                section("A library that can keep growing", text: "Core curriculum updates come from our shared GitHub dataset. Downloading and preparing updates happens separately from displaying the local library. This keeps reading and content maintenance apart, and gives us a clear path to improve the curriculum over time.")

                Text("A thoughtful reading companion—and an open invitation to learn how it is made.")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(theme.theme.accent)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(theme.theme.paper)
        .foregroundStyle(theme.theme.ink)
        .tint(theme.theme.accent)
        .navigationTitle("Why Cuentiva is unique")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(text).foregroundStyle(theme.theme.muted)
        }
    }

    @ViewBuilder
    private func repositoryLink(_ title: String, address: String) -> some View {
        if let url = URL(string: address) {
            Link(destination: url) {
                Label(title, systemImage: "arrow.up.right.square")
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }
}
