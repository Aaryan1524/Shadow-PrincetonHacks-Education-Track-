import SwiftUI
import KnotAPI

struct KnotView: UIViewControllerRepresentable {
    let sessionId: String
    let clientId: String
    var onSuccess: ((String) -> Void)?
    var onExitHandler: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess, onExitHandler: onExitHandler)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard !context.coordinator.hasOpened else { return }
        context.coordinator.hasOpened = true

        let config = KnotConfiguration(
            sessionId: sessionId,
            clientId: clientId,
            environment: .production,
            entryPoint: "onboarding",
            useCategories: false,
            useSearch: true,
            merchantIds: []
        )

        DispatchQueue.main.async {
            Knot.open(configuration: config, delegate: context.coordinator)
        }
    }

    class Coordinator: NSObject, KnotEventDelegate {
        var hasOpened = false
        var onSuccess: ((String) -> Void)?
        var onExitHandler: (() -> Void)?

        init(onSuccess: ((String) -> Void)?, onExitHandler: (() -> Void)?) {
            self.onSuccess = onSuccess
            self.onExitHandler = onExitHandler
        }

        func onSuccess(merchant: String) {
            onSuccess?(merchant)
        }

        func onExit() {
            // Don't close the sheet on onExit — let the user swipe down or succeed
        }

        func onError(error: KnotError) {
            print("Knot error: \(error)")
        }

        func onEvent(event: KnotEvent) {
            print("Knot event: \(event)")
        }
    }
}
