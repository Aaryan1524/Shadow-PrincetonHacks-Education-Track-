import MWDATCore
import SwiftUI

struct StreamView: View {
    @ObservedObject var streamVM: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    var onBack: (() -> Void)? = nil

    @ObservedObject private var voiceVM: VoiceSessionManager

    @State private var unifiedMessage: String = ""
    @State private var isVoiceMessage: Bool = false

    init(streamVM: StreamSessionViewModel, wearablesVM: WearablesViewModel, onBack: (() -> Void)? = nil) {
        self.streamVM = streamVM
        self.wearablesVM = wearablesVM
        self.onBack = onBack
        self.voiceVM = streamVM.voiceVM
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            // Video preview
            if let frame = streamVM.currentVideoFrame, streamVM.hasReceivedFirstFrame {
                GeometryReader { geometry in
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .edgesIgnoringSafeArea(.all)
            } else if streamVM.isStreaming {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text(streamVM.streamingStatus == .waiting ? "Waiting for device..." : "Starting stream...")
                        .foregroundColor(.white)
                }
            }

            // Controls overlay
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    // Back button — stops stream and returns to lesson selection
                    Button {
                        Task {
                            await streamVM.stopSession()
                            onBack?()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    Spacer()
                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
                .padding()

                // Step progress bar
                if let lesson = streamVM.currentLesson, streamVM.isStreaming {
                    VStack(spacing: 4) {
                        HStack {
                            Text(lesson.title)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Text("Step \(streamVM.currentStepIndex + 1)/\(streamVM.totalSteps)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        ProgressView(value: Double(streamVM.currentStepIndex), total: Double(max(streamVM.totalSteps, 1)))
                            .tint(.green)

                        if let step = streamVM.currentStep {
                            Text(step.instruction)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()

                // Unified Coaching Bubble
                if !unifiedMessage.isEmpty, streamVM.isStreaming {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: isVoiceMessage ? "waveform" : (streamVM.stepCompleted ? "checkmark.circle.fill" : "brain.head.profile"))
                            .foregroundColor(isVoiceMessage ? .purple : (streamVM.stepCompleted ? .green : .blue))
                        Text(unifiedMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(isVoiceMessage ? AnyShapeStyle(Color.purple.opacity(0.25)) : AnyShapeStyle(.ultraThinMaterial))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Live transcript
                if !voiceVM.liveTranscript.isEmpty, streamVM.isStreaming {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.orange)
                        Text(voiceVM.liveTranscript)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .italic()
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                // Voice coach status
                if streamVM.currentLesson != nil, streamVM.isStreaming {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(voiceVM.isConnected ? (voiceVM.isListening ? Color.green : Color.yellow) : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(voiceStatusText)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Bottom controls
                if streamVM.isStreaming {
                    HStack(spacing: 24) {
                        // Stop button
                        Button {
                            Task { await streamVM.stopSession() }
                        } label: {
                            Text("Stop")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        // Capture button
                        Button {
                            streamVM.capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                                    .frame(width: 64, height: 64)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 54, height: 54)
                            }
                        }
                        .disabled(streamVM.isCapturingPhoto || streamVM.streamingStatus != .streaming)
                    }
                    .padding(.bottom, 32)
                } else {
                    // Start streaming button
                    Button {
                        Task { await streamVM.handleStartStreaming() }
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Start Streaming")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(streamVM.hasActiveDevice ? Color.shadowOrange : Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!streamVM.hasActiveDevice)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .onChange(of: streamVM.coachingMessage) { _, newValue in
            if !newValue.isEmpty {
                unifiedMessage = newValue
                isVoiceMessage = false
            }
        }
        .onChange(of: voiceVM.lastReply) { _, newValue in
            if !newValue.isEmpty {
                unifiedMessage = newValue
                isVoiceMessage = true
            }
        }
        .onDisappear {
            Task {
                if streamVM.isStreaming {
                    await streamVM.stopSession()
                }
            }
        }
        .sheet(isPresented: $streamVM.showPhotoPreview) {
            if let photo = streamVM.capturedPhoto {
                PhotoPreviewView(photo: photo) {
                    streamVM.dismissPhotoPreview()
                }
            }
        }
        .alert("Streaming Error", isPresented: $streamVM.showError) {
            Button("OK") { streamVM.dismissError() }
        } message: {
            Text(streamVM.errorMessage)
        }
    }

    private var statusColor: Color {
        switch streamVM.streamingStatus {
        case .streaming: return .green
        case .waiting: return .yellow
        case .stopped: return .red
        }
    }

    private var voiceStatusText: String {
        if voiceVM.isProcessing { return "Coach is thinking..." }
        if voiceVM.isListening { return "Listening..." }
        if voiceVM.isConnected { return "Ready — just speak" }
        return "Voice offline"
    }

    private var statusText: String {
        switch streamVM.streamingStatus {
        case .streaming: return "Live"
        case .waiting: return "Connecting..."
        case .stopped: return "Not streaming"
        }
    }
}
