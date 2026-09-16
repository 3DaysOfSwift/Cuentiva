import SwiftUI
import UIKit

/// SwiftUI onAppear can precede a presentation transition. UIKit's callback waits
/// for the containing presentation to finish, without guessing a delay.
struct ViewDidAppearObserver: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> ObserverController {
        let controller = ObserverController()
        controller.action = action
        return controller
    }

    func updateUIViewController(_ controller: ObserverController, context: Context) {
        controller.action = action
    }

    final class ObserverController: UIViewController {
        var action: (() -> Void)?
        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            action?()
        }
    }
}
