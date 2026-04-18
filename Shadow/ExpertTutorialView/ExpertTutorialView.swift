import SwiftUI

struct PublishTutorialView: View {
    @Environment(\.dismiss) var dismiss
    @State private var tutorialTitle: String = ""
    @State private var isUploading: Bool = false
    @State private var selectedCategory: TutorialCategory?
    
    // Pass the recorded steps from ExpertView
    let recordedSteps: [RecordingStep]
    
    // Using your specific categories
    let mockCategories: [TutorialCategory] = [
        .init(name: "Home", icon: "house"),
        .init(name: "Cooking", icon: "fork.knife"),
        .init(name: "Fitness", icon: "figure.run"),
        .init(name: "Tech", icon: "laptopcomputer"),
        .init(name: "Crafts", icon: "scissors")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // 1. Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TUTORIAL TITLE")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g., How to tie a Windsor knot", text: $tutorialTitle)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top)

                    // 2. Category Dropdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SELECT CATEGORY")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        Menu {
                            ForEach(mockCategories) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Label(category.name, systemImage: category.icon)
                                }
                            }
                        } label: {
                            HStack {
                                if let selected = selectedCategory {
                                    Label(selected.name, systemImage: selected.icon)
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("Select a Category")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // 3. Validation Checklist
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Tutorial Title added", systemImage: tutorialTitle.trimmingCharacters(in: .whitespaces).isEmpty ? "circle" : "checkmark.circle.fill")
                            .foregroundStyle(tutorialTitle.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                        
                        Label("Category selected", systemImage: selectedCategory == nil ? "circle" : "checkmark.circle.fill")
                            .foregroundStyle(selectedCategory == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                    }
                    .font(.caption)
                    .padding(.vertical, 8)

                    // 4. Visual Step Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("STEPS (\(recordedSteps.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        if recordedSteps.isEmpty {
                            Text("No steps recorded yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recordedSteps) { step in
                                        VStack {
                                            Image(uiImage: step.image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            Text("Step \(step.stepNumber)")
                                                .font(.caption2.bold())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            // 5. Action Footer
            VStack(spacing: 12) {
                Button(action: publishTutorial) {
                    ZStack {
                        if isUploading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Publish to Shadow")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canPublish ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canPublish || isUploading)
                
                if !isUploading {
                    Button("Discard and Exit") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
        }
        .navigationTitle("Finalize Tutorial")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isUploading)
    }

    // Validation logic
    var canPublish: Bool {
        let titleIsValid = !tutorialTitle.trimmingCharacters(in: .whitespaces).isEmpty
        let categoryIsSelected = selectedCategory != nil
        let hasSteps = !recordedSteps.isEmpty
        
        return titleIsValid && categoryIsSelected && hasSteps
    }

    func publishTutorial() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        
        isUploading = true
        
        // Simulation of network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            generator.notificationOccurred(.success)
            isUploading = false
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        PublishTutorialView(recordedSteps: [
            RecordingStep(stepNumber: 1, image: UIImage(systemName: "camera.fill")!, aiDescription: "Mock Step")
        ])
    }
}
