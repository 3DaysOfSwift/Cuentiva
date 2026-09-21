//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct ReaderBadgesView: View {
    let badges: [ReaderBadge]
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your reading honours").font(.system(.title2, design: .serif))
            ForEach(badges) { badge in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "seal.fill")
                        .font(.title).foregroundStyle(theme.theme.rewardGold)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(badge.title).font(.headline)
                        Text(badge.detail).font(.subheadline).foregroundStyle(theme.theme.muted)
                    }
                }.accessibilityElement(children: .combine)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
            .background(theme.theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}
