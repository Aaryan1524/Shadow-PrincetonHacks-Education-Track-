import Combine
import MWDATCore
import SwiftUI

/// Manages DeviceSession lifecycle with 1:1 device-to-session mapping.
/// Matches the sample CameraAccess app pattern exactly.
@MainActor
final class DeviceSessionManager: ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var hasActiveDevice: Bool = false

    private let wearables: WearablesInterface
    private let deviceSelector: AutoDeviceSelector
    private var deviceSession: DeviceSession?
    private var deviceMonitorTask: Task<Void, Never>?
    private var stateObserverTask: Task<Void, Never>?

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.deviceSelector = AutoDeviceSelector(wearables: wearables)
        startDeviceMonitoring()
    }

    deinit {
        deviceMonitorTask?.cancel()
        stateObserverTask?.cancel()
    }

    /// Returns a ready DeviceSession, creating one if needed.
    /// Waits for the session to reach .started state before returning.
    func getSession() async -> DeviceSession? {
        if let session = deviceSession, session.state == .started {
            isReady = true
            return session
        }

        if deviceSession?.state == .stopped {
            deviceSession = nil
        }

        guard deviceSession == nil else { return nil }

        do {
            let session = try wearables.createSession(deviceSelector: deviceSelector)
            deviceSession = session

            let stateStream = session.stateStream()
            try session.start()

            for await state in stateStream {
                if state == .started {
                    isReady = true
                    startStateObserver(for: session)
                    return session
                } else if state == .stopped {
                    isReady = false
                    deviceSession = nil
                    return nil
                }
            }
        } catch {
            isReady = false
            deviceSession = nil
        }
        return nil
    }

    // MARK: - Private

    private func startDeviceMonitoring() {
        deviceMonitorTask = Task { [weak self] in
            guard let self else { return }
            for await device in deviceSelector.activeDeviceStream() {
                hasActiveDevice = device != nil
                if device != nil {
                    _ = await getSession()
                } else {
                    handleDeviceLost()
                }
            }
        }
    }

    private func startStateObserver(for session: DeviceSession) {
        stateObserverTask?.cancel()
        stateObserverTask = Task { [weak self] in
            for await state in session.stateStream() {
                guard let self else { return }
                if state == .started {
                    isReady = true
                } else if state == .stopped {
                    isReady = false
                    deviceSession = nil
                    return
                }
            }
        }
    }

    private func handleDeviceLost() {
        stateObserverTask?.cancel()
        stateObserverTask = nil
        deviceSession?.stop()
        deviceSession = nil
        isReady = false
    }
}
