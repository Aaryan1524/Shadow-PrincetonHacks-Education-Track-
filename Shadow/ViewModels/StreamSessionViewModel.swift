import Combine
import MWDATCamera
import MWDATCore
import SwiftUI

enum StreamingStatus {
    case streaming
    case waiting
    case stopped
}

@MainActor
final class StreamSessionViewModel: ObservableObject {
    @Published var currentVideoFrame: UIImage?
    @Published var hasReceivedFirstFrame: Bool = false
    @Published var streamingStatus: StreamingStatus = .stopped

    @Published var capturedPhoto: UIImage?
    @Published var showPhotoPreview: Bool = false
    @Published var isCapturingPhoto: Bool = false

    @Published var hasActiveDevice: Bool = false
    @Published var isDeviceSessionReady: Bool = false

    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // MARK: - Coaching State

    @Published var currentLesson: APILesson?
    @Published var currentStepIndex: Int = 0
    @Published var coachingMessage: String = ""
    @Published var stepCompleted: Bool = false
    @Published var coachConfidence: Double = 0.0
    @Published var isVerifying: Bool = false

    // Gemini voice coach
    let voiceVM = VoiceSessionManager()

    var isStreaming: Bool { streamingStatus != .stopped }

    var currentStep: APIStep? {
        guard let lesson = currentLesson,
              currentStepIndex < lesson.steps.count else { return nil }
        return lesson.steps[currentStepIndex]
    }

    var totalSteps: Int { currentLesson?.steps.count ?? 0 }
    var isLessonComplete: Bool { currentStepIndex >= totalSteps }

    private let sessionManager: DeviceSessionManager
    private let wearables: WearablesInterface
    private var streamSession: StreamSession?
    private var cancellables = Set<AnyCancellable>()

    private var stateListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?
    private var photoDataListenerToken: AnyListenerToken?

    private var verifyTask: Task<Void, Never>?
    private let api = ShadowAPIClient.shared

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        self.sessionManager = DeviceSessionManager(wearables: wearables)

        sessionManager.$hasActiveDevice
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasActiveDevice)
        sessionManager.$isReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isDeviceSessionReady)

        // Bind the vision context to the voice coach
        voiceVM.getLatestFrame = { [weak self] in
            return self?.currentVideoFrame
        }

        // Allow the voice coach to advance the step if user says "next"/"skip"
        voiceVM.onAdvanceStep = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.advanceStep()
            }
        }
    }

    // Manually advance to the next step (triggered by voice or other UI)
    func advanceStep() {
        guard let lesson = currentLesson,
              currentStepIndex + 1 < lesson.steps.count else { return }
        currentStepIndex += 1
        stepCompleted = false
        voiceVM.currentStepIndex = currentStepIndex
        coachingMessage = "Moving to step \(currentStepIndex + 1)..."
        print("[Shadow] Step manually advanced to \(currentStepIndex)")
    }

    // MARK: - Lesson Management

    func loadLesson(id: String) async {
        do {
            currentLesson = try await api.fetchLesson(id: id)
            currentStepIndex = 0
            coachingMessage = ""
            stepCompleted = false
        } catch {
            showError("Failed to load lesson: \(error.localizedDescription)")
        }
    }

    func setLesson(_ lesson: APILesson) {
        currentLesson = lesson
        currentStepIndex = 0
        coachingMessage = ""
        stepCompleted = false
    }

    // MARK: - Streaming

    func handleStartStreaming() async {
        print("[Shadow] handleStartStreaming called, hasActiveDevice=\(hasActiveDevice), streamingStatus=\(streamingStatus)")
        let permission = Permission.camera
        do {
            var status = try await wearables.checkPermissionStatus(permission)
            print("[Shadow] Permission status: \(status)")
            if status != .granted {
                status = try await wearables.requestPermission(permission)
            }
            guard status == .granted else {
                showError("Camera permission denied")
                return
            }
            await startSession()
        } catch {
            showError("Permission error: \(error.localizedDescription)")
        }
    }

    func stopSession() async {
        guard let stream = streamSession else { return }
        streamSession = nil
        clearListeners()
        stopVerifyLoop()
        voiceVM.disconnect()
        streamingStatus = .stopped
        currentVideoFrame = nil
        hasReceivedFirstFrame = false
        await stream.stop()
    }

    func capturePhoto() {
        guard !isCapturingPhoto, streamingStatus == .streaming else { return }
        isCapturingPhoto = true
        let success = streamSession?.capturePhoto(format: .jpeg) ?? false
        if !success {
            isCapturingPhoto = false
        }
    }

    func dismissPhotoPreview() {
        showPhotoPreview = false
        capturedPhoto = nil
    }

    func dismissError() {
        showError = false
        errorMessage = ""
    }

    // MARK: - Verify Step Loop

    func startVerifyLoop() {
        guard currentLesson != nil else { return }
        stopVerifyLoop()
        verifyTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.verifyCurrentStep()
                try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
            }
        }
    }

    func stopVerifyLoop() {
        verifyTask?.cancel()
        verifyTask = nil
    }

    private func verifyCurrentStep() async {
        guard let lesson = currentLesson,
              currentStepIndex < lesson.steps.count,
              let frame = currentVideoFrame,
              !isVerifying else { return }

        isVerifying = true
        do {
            let response = try await api.verifyStep(
                lessonId: lesson.id,
                stepIndex: currentStepIndex,
                frame: frame
            )
            coachingMessage = response.coachingMessage
            stepCompleted = response.stepCompleted
            coachConfidence = response.confidence

            // Feed vision context to voice coach
            voiceVM.updateCoachResponse(response, stepIndex: currentStepIndex)

            if response.stepCompleted {
                // Use the shared advanceStep() to prevent double-advance races
                // and keep the voice agent in sync
                if currentStepIndex + 1 < lesson.steps.count {
                    advanceStep()
                    // Override the generic message with the vision's specific hint
                    if !response.nextStepHint.isEmpty {
                        coachingMessage = "Step complete! Next: \(response.nextStepHint)"
                    }
                } else {
                    stopVerifyLoop()
                    coachingMessage = "Lesson complete! Great job!"
                }
            }
        } catch {
            // Silently continue — network hiccups shouldn't interrupt the learner
        }
        isVerifying = false
    }

    // MARK: - Private

    private func startSession() async {
        streamingStatus = .waiting

        // Retry up to 3 times — the glasses' Activity Manager sometimes rejects
        // the first attempt while cleaning up from a previous session.
        let maxRetries = 3
        for attempt in 1...maxRetries {
            print("[Shadow] startSession: attempt \(attempt)/\(maxRetries)")

            if let deviceSession = await sessionManager.getSession(),
               deviceSession.state == .started {

                let config = StreamSessionConfig(
                    videoCodec: VideoCodec.raw,
                    resolution: StreamingResolution.low,
                    frameRate: 24
                )

                if let stream = try? deviceSession.addStream(config: config) {
                    print("[Shadow] startSession: stream added, starting...")
                    streamSession = stream
                    setupListeners(for: stream)
                    await stream.start()
                    print("[Shadow] startSession: stream.start() returned")
                    return
                } else {
                    print("[Shadow] startSession: addStream failed")
                }
            } else {
                print("[Shadow] startSession: getSession returned nil or not started")
            }

            // Wait before retrying (increasing delay)
            if attempt < maxRetries {
                let delay = UInt64(attempt) * 2_000_000_000 // 2s, 4s
                print("[Shadow] startSession: waiting before retry...")
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        // All retries exhausted
        streamingStatus = .stopped
        showError("Could not connect to glasses. Close the Meta AI app, close & reopen the hinges, then try again.")
    }

    private func setupListeners(for stream: StreamSession) {
        stateListenerToken = stream.statePublisher.listen { [weak self] state in
            Task { @MainActor in self?.handleStateChange(state) }
        }

        videoFrameListenerToken = stream.videoFramePublisher.listen { [weak self] frame in
            Task { @MainActor in self?.handleVideoFrame(frame) }
        }

        errorListenerToken = stream.errorPublisher.listen { [weak self] error in
            Task { @MainActor in self?.handleStreamError(error) }
        }

        photoDataListenerToken = stream.photoDataPublisher.listen { [weak self] data in
            Task { @MainActor in self?.handlePhotoData(data) }
        }
    }

    private func clearListeners() {
        stateListenerToken = nil
        videoFrameListenerToken = nil
        errorListenerToken = nil
        photoDataListenerToken = nil
    }

    private func handleStateChange(_ state: StreamSessionState) {
        switch state {
        case .stopped:
            currentVideoFrame = nil
            streamingStatus = .stopped
            voiceVM.disconnect()
        case .waitingForDevice, .starting, .stopping, .paused:
            streamingStatus = .waiting
        case .streaming:
            streamingStatus = .streaming
            // Start verify loop and voice coach when streaming begins with a lesson
            if let lesson = currentLesson {
                startVerifyLoop()
                Task { await voiceVM.connect(lessonId: lesson.id, lessonTitle: lesson.title, stepIndex: currentStepIndex) }
            }
        }
    }

    private func handleVideoFrame(_ frame: VideoFrame) {
        if let image = frame.makeUIImage() {
            currentVideoFrame = image
            if !hasReceivedFirstFrame {
                hasReceivedFirstFrame = true
            }
        }
    }

    private func handleStreamError(_ error: StreamSessionError) {
        print("[Shadow] Stream error: \(error)")
        // Clean up the failed stream so we can start fresh
        streamSession = nil
        clearListeners()
        stopVerifyLoop()
        voiceVM.disconnect()
        streamingStatus = .stopped
        currentVideoFrame = nil
        hasReceivedFirstFrame = false

        switch error {
        case .deviceNotFound:
            showError("Device not found. Ensure your glasses are connected.")
        case .deviceNotConnected:
            showError("Device disconnected. Check your connection.")
        case .timeout:
            showError("Connection timed out. Please try again.")
        case .permissionDenied:
            showError("Camera permission denied.")
        case .hingesClosed:
            showError("Glasses hinges closed. Open them and try again.")
        case .thermalCritical:
            showError("Device overheating. Streaming paused.")
        case .internalError:
            showError("Connection lost. Please try streaming again.")
        default:
            showError("Streaming error: \(error)")
        }
    }

    private func handlePhotoData(_ data: PhotoData) {
        isCapturingPhoto = false
        if let image = UIImage(data: data.data) {
            capturedPhoto = image
            showPhotoPreview = true
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
