//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct StreakBar: View {
    let days: [WeekDay]
    @Environment(ThemeManager.self) private var theme
    var body: some View {
        HStack(spacing: 7) {
            ForEach(days) { day in
                VStack(spacing: 5) {
                    Text(day.label).font(.caption2.weight(.semibold))
                    Image(systemName: day.revived ? "arrow.counterclockwise.circle.fill" : day.practiced ? "checkmark.circle.fill" : day.today ? "circle.inset.filled" : "circle")
                        .font(.title3).opacity(day.revived || day.practiced || day.today ? 1 : 0.35)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.id): \(day.revived ? "streak revived" : day.practiced ? "practiced" : "not practiced")")
            }
        }.foregroundStyle(theme.theme.accent).padding(.vertical, 4)
    }
}
