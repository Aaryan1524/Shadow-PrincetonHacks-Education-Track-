import SwiftUI

// MARK: - Models
struct RecordingStep: Identifiable {
    let id = UUID()
    var stepNumber: Int
    let image: UIImage
    var aiDescription: String
}

// MARK: - Main Expert View
struct ExpertView: View {
    @State private var steps: [RecordingStep] = []
    @State private var isProcessing = false
    @State private var showPublish = false

    private let green = Color(red: 0.22, green: 0.50, blue: 0.12)
    private let darkGreen = Color(red: 0.08, green: 0.20, blue: 0.06)

    var body: some View {
        ZStack {
            // Sky background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.53, green: 0.81, blue: 0.98), location: 0.0),
                    .init(color: Color(red: 0.78, green: 0.91, blue: 1.00), location: 0.38),
                    .init(color: Color(red: 0.95, green: 0.88, blue: 0.74), location: 0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Grass bottom
            VStack(spacing: 0) {
                Color.clear.frame(height: UIScreen.main.bounds.height * 0.50)
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.35, green: 0.62, blue: 0.22), location: 0.0),
                        .init(color: Color(red: 0.20, green: 0.42, blue: 0.12), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxHeight: .infinity)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step list
                ScrollView {
                    VStack(spacing: 10) {
                        if steps.isEmpty && !isProcessing {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 48))
                                    .foregroundStyle(darkGreen.opacity(0.5))
                                Text("No steps yet")
                                    .font(.custom("CopernicusTrial-Book", size: 16))
                                    .foregroundStyle(darkGreen.opacity(0.6))
                                Text("Tap below to capture your first step")
                                    .font(.custom("CopernicusTrial-Book", size: 13))
                                    .foregroundStyle(darkGreen.opacity(0.4))
                            }
                            .padding(.top, 60)
                        }

                        ForEach(steps) { step in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(green)
                                        .frame(width: 28, height: 28)
                                    Text("\(step.stepNumber)")
                                        .font(.custom("CopernicusTrial-Book", size: 13))
                                        .foregroundStyle(.white)
                                }
                                Text(step.aiDescription)
                                    .font(.custom("CopernicusTrial-Book", size: 14))
                                    .foregroundStyle(darkGreen)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }

                        if isProcessing {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Processing step...")
                                    .font(.custom("CopernicusTrial-Book", size: 14))
                                    .foregroundStyle(darkGreen.opacity(0.7))
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 90)
                    .padding(.bottom, 120)
                }

                // Bottom action bar
                VStack(spacing: 10) {
                    Button {
                        isProcessing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            let n = steps.count + 1
                            steps.append(RecordingStep(stepNumber: n, image: UIImage(), aiDescription: "Step \(n): captured action"))
                            isProcessing = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Capture Step \(steps.count + 1)")
                                .font(.custom("CopernicusTrial-Book", size: 16))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isProcessing ? Color.gray.opacity(0.5) : green)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(isProcessing)
                    .buttonStyle(.plain)

                    if !steps.isEmpty {
                        Button {
                            showPublish = true
                        } label: {
                            Text("Finish & Publish (\(steps.count) steps)")
                                .font(.custom("CopernicusTrial-Book", size: 14))
                                .foregroundStyle(darkGreen.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showPublish) {
            PublishTutorialView(recordedSteps: steps)
        }
    }
}

#Preview {
    ExpertView()
}

