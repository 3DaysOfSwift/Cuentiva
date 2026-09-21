//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

struct InlineError: View {
    @Environment(ThemeManager.self) private var theme
    let message: String?
    var body: some View { if let message { Label(message, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(theme.theme.error).fixedSize(horizontal: false, vertical: true).accessibilityLabel("Notice: \(message)") } }
}
