import SwiftUI

struct AuthorPortrait: View {
    let author: Author
    var size: CGFloat = 76
    var body: some View {
        Image(author.portrait).resizable().scaledToFill()
            .frame(width: size, height: size).clipShape(Circle())
            .accessibilityHidden(true)
    }
}
