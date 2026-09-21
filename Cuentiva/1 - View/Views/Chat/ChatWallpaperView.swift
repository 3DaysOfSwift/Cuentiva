//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct ChatWallpaperView: View {
    @Environment(ThemeManager.self) private var theme
    private let symbols = ["book.closed", "leaf", "globe.americas", "cup.and.saucer",
        "sailboat", "moon.stars", "key", "bird", "map", "sparkles", "bicycle", "sun.max",
        "tram", "scissors", "bell", "backpack"]

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 76
            let columns = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for row in 0..<rows {
                for column in 0..<columns {
                    let index = (row * 5 + column * 3) % symbols.count
                    let image = context.resolve(Text(Image(systemName: symbols[index]))
                        .font(.system(size: 29, weight: .ultraLight))
                        .foregroundColor(theme.theme.muted))
                    var tile = context
                    tile.translateBy(x: CGFloat(column) * spacing + (row.isMultiple(of: 2) ? 12 : 48),
                                     y: CGFloat(row) * spacing + 25)
                    tile.rotate(by: .degrees(Double((row + column) % 3 - 1) * 18))
                    tile.draw(image, at: .zero)
                }
            }
        }
        .opacity(0.045)
        .background(theme.theme.chatWallpaper)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
