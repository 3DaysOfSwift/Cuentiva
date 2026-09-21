//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct WholeBookInvitationView: View {
    let book: Book
    let onRead: () -> Void
    let onFinish: () -> Void
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 70)).foregroundStyle(theme.theme.accent)
                Text("You know the story.\nNow read it your way.")
                    .font(.system(.largeTitle, design: .serif))
                BookCover(book: book, completed: true, compact: true).frame(width: 180)
                Text("All three chapters, together. Read in Spanish at your own pace, and tap a sentence if you need its English meaning.")
                    .foregroundStyle(theme.theme.muted)
                Text("Your book is completed and your reading reward is already saved.").font(.subheadline)
                Button("Finish for now", action: onFinish)
            }.multilineTextAlignment(.center).padding(28)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Read the whole book →", action: onRead).buttonStyle(PrimaryButton())
                .padding(24).background(theme.theme.paper).dockedAreaBorder()
        }.background(theme.theme.paper).foregroundStyle(theme.theme.ink)
    }
}
