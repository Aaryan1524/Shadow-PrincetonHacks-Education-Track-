import Combine
import MWDATCore
import SwiftUI

@MainActor
class WearablesViewModel: ObservableObject {
    @Published var devices: [DeviceIdentifier]
    @Published var registrationState: RegistrationState
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private var registrationTask: Task<Void, Never>?
    private var deviceStreamTask: Task<Void, Never>?
    private let wearables: WearablesInterface

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.devices = wearables.devices
        self.registrationState = wearables.registrationState

        deviceStreamTask = Task {
            for await devices in wearables.devicesStream() {
                self.devices = devices
            }
        }

        registrationTask = Task {
            for await state in wearables.registrationStateStream() {
                self.registrationState = state
            }
        }
    }

    deinit {
        registrationTask?.cancel()
        deviceStreamTask?.cancel()
    }

    func connectGlasses() {
        guard registrationState != .registering else { return }
        Task { @MainActor in
            do {
                try await wearables.startRegistration()
            } catch let error as RegistrationError {
                showError(error.description)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func disconnectGlasses() {
        Task { @MainActor in
            do {
                try await wearables.startUnregistration()
            } catch let error as UnregistrationError {
                showError(error.description)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
    }
}
