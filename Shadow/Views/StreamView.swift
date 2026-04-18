import MWDATCore
import SwiftUI

struct StreamView: View {
    @ObservedObject var streamVM: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel

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
            VStack {
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

                Spacer()

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
