//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct ChatTypingIndicator: View {
    let storyteller: String
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { context in
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(theme.theme.chatSecondaryText)
                        .frame(width: 7, height: 7)
                        .offset(y: offset(for: index, at: context.date))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(theme.theme.chatReceived, in: ChatBubbleShape(tailOnRight: layoutDirection == .rightToLeft))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(storyteller) is typing")
    }

    private func offset(for index: Int, at date: Date) -> CGFloat {
        guard !reduceMotion, scenePhase == .active else { return 0 }
        let beat = date.timeIntervalSince(started).truncatingRemainder(dividingBy: 1.2) - Double(index) * 0.24
        guard beat >= 0, beat < 0.24 else { return 0 }
        return -6 * sin(beat / 0.24 * .pi)
    }
}
