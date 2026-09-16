import SwiftUI
struct LessonView: View {
    let book: Book
    @State private var viewModel = LessonViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        Group {
            if viewModel.showingReader { BookReaderView(book: book) }
            else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        HStack { Text(viewModel.positionLabel).font(.system(.caption, design: .monospaced)); Spacer(); Text(book.level).font(.caption.bold()) }
                        ProgressView(value: viewModel.fraction)
                        if book.kind == .movieScript {
                            if let scene = book.scene { Text(scene).font(.subheadline).foregroundStyle(theme.theme.muted) }
                            Picker("Your role", selection: $viewModel.role) {
                                Text("Read all roles").tag("")
                                ForEach(book.cast, id: \.self) { Text("Play \($0)").tag($0) }
                            }.onChange(of: viewModel.role) { viewModel.changeMode() }
                        }
                        if let sentence = viewModel.sentence {
                            if let speaker = sentence.speaker {
                                Text("\(speaker)\(viewModel.role.isEmpty ? "" : viewModel.isPartnerLine ? " · Listen to your scene partner" : " · Your line")")
                                    .font(.headline).foregroundStyle(theme.theme.accent)
                            }
                            if viewModel.mode == "Speak" || viewModel.isPartnerLine || viewModel.showSpanish || viewModel.feedback != nil {
                                highlighted(sentence.spanish).font(.system(.title, design: .serif)).lineSpacing(8).environment(\.locale, Locale(identifier: "es-ES"))
                            } else {
                                Text(sentence.spanish)
                                    .font(.system(.title, design: .serif)).lineSpacing(8)
                                    .redacted(reason: .placeholder)
                                    .accessibilityLabel("Spanish sentence hidden. Use Show a hint to reveal it.")
                            }
                            Text(sentence.english).font(.title3).foregroundStyle(theme.theme.muted).environment(\.locale, Locale(identifier: "en-US"))
                            HStack {
                                Button { viewModel.listen() } label: { Label(viewModel.isPartnerLine ? "Listen to \(viewModel.sentence?.speaker ?? "partner")" : "Listen", systemImage: "speaker.wave.2.fill").padding(.vertical, 10) }.buttonStyle(.bordered)
                                Toggle("Slow", isOn: $viewModel.slow).font(.subheadline).fixedSize().padding(.leading)
                            }
                            Picker("Practice mode", selection: $viewModel.mode) { Text("Speak").tag("Speak"); Text("Write").tag("Write") }.pickerStyle(.segmented).disabled(viewModel.busy).onChange(of: viewModel.mode) { viewModel.changeMode() }
                            if viewModel.mode == "Speak" {
                                VStack(spacing: 15) {
                                    Button { viewModel.toggleRecording() } label: { Label(viewModel.audio.recording ? "Stop recording" : "Read it aloud", systemImage: viewModel.audio.recording ? "stop.circle.fill" : "mic.circle.fill").font(.title3).frame(maxWidth: .infinity).padding(20) }.buttonStyle(.bordered).disabled(viewModel.busy)
                                    Text(viewModel.audio.transcript.isEmpty ? "Tap the microphone, then read the Spanish sentence." : viewModel.audio.transcript).font(.body).frame(maxWidth: .infinity).foregroundStyle(theme.theme.muted)
                                }
                            } else {
                                TextField("Your Spanish translation", text: $viewModel.answer, axis: .vertical).lineLimit(3...6).textInputAutocapitalization(.sentences).autocorrectionDisabled().padding(18).background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 15)).disabled(viewModel.busy)
                                Button(viewModel.showSpanish ? "Hide Spanish" : "Show a hint") { viewModel.showSpanish.toggle() }.font(.footnote)
                            }
                            Button { Task { await viewModel.check() } } label: { Text("Check my words").foregroundStyle(theme.theme.checkButtonForeground) }.buttonStyle(.borderedProminent).tint(theme.theme.checkButtonBackground).disabled(viewModel.busy)
                            if let feedback = viewModel.feedback {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("\(feedback.matched) / \(feedback.words.count) words matched").font(.headline)
                                    ForEach(feedback.words) { word in
                                        HStack {
                                            Image(systemName: word.result == .correct ? "checkmark.circle.fill" : word.result == .accent ? "character.cursor.ibeam" : "arrow.uturn.backward.circle")
                                            Text(word.expected).bold()
                                            if word.result == .accent { Text("Check the accent") }
                                            else if word.result == .missing { Text("Not recognized") }
                                            else if word.result == .incorrect { Text("You entered: \(word.received ?? "")") }
                                        }.font(.subheadline).foregroundStyle(word.result == .correct ? theme.theme.accent : theme.theme.ink)
                                    }
                                    if !feedback.extraWords.isEmpty { Text("Extra words: \(feedback.extraWords.joined(separator: ", "))").font(.footnote) }
                                    Text(viewModel.mode == "Speak" ? "Recognition can miss words. This is practice feedback, not a pronunciation score." : "Compared with this book’s sentence. Other translations may also be valid.").font(.caption).foregroundStyle(theme.theme.muted)
                                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(theme.theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        InlineError(message: viewModel.error ?? viewModel.audio.error)
                        HStack {
                            Button("Previous") { Task { await viewModel.back() } }.disabled(viewModel.index == 0 || viewModel.busy)
                        }.font(.footnote)
                    }.padding(25)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Button(viewModel.nextTitle + "  →") { Task { await viewModel.next() } }
                        .buttonStyle(PrimaryButton()).disabled(viewModel.busy)
                        .padding(.horizontal, 25).padding(.top, 12).padding(.bottom, 12)
                        .background(theme.theme.paper)
                }
                .background(theme.theme.paper).foregroundStyle(theme.theme.ink)
            }
        }.navigationTitle(book.englishTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { viewModel.stop(); dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close lesson") } }
            .onAppear { viewModel.load(book) }.onDisappear { viewModel.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { viewModel.stop() } }
    }
    private func highlighted(_ text: String) -> Text {
        guard let range = viewModel.audio.spokenRange, Range(range, in: text) != nil else { return Text(text) }
        var styled = AttributedString(text)
        if let attributedRange = Range(range, in: styled) { styled[attributedRange].foregroundColor = theme.theme.accent; styled[attributedRange].font = .system(.title, design: .serif, weight: .bold) }
        return Text(styled)
    }
}
