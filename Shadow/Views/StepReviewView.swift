import SwiftUI

struct StepReviewView: View {
    let lessonTitle: String
    @State var steps: [EditableStep]
    var onSave: (APILesson) -> Void
    var onCancel: () -> Void

    @State private var lessonDescription = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(title: String, suggestedSteps: [APIStep], onSave: @escaping (APILesson) -> Void, onCancel: @escaping () -> Void) {
        self.lessonTitle = title
        self._steps = State(initialValue: suggestedSteps.map {
            EditableStep(
                instruction: $0.instruction,
                successCriteria: $0.successCriteria,
                timestampStart: $0.timestampStart,
                timestampEnd: $0.timestampEnd,
                tempoDescription: $0.tempoDescription,
                techniqueNotes: $0.techniqueNotes,
                context: $0.context,
                visualLandmarks: $0.visualLandmarks,
                commonFailurePoints: $0.commonFailurePoints,
                failureTriggers: $0.failureTriggers,
                arOverlayAnchor: $0.arOverlayAnchor
            )
        })
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.shadowCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header card
                            VStack(alignment: .leading, spacing: 10) {
                                Text(lessonTitle)
                                    .font(.system(size: 22, weight: .light, design: .serif))
                                    .foregroundColor(.shadowPrimary)
                                Text("Review and edit the AI-generated steps below.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.shadowSecondary)

                                styledTextField("Lesson description", text: $lessonDescription)
                                    .padding(.top, 4)
                            }
                            .padding(18)
                            .background(Color.shadowCard)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            // Steps
                            ForEach(steps.indices, id: \.self) { idx in
                                StepEditCard(
                                    stepNumber: idx + 1,
                                    step: $steps[idx],
                                    onDelete: steps.count > 1 ? { steps.remove(at: idx) } : nil
                                )
                            }

                            // Add step
                            Button {
                                steps.append(EditableStep(instruction: "", successCriteria: ""))
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.shadowOrange)
                                    Text("Add Step")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.shadowOrange)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.shadowCard)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.shadowOrange.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 20)

                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 20)
                            }

                            Spacer(minLength: 24)
                        }
                    }

                    // Save button
                    Button {
                        Task { await saveLesson() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text(isSaving ? "Saving..." : "Save Lesson")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(canSave ? Color.shadowOrange : Color.shadowSecondary.opacity(0.35))
                        .cornerRadius(14)
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.shadowCream)
                }
            }
            .navigationTitle("Review Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.shadowOrange)
                    }
                }
            }
        }
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14))
            .padding(12)
            .background(Color.shadowCream.opacity(0.7))
            .cornerRadius(10)
            .foregroundColor(.shadowPrimary)
    }

    private var canSave: Bool {
        !lessonDescription.trimmingCharacters(in: .whitespaces).isEmpty
        && steps.allSatisfy { !$0.instruction.trimmingCharacters(in: .whitespaces).isEmpty }
        && !isSaving
    }

    private func saveLesson() async {
        isSaving = true
        errorMessage = nil

        let stepRequests = steps.map {
            StepCreateRequest(
                instruction: $0.instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                timestampStart: $0.timestampStart,
                timestampEnd: $0.timestampEnd,
                tempoDescription: $0.tempoDescription,
                techniqueNotes: $0.techniqueNotes,
                context: $0.context,
                successCriteria: $0.successCriteria.trimmingCharacters(in: .whitespacesAndNewlines),
                visualLandmarks: $0.visualLandmarks,
                commonFailurePoints: $0.commonFailurePoints,
                failureTriggers: $0.failureTriggers,
                arOverlayAnchor: $0.arOverlayAnchor
            )
        }

        let request = LessonCreateRequest(
            title: lessonTitle,
            description: lessonDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            steps: stepRequests
        )

        do {
            let lesson = try await ShadowAPIClient.shared.createLesson(request)
            print("[Shadow] Lesson saved: \(lesson.id)")
            onSave(lesson)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }
}

// MARK: - Editable Step Model

struct EditableStep {
    var instruction: String
    var successCriteria: String
    var timestampStart: String = ""
    var timestampEnd: String = ""
    var tempoDescription: String = ""
    var techniqueNotes: String = ""
    var context: String = ""
    var visualLandmarks: String = ""
    var commonFailurePoints: String = ""
    var failureTriggers: String = ""
    var arOverlayAnchor: String = ""
}

// MARK: - Step Edit Card

struct StepEditCard: View {
    let stepNumber: Int
    @Binding var step: EditableStep
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("\(stepNumber)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.shadowOrange)
                        .clipShape(Circle())
                    Text("Step \(stepNumber)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.shadowPrimary)
                }
                Spacer()
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.6))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("INSTRUCTION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.shadowSecondary)
                    .tracking(0.8)
                TextField("What should the learner do?", text: $step.instruction, axis: .vertical)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.shadowCream.opacity(0.7))
                    .cornerRadius(8)
                    .lineLimit(2...4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("SUCCESS CRITERIA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.shadowSecondary)
                    .tracking(0.8)
                TextField("How to tell this step is done correctly", text: $step.successCriteria, axis: .vertical)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.shadowCream.opacity(0.7))
                    .cornerRadius(8)
                    .lineLimit(2...4)
            }
        }
        .padding(16)
        .background(Color.shadowCard)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}
