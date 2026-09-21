//
// Cuentiva
// Copyright © 2026 3DaysOfSwiftConcurrency.com.
// All rights reserved.
// See LICENSE for permitted use.
//

import SwiftUI

/// The saved reveal is the source of truth; no placeholder appears before choosing a character.
struct PersonalStorytellerButton: View {
    let feature: any FantasyFeature
    var size: CGFloat = 44
    @State private var showingProfile = false
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        if let creature = feature.profile?.creature {
            Button { showingProfile = true } label: {
                Image(creature.portrait).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(theme.theme.accent.opacity(0.18), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("My storyteller")
            .accessibilityHint("View and edit your character’s name and biography")
            .sheet(isPresented: $showingProfile) {
                StorytellerRevealView(feature: feature) { showingProfile = false }
            }
        }
    }
}
