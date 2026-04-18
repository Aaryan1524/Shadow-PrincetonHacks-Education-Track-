import SwiftUI
import Combine

// MARK: - Models
// Defined at the top level so PublishTutorialView can see it if in the same target
struct RecordingStep: Identifiable {
    let id = UUID()
    var stepNumber: Int
    let image: UIImage
    var aiDescription: String
    var isProcessing: Bool = false
}

// MARK: - Main Expert View
struct ExpertView: View {
    @StateObject private var viewModel = ExpertRecordingViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var showingImagePicker = false
    @State private var selectedStep: RecordingStep? = nil
    @State private var showingExitConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header progress bar
                StepProgressBar(stepCount: viewModel.steps.count)
                    .padding(.horizontal)
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 16) {
                        // List of captured steps
                        ForEach(viewModel.steps) { step in
                            CompletedStepCard(step: step) {
                                selectedStep = step
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation { viewModel.removeStep(at: step.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        // AI Loading State
                        if viewModel.isProcessing {
                            ProcessingCard()
                        }

                        // Capture Button
                        if !viewModel.isProcessing {
                            CaptureNextStepCard(
                                stepNumber: viewModel.steps.count + 1,
                                onCapture: { showingImagePicker = true }
                            )
                        }
                    }
                    .padding()
                }

                // Bottom bar with NavigationLink to Publish page
                BottomActionBar(
                    steps: viewModel.steps,
                    isProcessing: viewModel.isProcessing
                )
            }
            .navigationTitle("Record Tutorial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if viewModel.steps.isEmpty {
                            dismiss()
                        } else {
                            showingExitConfirmation = true
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
            .alert("Discard Tutorial?", isPresented: $showingExitConfirmation) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Continue Recording", role: .cancel) {}
            } message: {
                Text("Are you sure you want to exit? All progress will be lost.")
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            MockImagePickerView { image in
                viewModel.addStep(with: image)
            }
        }
        .sheet(item: $selectedStep) { step in
            StepReviewSheet(step: step) { updatedDescription in
                viewModel.updateDescription(for: step.id, description: updatedDescription)
            } onDelete: {
                withAnimation { viewModel.removeStep(at: step.id) }
            }
        }
    }
}

// MARK: - Supporting Components

struct StepProgressBar: View {
    let stepCount: Int
    let maxSteps = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(stepCount) / \(maxSteps)").font(.caption.bold())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stepCount == 0 ? AnyShapeStyle(Color.clear) : AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)))
                        .frame(width: geo.size.width * CGFloat(min(stepCount, maxSteps)) / CGFloat(maxSteps), height: 6)
                        .animation(.spring(duration: 0.4), value: stepCount)
                }
            }
            .frame(height: 6)
        }
        .padding(.bottom, 8)
    }
}

struct CompletedStepCard: View {
    let step: RecordingStep
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 32, height: 32)
                    Text("\(step.stepNumber)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
                Image(uiImage: step.image).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 8))
                Text(step.aiDescription).font(.subheadline).foregroundStyle(.primary).lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ProcessingCard: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            ProgressView().padding(.trailing, 8)
            Text("AI is transcribing\(String(repeating: ".", count: dotCount))").font(.subheadline.bold())
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(timer) { _ in dotCount = (dotCount + 1) % 4 }
    }
}

struct CaptureNextStepCard: View {
    let stepNumber: Int
    let onCapture: () -> Void

    var body: some View {
        Button(action: onCapture) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.largeTitle).foregroundStyle(.blue)
                Text("Add Step \(stepNumber)").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6])))
        }
        .buttonStyle(.plain)
    }
}

struct BottomActionBar: View {
    let steps: [RecordingStep]
    let isProcessing: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("\(steps.count) Steps").font(.subheadline.bold()).padding(8).background(Color(.systemGray6)).clipShape(Capsule())
                Spacer()
                
                // Navigates to the Publish page, passing the collected steps
                NavigationLink(destination: PublishTutorialView(recordedSteps: steps)) {
                    Text("Finish & Publish")
                        .font(.headline).foregroundStyle(.white).padding(.horizontal, 30).padding(.vertical, 12)
                        .background {
                            if !steps.isEmpty && !isProcessing {
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            } else { Color.gray }
                        }
                        .clipShape(Capsule())
                }
                .disabled(steps.isEmpty || isProcessing)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

struct StepReviewSheet: View {
    let step: RecordingStep
    let onSave: (String) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var editedDescription: String = ""

    init(step: RecordingStep, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.step = step
        self.onSave = onSave
        self.onDelete = onDelete
        _editedDescription = State(initialValue: step.aiDescription)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: step.image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)).padding()
                    VStack(alignment: .leading) {
                        Text("EDIT TRANSCRIPTION").font(.caption.bold()).foregroundStyle(.secondary)
                        TextEditor(text: $editedDescription).frame(minHeight: 120).padding(8).background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Step \(step.stepNumber)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Delete", role: .destructive) { onDelete(); dismiss() }.foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { onSave(editedDescription); dismiss() }.bold()
                }
            }
        }
    }
}

struct MockImagePickerView: View {
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 20) {
            Text("Camera Simulator").font(.headline)
            Button("Capture Action") {
                onSelect(UIImage(systemName: "camera.fill") ?? UIImage())
                dismiss()
            }.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - ViewModel
@MainActor
class ExpertRecordingViewModel: ObservableObject {
    @Published var steps: [RecordingStep] = []
    @Published var isProcessing = false

    func addStep(with image: UIImage) {
        isProcessing = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            let nextNumber = steps.count + 1
            let desc = "AI transcribes this as step \(nextNumber) for your tutorial."
            steps.append(RecordingStep(stepNumber: nextNumber, image: image, aiDescription: desc))
            isProcessing = false
        }
    }

    func removeStep(at id: UUID) {
        steps.removeAll(where: { $0.id == id })
        for i in 0..<steps.count { steps[i].stepNumber = i + 1 }
    }

    func updateDescription(for id: UUID, description: String) {
        if let index = steps.firstIndex(where: { $0.id == id }) {
            steps[index].aiDescription = description
        }
    }
}

#Preview {
    ExpertView()
}
