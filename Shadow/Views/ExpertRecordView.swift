import AVFoundation
import AVKit
import PhotosUI
import SwiftUI

struct ExpertRecordView: View {
    var onStepsGenerated: ([APIStep], String) -> Void
    var onCancel: () -> Void

    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @State private var selectedVideoURL: URL?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showVideoPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.shadowCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.shadowOrange.opacity(0.1))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 28))
                                    .foregroundColor(.shadowOrange)
                            }
                            Text("Record a Lesson")
                                .font(.system(size: 24, weight: .light, design: .serif))
                                .foregroundColor(.shadowPrimary)
                            Text("Record yourself performing a task, and AI will break it into teachable steps.")
                                .font(.system(size: 14))
                                .foregroundColor(.shadowSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                        // Lesson details card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Lesson Details")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.shadowSecondary)
                                .textCase(.uppercase)
                                .tracking(0.8)

                            VStack(spacing: 10) {
                                styledTextField("Title (e.g. \"Make Pour-Over Coffee\")", text: $taskTitle)
                                styledTextField("Description of the task", text: $taskDescription)
                            }
                        }
                        .padding(18)
                        .background(Color.shadowCard)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 24)

                        // Video selection
                        VStack(spacing: 12) {
                            if let url = selectedVideoURL {
                                VStack(spacing: 14) {
                                    VideoPlayer(player: AVPlayer(url: url))
                                        .frame(height: 220)
                                        .cornerRadius(14)
                                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)

                                    Button {
                                        selectedVideoURL = nil
                                    } label: {
                                        Label("Choose Different Video", systemImage: "arrow.triangle.2.circlepath")
                                            .font(.subheadline)
                                            .foregroundColor(.shadowOrange)
                                    }
                                }
                                .padding(.horizontal, 24)
                            } else {
                                Button {
                                    showVideoPicker = true
                                } label: {
                                    VStack(spacing: 10) {
                                        Image(systemName: "video.fill.badge.plus")
                                            .font(.system(size: 32))
                                            .foregroundColor(.shadowOrange.opacity(0.7))
                                        Text("Select Video from Library")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.shadowPrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 150)
                                    .background(Color.shadowCard)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.shadowOrange.opacity(0.2), lineWidth: 1.5)
                                    )
                                }
                                .padding(.horizontal, 24)
                            }
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 24)
                        }

                        // Generate button
                        if selectedVideoURL != nil {
                            Button {
                                Task { await generateSteps() }
                            } label: {
                                HStack(spacing: 10) {
                                    if isGenerating {
                                        ProgressView().tint(.white)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isGenerating ? "Gemini is watching..." : "Analyze Recording")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        if isGenerating {
                                            Text("This may take a minute for long videos")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.75))
                                        }
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(canGenerate ? Color.shadowOrange : Color.shadowSecondary.opacity(0.4))
                                .cornerRadius(14)
                            }
                            .disabled(!canGenerate)
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Expert Mode")
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
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker(videoURL: $selectedVideoURL)
            }
        }
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14))
            .padding(12)
            .background(Color.shadowCream.opacity(0.6))
            .cornerRadius(10)
            .foregroundColor(.shadowPrimary)
    }

    private var canGenerate: Bool {
        !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
        && !taskDescription.trimmingCharacters(in: .whitespaces).isEmpty
        && selectedVideoURL != nil
        && !isGenerating
    }

    // MARK: - Generate Steps

    private func generateSteps() async {
        guard let url = selectedVideoURL else { return }
        isGenerating = true
        errorMessage = nil

        do {
            let steps = try await ShadowAPIClient.shared.generateSteps(
                videoURL: url,
                taskDescription: taskDescription
            )
            onStepsGenerated(steps, taskTitle)
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }

        isGenerating = false
    }
}

// MARK: - Video Picker

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier("public.movie") else { return }

            provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                guard let url, error == nil else { return }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                try? FileManager.default.copyItem(at: url, to: tempURL)

                DispatchQueue.main.async {
                    self.parent.videoURL = tempURL
                }
            }
        }
    }
}
