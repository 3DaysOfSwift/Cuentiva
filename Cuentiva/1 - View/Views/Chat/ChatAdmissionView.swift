import SwiftUI

struct ChatAdmissionView: View {
    let coins: Int
    let celebrating: Bool
    let confirm: () -> Bool
    @ScaledMetric(relativeTo: .headline) private var handleSize: CGFloat = 62
    @Namespace private var coinAnimation
    @Environment(ThemeManager.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                DoubloonIcon(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost: 1 doubloon").font(.title2.weight(.semibold))
                    Text("One topic. Keep the conversation going.")
                        .font(.subheadline).foregroundStyle(theme.theme.muted)
                }
                Spacer(minLength: 0)
            }
            .opacity(celebrating ? 0 : 1)
            DoubloonBalance(count: coins).font(.subheadline)
                .opacity(celebrating ? 0 : 1)
            Text("Reserved when you slide. Charged after your first successful reply. Leaving before a reply returns the coin.")
                .font(.footnote).foregroundStyle(theme.theme.muted)
                .opacity(celebrating ? 0 : 1)
            if celebrating {
                Color.clear.frame(height: handleSize + 12)
            } else {
                SlideToStartView(confirm: confirm, coinAnimation: coinAnimation)
            }
        }
        .accessibilityHidden(celebrating)
        .padding(20)
        .overlay {
            if celebrating {
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(theme.theme.checkButtonBackground)
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(theme.theme.checkButtonForeground)
                            .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                    }
                    .frame(width: 80, height: 80)
                    .matchedGeometryEffect(id: "admission-coin", in: coinAnimation, properties: reduceMotion ? [] : .frame)
                    .accessibilityLabel("Coin reserved")
                    DoubloonBalance(count: coins)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("\(coins) doubloons remaining")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.theme.paper)
        .overlay(alignment: .top) { Rectangle().fill(theme.theme.muted.opacity(0.45)).frame(height: 1) }
    }
}
