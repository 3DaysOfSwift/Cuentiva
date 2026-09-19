import Observation

/// This reveal is paced by the reader. The saved completion already grants access.
@MainActor @Observable final class WritingUnlockedViewModel {
    enum Stage { case announcement, invitation, character }
    private(set) var stage: Stage = .announcement

    func next() {
        switch stage {
        case .announcement: stage = .invitation
        case .invitation: stage = .character
        case .character: break
        }
    }
}
