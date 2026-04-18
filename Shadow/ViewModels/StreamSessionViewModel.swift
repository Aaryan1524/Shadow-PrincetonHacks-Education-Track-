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

    // Coach conversation
    @Published var conversationHistory: [ConversationMessage] = []
    @Published var coachReply: String = ""
    @Published var isSendingMessage: Bool = false

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
    }

    // MARK: - Lesson Management

    func loadLesson(id: String) async {
        do {
            currentLesson = try await api.fetchLesson(id: id)
            currentStepIndex = 0
            coachingMessage = ""
            stepCompleted = false
            conversationHistory = []
        } catch {
            showError("Failed to load lesson: \(error.localizedDescription)")
        }
    }

    func setLesson(_ lesson: APILesson) {
        currentLesson = lesson
        currentStepIndex = 0
        coachingMessage = ""
        stepCompleted = false
        conversationHistory = []
    }

    // MARK: - Streaming

    func handleStartStreaming() async {
        let permission = Permission.camera
        do {
            var status = try await wearables.checkPermissionStatus(permission)
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
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
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

            if response.stepCompleted {
                // Auto-advance to next step
                if currentStepIndex + 1 < lesson.steps.count {
                    currentStepIndex += 1
                    stepCompleted = false
                    coachingMessage = response.nextStepHint.isEmpty
                        ? "Step complete! Moving to next step."
                        : "Step complete! Next: \(response.nextStepHint)"
                    conversationHistory = []
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

    // MARK: - Coach Conversation

    func sendCoachMessage(_ message: String) async {
        guard let lesson = currentLesson, !message.isEmpty else { return }
        isSendingMessage = true

        let frameB64: String?
        if let frame = currentVideoFrame, let data = frame.jpegData(compressionQuality: 0.5) {
            frameB64 = data.base64EncodedString()
        } else {
            frameB64 = nil
        }

        let request = CoachRequest(
            frameB64: frameB64,
            stepIndex: currentStepIndex,
            lessonId: lesson.id,
            conversationHistory: conversationHistory,
            userMessage: message
        )

        do {
            let response = try await api.coach(lessonId: lesson.id, request: request)
            coachReply = response.reply
            conversationHistory = response.updatedHistory
        } catch {
            coachReply = "Sorry, I couldn't reach the coach. Try again."
        }
        isSendingMessage = false
    }

    // MARK: - Private

    private func startSession() async {
        guard let deviceSession = await sessionManager.getSession() else { return }
        guard deviceSession.state == .started else { return }

        let config = StreamSessionConfig(
            videoCodec: VideoCodec.raw,
            resolution: StreamingResolution.low,
            frameRate: 24
        )

        guard let stream = try? deviceSession.addStream(config: config) else { return }
        streamSession = stream
        streamingStatus = .waiting
        setupListeners(for: stream)
        await stream.start()
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
        case .waitingForDevice, .starting, .stopping, .paused:
            streamingStatus = .waiting
        case .streaming:
            streamingStatus = .streaming
            // Start verify loop when streaming begins and a lesson is loaded
            if currentLesson != nil {
                startVerifyLoop()
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
        default:
            showError("Streaming error occurred.")
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
