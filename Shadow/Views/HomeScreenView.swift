import MWDATCore
import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var viewModel: WearablesViewModel
    var onSelectLesson: (APILesson) -> Void

    @State private var lessons: [APILesson] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)

            if viewModel.registrationState != .registered {
                connectView
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading lessons...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if let error = loadError {
                errorView(error)
            } else if lessons.isEmpty {
                emptyView
            } else {
                lessonListView
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.registrationState) { newState in
            if newState == .registered {
                Task { await fetchLessons() }
            }
        }
    }

    // MARK: - Connect View (pre-registration)

    private var connectView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "eyeglasses")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100)
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Shadow")
                    .font(.largeTitle.bold())
                Text("Connect your Meta glasses to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "video.fill", title: "Live Streaming", subtitle: "Stream video from your glasses in real-time")
                FeatureRow(icon: "camera.fill", title: "Photo Capture", subtitle: "Capture photos directly from your glasses")
                FeatureRow(icon: "hand.raised.fill", title: "Hands-Free", subtitle: "Stay connected without reaching for your phone")
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Text("You'll be redirected to Meta AI to confirm your connection.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.connectGlasses()
                } label: {
                    Text(viewModel.registrationState == .registering ? "Connecting..." : "Connect My Glasses")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.registrationState == .registering ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(viewModel.registrationState == .registering)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Lesson List

    private var lessonListView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Choose a Lesson")
                    .font(.title2.bold())
                Text("Select what you'd like to learn today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(lessons) { lesson in
                        LessonCard(lesson: lesson) {
                            onSelectLesson(lesson)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }

            // Refresh button at bottom
            Button {
                Task { await fetchLessons() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Lessons Available")
                .font(.title3.bold())
            Text("Create a lesson from the backend to get started.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await fetchLessons() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Failed to Load Lessons")
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await fetchLessons() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Fetch

    private func fetchLessons() async {
        isLoading = true
        loadError = nil
        do {
            lessons = try await ShadowAPIClient.shared.fetchLessons()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Lesson Card

struct LessonCard: View {
    let lesson: APILesson
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.headline)
                    Text(lesson.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(lesson.steps.count) steps")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }

            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Learning")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
