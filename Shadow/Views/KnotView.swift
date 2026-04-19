import SwiftUI
import KnotAPI

struct KnotView: UIViewControllerRepresentable {
    let sessionId: String
    let clientId: String
    var onSuccess: ((String) -> Void)?
    var onExit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess, onExit: onExit)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard !context.coordinator.hasOpened else { return }
        context.coordinator.hasOpened = true

        let customerConfiguration = CustomerConfiguration(
            cardName: "Card Name",
            customerName: "Customer Name",
            logoId: "LogoId"
        )

        let config = KnotConfiguration(
            sessionId: sessionId,
            clientId: clientId,
            environment: .development,
            entryPoint: "onboarding",
            useCategories: true,
            useSearch: true,
            merchantIds: [52],
            metadata: ["reference_token": "your-token"],
            customerConfiguration: customerConfiguration,
            locale: "es-US"
        )

        Knot.open(configuration: config, delegate: context.coordinator)
    }

    class Coordinator: NSObject, KnotDelegate {
        var hasOpened = false
        var onSuccess: ((String) -> Void)?
        var onExit: (() -> Void)?

        init(onSuccess: ((String) -> Void)?, onExit: (() -> Void)?) {
            self.onSuccess = onSuccess
            self.onExit = onExit
        }

        func onSuccess(institutionId: String) {
            onSuccess?(institutionId)
        }

        func onExit() {
            onExit?()
        }

        func onEvent(name: String, metadata: [String: Any]) {
            print("Knot event: \(name), metadata: \(metadata)")
        }
    }
}
