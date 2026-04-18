import SwiftUI

// MARK: - Models
struct RecordingStep: Identifiable {
    let id = UUID()
    var stepNumber: Int
    let image: UIImage
    var aiDescription: String
}

private let inkWash = LinearGradient(
    stops: [
        .init(color: Color(red: 1.00, green: 1.00, blue: 0.89), location: 0.0),
        .init(color: Color(red: 0.80, green: 0.80, blue: 0.80), location: 1.0)
    ],
    startPoint: .top,
    endPoint: .bottom
)

// MARK: - Expert View (two-phase)
struct ExpertView: View {
    enum Phase { case setup, recording }

    @State private var phase: Phase = .setup
    // Setup fields
    @State private var tutorialTitle = ""
    @State private var selectedCategory = ""
    @State private var tutorialDescription = ""
    // Recording
    @State private var steps: [RecordingStep] = []
    @State private var isStreaming = false
    @State private var isCapturing = false
    @State private var showPublished = false

    private let accent    = Color(red: 0.43, green: 0.51, blue: 0.59)
    private let charcoal  = Color(red: 0.29, green: 0.29, blue: 0.29)
    private let categories = ["Cooking", "Home", "Fitness", "Tech", "Crafts", "DIY", "Other"]

    var body: some View {
        ZStack {
            // Background
            inkWash.ignoresSafeArea()

            if phase == .setup {
                setupView
            } else {
                recordingView
            }
        }
        .overlay(alignment: .bottom) {
            if showPublished {
                publishedBanner
            }
        }
    }

    // MARK: - Setup Screen
    var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Tutorial")
                        .font(.custom("CopernicusTrial-Book", size: 28))
                        .foregroundStyle(charcoal)
                    Text("Tell us what you're making before you record")
                        .font(.custom("CopernicusTrial-Book", size: 14))
                        .foregroundStyle(charcoal.opacity(0.6))
                }
                .padding(.top, 90)

                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text("TITLE")
                        .font(.custom("CopernicusTrial-Book", size: 11))
                        .foregroundStyle(charcoal.opacity(0.5))
                        .tracking(2)
                    TextField("e.g. How to make pasta from scratch", text: $tutorialTitle)
                        .font(.custom("CopernicusTrial-Book", size: 15))
                        .padding(14)
                        .background(Color.white.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Description field
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT ARE YOU MAKING?")
                        .font(.custom("CopernicusTrial-Book", size: 11))
                        .foregroundStyle(charcoal.opacity(0.5))
                        .tracking(2)
                    TextField("Brief description of the tutorial", text: $tutorialDescription)
                        .font(.custom("CopernicusTrial-Book", size: 15))
                        .padding(14)
                        .background(Color.white.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Category
                VStack(alignment: .leading, spacing: 10) {
                    Text("CATEGORY")
                        .font(.custom("CopernicusTrial-Book", size: 11))
                        .foregroundStyle(charcoal.opacity(0.5))
                        .tracking(2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(cat)
                                        .font(.custom("CopernicusTrial-Book", size: 14))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == cat ? accent : Color.white.opacity(0.5))
                                        .foregroundStyle(selectedCategory == cat ? .white : charcoal)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Start button
                Button {
                    withAnimation { phase = .recording }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "record.circle")
                        Text("Start Recording")
                            .font(.custom("CopernicusTrial-Book", size: 17))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canStart ? accent : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .disabled(!canStart)
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    var canStart: Bool {
        !tutorialTitle.trimmingCharacters(in: .whitespaces).isEmpty && !selectedCategory.isEmpty
    }

    // MARK: - Recording Screen
    var recordingView: some View {
        VStack(spacing: 0) {
            // Stream status bar
            HStack(spacing: 10) {
                Circle()
                    .fill(isStreaming ? Color.red : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(isStreaming ? Color.red.opacity(0.4) : .clear, lineWidth: 6)
                            .scaleEffect(isStreaming ? 1.8 : 1)
                            .animation(.easeInOut(duration: 0.9).repeatForever(), value: isStreaming)
                    )
                Text(isStreaming ? "Streaming from glasses  •  AI capturing steps" : "Not streaming")
                    .font(.custom("CopernicusTrial-Book", size: 13))
                    .foregroundStyle(charcoal.opacity(0.8))
                Spacer()
                Text(tutorialTitle)
                    .font(.custom("CopernicusTrial-Book", size: 12))
                    .foregroundStyle(charcoal.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.45))
            .padding(.top, 80)

            // Steps list
            ScrollView {
                VStack(spacing: 10) {
                    if steps.isEmpty && !isCapturing {
                        VStack(spacing: 12) {
                            Image(systemName: "glasses")
                                .font(.system(size: 44))
                                .foregroundStyle(charcoal.opacity(0.4))
                            Text("Start streaming from your glasses")
                                .font(.custom("CopernicusTrial-Book", size: 15))
                                .foregroundStyle(charcoal.opacity(0.55))
                            Text("AI will automatically detect and capture steps")
                                .font(.custom("CopernicusTrial-Book", size: 13))
                                .foregroundStyle(charcoal.opacity(0.35))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                        .padding(.horizontal, 30)
                    }

                    ForEach(steps) { step in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(accent).frame(width: 28, height: 28)
                                Text("\(step.stepNumber)")
                                    .font(.custom("CopernicusTrial-Book", size: 13))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Step \(step.stepNumber)")
                                    .font(.custom("CopernicusTrial-Book", size: 11))
                                    .foregroundStyle(charcoal.opacity(0.4))
                                    .tracking(1)
                                Text(step.aiDescription)
                                    .font(.custom("CopernicusTrial-Book", size: 14))
                                    .foregroundStyle(charcoal)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accent.opacity(0.7))
                                .font(.system(size: 16))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if isCapturing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("AI processing step...")
                                .font(.custom("CopernicusTrial-Book", size: 14))
                                .foregroundStyle(charcoal.opacity(0.7))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 140)
                .animation(.spring(duration: 0.4), value: steps.count)
            }

            // Bottom bar
            VStack(spacing: 10) {
                // Stream toggle
                Button {
                    withAnimation { isStreaming.toggle() }
                    if isStreaming {
                        simulateAutoCapture()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isStreaming ? "stop.circle.fill" : "play.circle.fill")
                        Text(isStreaming ? "Stop Stream" : "Start Stream from Glasses")
                            .font(.custom("CopernicusTrial-Book", size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isStreaming ? Color.red.opacity(0.85) : accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if !steps.isEmpty && !isStreaming {
                    Button {
                        withAnimation { showPublished = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showPublished = false }
                        }
                    } label: {
                        Text("Publish Tutorial  (\(steps.count) steps)")
                            .font(.custom("CopernicusTrial-Book", size: 14))
                            .foregroundStyle(charcoal.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
    }

    // Simulates AI auto-capturing steps while streaming
    private func simulateAutoCapture() {
        guard isStreaming else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard isStreaming else { return }
            isCapturing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isCapturing = false
                let n = steps.count + 1
                let descriptions = [
                    "Gathered all ingredients and tools",
                    "Prepared the workspace",
                    "Started the main process",
                    "Applied technique to material",
                    "Checked progress and adjusted",
                    "Completed the finishing step"
                ]
                let desc = n <= descriptions.count ? descriptions[n - 1] : "Completed action \(n)"
                withAnimation {
                    steps.append(RecordingStep(stepNumber: n, image: UIImage(), aiDescription: desc))
                }
                simulateAutoCapture()
            }
        }
    }

    // MARK: - Published Banner
    var publishedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tutorial Published!")
                    .font(.custom("CopernicusTrial-Book", size: 15))
                    .foregroundStyle(.white)
                Text("\(tutorialTitle) • \(selectedCategory)")
                    .font(.custom("CopernicusTrial-Book", size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(18)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    ExpertView()
}

