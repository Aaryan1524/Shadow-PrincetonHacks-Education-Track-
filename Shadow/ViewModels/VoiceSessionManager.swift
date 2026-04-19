import AVFoundation
import Combine
import Speech
import UIKit

// MARK: - VoiceSessionManager
// Single-agent voice coach: iOS Speech (STT) → Claude /coach API → AVSpeechSynthesizer (TTS)

@MainActor
final class VoiceSessionManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var lastReply = ""
    @Published var errorMessage: String?
    @Published var liveTranscript = ""

    // Provide the latest frame from the AR stream
    var getLatestFrame: (() -> UIImage?)?

    // Called when the user voice-commands to advance the step
    var onAdvanceStep: (() -> Void)?

    // State
    private var currentLessonId: String?
    var currentStepIndex: Int = 0
    private var latestCoachResponse: CoachResponse?
    private var conversationHistory: [ConversationMessage] = []
    
    // Silence tracking
    private var lastResultTime: Date = Date()
    private var lastTranscript: String = ""

    // If the user speaks WHILE the AI is processing, queue it here
    private var pendingUserMessage: String? = nil

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // TTS
    private let synthesizer = AVSpeechSynthesizer()

    // API
    private let api = ShadowAPIClient.shared

    // MARK: - Public API

    func connect(lessonId: String, lessonTitle: String, stepIndex: Int = 0) async {
        if isConnected && currentLessonId == lessonId {
            print("[Shadow] Voice coach already connected for lesson \(lessonId), skipping reset.")
            return
        }

        currentLessonId = lessonId
        currentStepIndex = stepIndex
        conversationHistory = []
        latestCoachResponse = nil
        errorMessage = nil

        // Request speech recognition permission
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }

        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        isConnected = true
        print("[Shadow] Voice coach connected for lesson \(lessonId) at step \(stepIndex)")

        // Start the conversation naturally
        Task {
            let prompt = stepIndex == 0 
                ? "System: We just started the lesson '\(lessonTitle)'. Provide a natural, brief spoken greeting to get the user started, like 'Are you ready to make some coffee together?' and wait for their response."
                : "System: We are resuming the lesson '\(lessonTitle)' after a brief interruption. we are currently on Step \(stepIndex + 1). Briefly say something like 'Okay, I'm back. Let's pick up where we left off on step \(stepIndex + 1).'"
            
            await sendToCoach(message: prompt)
        }
    }

    func disconnect() {
        stopListening()
        synthesizer.stopSpeaking(at: .immediate)
        isConnected = false
        isProcessing = false
        isListening = false
        liveTranscript = ""
        currentLessonId = nil
        conversationHistory = []
        latestCoachResponse = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("[Shadow] Voice coach disconnected")
    }

    func updateCoachResponse(_ response: CoachResponse, stepIndex: Int) {
        latestCoachResponse = response
        currentStepIndex = stepIndex
    }

    // MARK: - Speech Recognition (STT)

    func startListening() {
        guard isConnected, !isListening else { return }

        // Stop any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }

        // Use cloud recognition for fast, responsive partial results
        recognitionRequest.requiresOnDeviceRecognition = false
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            errorMessage = "No microphone available"
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Mic start error: \(error.localizedDescription)"
            return
        }

        isListening = true
        liveTranscript = ""
        print("[Shadow] Listening started")

        // Track silence to auto-send using class properties so Tasks share state
        self.lastResultTime = Date()
        self.lastTranscript = ""

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString
                    self.liveTranscript = transcript
                    self.lastResultTime = Date()
                    self.lastTranscript = transcript

                    if result.isFinal {
                        self.handleFinalTranscript(transcript)
                    }
                }

                if error != nil {
                    if !self.lastTranscript.isEmpty {
                        self.handleFinalTranscript(self.lastTranscript)
                    } else {
                        self.stopListeningInternal()
                        if self.isConnected {
                            self.startListening()
                        }
                    }
                }
            }
        }

        // Auto-send after silence timeout
        Task { [weak self] in
            let silenceTimeoutLimit: TimeInterval = 0.9

            while self?.isListening == true {
                try? await Task.sleep(nanoseconds: 200_000_000) // check every 0.2s
                guard let self, self.isListening else { break }
                let elapsed = Date().timeIntervalSince(self.lastResultTime)
                
                if elapsed > silenceTimeoutLimit && !self.lastTranscript.isEmpty {
                    self.handleFinalTranscript(self.lastTranscript)
                    self.lastTranscript = ""
                    break
                }
            }
        }
    }

    private func handleFinalTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stopListeningInternal()

        if isProcessing {
            // AI is still thinking — queue this message, it will be sent as soon as the reply comes back
            print("[Shadow] User spoke while processing — queuing: '\(trimmed)'")
            pendingUserMessage = trimmed
            return
        }

        print("[Shadow] User said: \(trimmed)")
        Task {
            await sendToCoach(message: trimmed)
        }
    }

    private func stopListeningInternal() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    func stopListening() {
        stopListeningInternal()
        liveTranscript = ""
    }

    // MARK: - Send to Claude Coach API

    private func sendToCoach(message: String) async {
        guard let lessonId = currentLessonId else { return }

        isProcessing = true
        liveTranscript = ""

        // Stop mic before calling API to prevent the AI from hearing itself
        stopListeningInternal()

        // Get current frame as base64 if available
        var frameB64: String? = nil
        if let frame = getLatestFrame?(), let jpegData = frame.jpegData(compressionQuality: 0.5) {
            frameB64 = jpegData.base64EncodedString()
        }

        let request = CoachRequest(
            frameB64: frameB64,
            stepIndex: currentStepIndex,
            lessonId: lessonId,
            conversationHistory: conversationHistory,
            userMessage: message
        )

        do {
            let response = try await api.coach(lessonId: lessonId, request: request)
            lastReply = response.reply
            conversationHistory = response.updatedHistory
            print("[Shadow] Coach replied: \(response.reply.prefix(80))...")
            isProcessing = false

            // If the user asked to move on, fire the advance callback before speaking
            if response.advanceStep {
                print("[Shadow] User requested step advance via voice command")
                onAdvanceStep?()
            }

            // If user already spoke, send their queued message instead of reading it out loud
            if let queued = pendingUserMessage {
                pendingUserMessage = nil
                print("[Shadow] Flushing queued message: '\(queued)'")
                await sendToCoach(message: queued)
            } else {
                // Speak the reply — mic restarts in AVSpeechSynthesizerDelegate after TTS finishes
                speak(response.reply)
            }
        } catch {
            print("[Shadow] Coach API error: \(error)")
            lastReply = "Sorry, I couldn't reach the coach."
            errorMessage = "Coach unavailable"
            isProcessing = false
            pendingUserMessage = nil

            // Resume listening on error
            if isConnected {
                startListening()
            }
        }
    }

    // MARK: - Text-to-Speech (TTS)

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        // Try Enhanced neural voice first, fall back to standard
        if let enhanced = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-US.Zoe") {
            utterance.voice = enhanced
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = 0.50
        utterance.pitchMultiplier = 0.95
        utterance.preUtteranceDelay = 0.2

        // Resume listening after speech finishes
        synthesizer.delegate = self
        synthesizer.speak(utterance)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceSessionManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Resume listening after TTS finishes
            if self.isConnected {
                self.startListening()
            }
        }
    }
}
