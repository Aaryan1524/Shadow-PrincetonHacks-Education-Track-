import AVFoundation
import Foundation

// MARK: - WebSocket Protocol Models

struct VoiceMessage: Codable {
    let type: String
    let data: String?
    let stepIndex: Int?
    let coachResponse: CoachResponse?

    enum CodingKeys: String, CodingKey {
        case type, data
        case stepIndex = "step_index"
        case coachResponse = "coach_response"
    }
}

struct VoiceResponse: Codable {
    let type: String
    let data: String?
    let reply: String?
    let message: String?
}

// MARK: - VoiceSessionManager

@MainActor
final class VoiceSessionManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isProcessing = false
    @Published var lastReply = ""
    @Published var errorMessage: String?

    // Audio engine
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?

    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Buffers
    private var audioBuffer = Data()
    private var silenceFrameCount = 0
    private let silenceThreshold: Float = 0.01
    // At 16kHz with 200ms chunks, 1.5s = ~7.5 chunks
    private let silenceFramesNeeded = 7
    private var hasSentEndOfSpeech = false

    // State
    private var currentLessonId: String?
    private var pingTimer: Timer?
    private var sendTimer: Timer?

    private let encoder = JSONEncoder()

    // MARK: - Public API

    func connect(lessonId: String) async {
        currentLessonId = lessonId
        errorMessage = nil

        // Configure audio session for play and record
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        // Build WebSocket URL
        let httpBase = ShadowAPI.baseURL
        let wsBase = httpBase
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: "\(wsBase)/ws/sessions/\(lessonId)") else {
            errorMessage = "Invalid WebSocket URL"
            return
        }

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        urlSession = session
        let task = session.webSocketTask(with: url)
        webSocket = task
        task.resume()

        isConnected = true
        receiveWebSocketMessages()
        startPingTimer()
        startAudioCapture()
    }

    func disconnect() {
        stopAudioCapture()
        pingTimer?.invalidate()
        pingTimer = nil
        sendTimer?.invalidate()
        sendTimer = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnected = false
        isProcessing = false
        audioBuffer = Data()
        silenceFrameCount = 0
        hasSentEndOfSpeech = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func updateCoachResponse(_ response: CoachResponse, stepIndex: Int) {
        let msg = VoiceMessage(
            type: "context_update",
            data: nil,
            stepIndex: stepIndex,
            coachResponse: response
        )
        sendVoiceMessage(msg)
    }

    // MARK: - Audio Capture

    private func startAudioCapture() {
        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!

        // Install tap — the hardware format may differ, so we convert
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0 else {
            errorMessage = "No microphone available"
            return
        }

        // Use a converter to get 16kHz mono PCM16
        let converter = AVAudioConverter(from: hardwareFormat, to: desiredFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self, let converter else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * desiredFormat.sampleRate / hardwareFormat.sampleRate
            )
            guard frameCount > 0 else { return }

            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            // Extract PCM bytes
            let length = Int(convertedBuffer.frameLength) * 2 // 16-bit = 2 bytes per sample
            guard let int16Data = convertedBuffer.int16ChannelData else { return }
            let data = Data(bytes: int16Data[0], count: length)

            // Calculate RMS for silence detection
            var sumSquares: Float = 0
            let sampleCount = Int(convertedBuffer.frameLength)
            for i in 0..<sampleCount {
                let sample = Float(int16Data[0][i]) / Float(Int16.max)
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(max(sampleCount, 1)))

            Task { @MainActor in
                self.audioBuffer.append(data)
                self.detectSilence(rms: rms)
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "Mic start error: \(error.localizedDescription)"
            return
        }

        // Send audio chunks every 200ms
        sendTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushAudioBuffer()
            }
        }
    }

    private func stopAudioCapture() {
        sendTimer?.invalidate()
        sendTimer = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    private func flushAudioBuffer() {
        guard !audioBuffer.isEmpty else { return }
        let chunk = audioBuffer
        audioBuffer = Data()
        sendAudioChunk(chunk)
    }

    private func detectSilence(rms: Float) {
        if rms < silenceThreshold {
            silenceFrameCount += 1
            if silenceFrameCount >= silenceFramesNeeded && !hasSentEndOfSpeech {
                hasSentEndOfSpeech = true
                // Flush remaining audio first
                flushAudioBuffer()
                let msg = VoiceMessage(type: "end_of_speech", data: nil, stepIndex: nil, coachResponse: nil)
                sendVoiceMessage(msg)
            }
        } else {
            silenceFrameCount = 0
            hasSentEndOfSpeech = false
        }
    }

    private func sendAudioChunk(_ data: Data) {
        let b64 = data.base64EncodedString()
        let msg = VoiceMessage(type: "audio_chunk", data: b64, stepIndex: nil, coachResponse: nil)
        sendVoiceMessage(msg)
    }

    // MARK: - Audio Playback

    private func playAudio(base64MP3: String) {
        guard let mp3Data = Data(base64Encoded: base64MP3) else {
            print("[Voice] Failed to decode base64 MP3")
            return
        }
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(data: mp3Data)
            audioPlayer?.play()
        } catch {
            print("[Voice] MP3 playback error: \(error)")
        }
    }

    // MARK: - WebSocket Send

    private func sendVoiceMessage(_ msg: VoiceMessage) {
        guard let data = try? encoder.encode(msg),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(jsonString)) { error in
            if let error {
                print("[Voice] Send error: \(error)")
            }
        }
    }

    // MARK: - WebSocket Receive

    private func receiveWebSocketMessages() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleServerMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleServerMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    // Continue listening
                    self.receiveWebSocketMessages()

                case .failure(let error):
                    print("[Voice] WebSocket receive error: \(error)")
                    self.isConnected = false
                    self.errorMessage = "Connection lost. Reconnecting..."
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let response = try? JSONDecoder().decode(VoiceResponse.self, from: data) else {
            print("[Voice] Failed to parse server message: \(text.prefix(100))")
            return
        }

        switch response.type {
        case "ready":
            print("[Voice] Server ready")
            isConnected = true
            errorMessage = nil

        case "processing":
            isProcessing = true

        case "audio_response":
            isProcessing = false
            if let reply = response.reply {
                lastReply = reply
            }
            if let audioData = response.data {
                playAudio(base64MP3: audioData)
            }

        case "error":
            isProcessing = false
            errorMessage = response.message ?? "Unknown error"

        case "pong":
            break

        default:
            print("[Voice] Unknown message type: \(response.type)")
        }
    }

    // MARK: - Keepalive & Reconnect

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            let msg = VoiceMessage(type: "ping", data: nil, stepIndex: nil, coachResponse: nil)
            self?.sendVoiceMessage(msg)
        }
    }

    private func scheduleReconnect() {
        guard let lessonId = currentLessonId else { return }
        stopAudioCapture()
        pingTimer?.invalidate()
        sendTimer?.invalidate()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !self.isConnected else { return }
            await self.connect(lessonId: lessonId)
        }
    }
}
