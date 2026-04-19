import MWDATCore
import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var viewModel: WearablesViewModel
    var onBack: (() -> Void)? = nil
    var onSelectLesson: (APILesson) -> Void

    @State private var lessons: [APILesson] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color.shadowCream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.shadowOrange)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)

                // Glasses connection banner
                if viewModel.registrationState != .registered {
                    HStack(spacing: 8) {
                        Image(systemName: "eyeglasses")
                            .foregroundColor(.white)
                        Text("Connect Meta glasses to start a session")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Spacer()
                        Button("Connect") { viewModel.connectGlasses() }
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.shadowOrange)
                }

                if isLoading {
                    Spacer()
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(.shadowOrange)
                        Text("Loading lessons...")
                            .font(.subheadline)
                            .foregroundColor(.shadowSecondary)
                    }
                    Spacer()
                } else if let error = loadError {
                    errorView(error)
                } else if lessons.isEmpty {
                    emptyView
                } else {
                    lessonListView
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            guard lessons.isEmpty else { return }
            await fetchLessons()
        }
    }

    // MARK: - Lesson List

    private var lessonListView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Choose a Lesson")
                    .font(.system(size: 26, weight: .light, design: .serif))
                    .foregroundColor(.shadowPrimary)
                Text("Select what you'd like to learn today")
                    .font(.system(size: 14))
                    .foregroundColor(.shadowSecondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(lessons) { lesson in
                        LessonCard(lesson: lesson) {
                            onSelectLesson(lesson)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }

            Button {
                Task { await fetchLessons() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.subheadline)
                .foregroundColor(.shadowOrange)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundColor(.shadowOrange.opacity(0.5))
            Text("No Lessons Yet")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundColor(.shadowPrimary)
            Text("Create a lesson from the backend to get started.")
                .font(.subheadline)
                .foregroundColor(.shadowSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await fetchLessons() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.shadowOrange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(32)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(.shadowOrange.opacity(0.6))
            Text("Couldn't Load Lessons")
                .font(.system(size: 20, weight: .light, design: .serif))
                .foregroundColor(.shadowPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.shadowSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await fetchLessons() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.shadowOrange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(32)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.shadowPrimary)
                    Text(lesson.description)
                        .font(.system(size: 13))
                        .foregroundColor(.shadowSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(lesson.steps.count) steps")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.shadowOrange.opacity(0.1))
                    .foregroundColor(.shadowOrange)
                    .cornerRadius(8)
            }

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                    Text("Start Learning")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.shadowOrange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(18)
        .background(Color.shadowCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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
                .foregroundColor(.shadowOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.shadowPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.shadowSecondary)
            }
            Spacer()
        }
    }
}
