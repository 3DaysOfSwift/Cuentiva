//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct SlideToStartView: View {
    let confirm: () -> Bool
    let coinAnimation: Namespace.ID
    var title = "Slide to start"
    var cost = 1
    var paymentHint = "One doubloon covers up to 100 sent messages. Charged after the first successful reply."
    @State private var model = SlideToStartViewModel()
    @GestureState private var translation: CGFloat = 0
    @Environment(ThemeManager.self) private var theme
    @Environment(\.layoutDirection) private var direction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var handleSize: CGFloat = 62

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.width - handleSize - 12)
            let reverse = direction == .rightToLeft
            let distance = min(travel, max(0, reverse ? -translation : translation))
            ZStack(alignment: .leading) {
                Capsule().fill(theme.theme.surface)
                Capsule().strokeBorder(theme.theme.rewardGold.opacity(0.45), lineWidth: 1)
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    Image(systemName: "chevron.forward").font(.caption.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, handleSize * 0.6)
                .foregroundStyle(theme.theme.ink)
                .opacity(model.confirmed ? 0 : 1 - Double(distance / max(1, travel)))
                DoubloonIcon(size: handleSize)
                    .matchedGeometryEffect(id: "admission-coin", in: coinAnimation, properties: reduceMotion ? [] : .frame)
                    .padding(6)
                    .offset(x: (reverse ? -1 : 1) * (model.confirmed ? travel : distance))
                    .gesture(DragGesture(minimumDistance: 8)
                        .updating($translation) { value, state, _ in state = value.translation.width }
                        .onEnded { value in
                            model.finish(translation: value.translation.width, travel: travel,
                                rightToLeft: reverse, confirm: confirm)
                        })
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: translation)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) for \(cost) \(cost == 1 ? "doubloon" : "doubloons")")
            .accessibilityHint(paymentHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.activate(confirm: confirm) }
        }
        .frame(height: handleSize + 12)

    }
}
