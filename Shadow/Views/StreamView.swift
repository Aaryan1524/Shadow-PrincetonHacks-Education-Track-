import MWDATCore
import SwiftUI

struct StreamView: View {
    @ObservedObject var streamVM: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel

    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool

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
                    if streamVM.isStreaming {
                        Button {
                            wearablesVM.disconnectGlasses()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
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

                // Coaching message bubble
                if !streamVM.coachingMessage.isEmpty, streamVM.isStreaming {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: streamVM.stepCompleted ? "checkmark.circle.fill" : "brain.head.profile")
                            .foregroundColor(streamVM.stepCompleted ? .green : .blue)
                        Text(streamVM.coachingMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Coach reply bubble
                if !streamVM.coachReply.isEmpty, streamVM.isStreaming {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.purple)
                        Text(streamVM.coachReply)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.purple.opacity(0.3))
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Message input for coach
                if streamVM.currentLesson != nil, streamVM.isStreaming {
                    HStack(spacing: 8) {
                        TextField("Ask your coach...", text: $messageText)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(20)
                            .foregroundColor(.white)
                            .focused($isMessageFieldFocused)

                        Button {
                            let msg = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !msg.isEmpty else { return }
                            messageText = ""
                            isMessageFieldFocused = false
                            Task { await streamVM.sendCoachMessage(msg) }
                        } label: {
                            Image(systemName: streamVM.isSendingMessage ? "ellipsis.circle" : "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(messageText.isEmpty ? .gray : .white)
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || streamVM.isSendingMessage)
                    }
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
                        .background(streamVM.hasActiveDevice ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(!streamVM.hasActiveDevice)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
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

    private var statusText: String {
        switch streamVM.streamingStatus {
        case .streaming: return "Live"
        case .waiting: return "Connecting..."
        case .stopped: return "Not streaming"
        }
    }
}
