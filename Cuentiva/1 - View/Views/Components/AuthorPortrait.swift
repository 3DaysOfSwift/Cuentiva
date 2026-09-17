import SwiftUI

/// Bundled character artwork keeps profiles available offline without remote image requests.
struct AuthorPortrait: View {
    let author: Author
    var size: CGFloat = 76
    var showsBorder = true
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        Group {
            if author.storyteller.portrait.hasPrefix("Storyteller"),
               Author.supportedPortraits.contains(author.storyteller.portrait) {
                Image(author.storyteller.portrait).resizable().scaledToFill()
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.48, weight: .regular))
                    .foregroundStyle(theme.theme.accent)
            }
        }
            .frame(width: size, height: size)
            .background(theme.theme.surface, in: Circle())
            .clipShape(Circle())
            .overlay {
                if showsBorder { Circle().strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1) }
            }
            .accessibilityHidden(true)
    }
}
