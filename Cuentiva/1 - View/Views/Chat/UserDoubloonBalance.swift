import SwiftUI

struct UserDoubloonBalance: View {
    let count: Int
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 14) {
            PersonalStorytellerButton(feature: AppModel.shared.fantasy, size: 64)
            Divider().frame(height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your balance")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.theme.muted)
                DoubloonBalance(count: count, size: 38)
                    .font(.title2.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
    }
}
