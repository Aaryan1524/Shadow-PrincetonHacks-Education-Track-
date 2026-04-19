import MWDATCore
import SwiftUI

// MARK: - Design Tokens (shared across all views)
extension Color {
    static let shadowCream  = Color(red: 0.949, green: 0.929, blue: 0.902)
    static let shadowOrange = Color(red: 0.910, green: 0.396, blue: 0.102)
    static let shadowCard   = Color.white
    static let shadowPrimary   = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let shadowSecondary = Color(red: 0.45, green: 0.45, blue: 0.45)
}

enum AppMode {
    case roleSelection
    case learner
    case expertRecord
    case expertReview(steps: [APIStep], title: String)
}

struct MainAppView: View {
    @StateObject private var wearablesVM: WearablesViewModel
    @StateObject private var streamVM: StreamSessionViewModel

    @State private var appMode: AppMode = .roleSelection
    @State private var selectedLesson: APILesson?

    private let wearables: WearablesInterface

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        _wearablesVM = StateObject(wrappedValue: WearablesViewModel(wearables: wearables))
        _streamVM = StateObject(wrappedValue: StreamSessionViewModel(wearables: wearables))
    }

    var body: some View {
        Group {
            switch appMode {
            case .roleSelection:
                RoleSelectionView(
                    onLearn: { appMode = .learner },
                    onExpert: { appMode = .expertRecord }
                )

            case .learner:
                if wearablesVM.registrationState == .registered, selectedLesson != nil {
                    StreamView(streamVM: streamVM, wearablesVM: wearablesVM) {
                        selectedLesson = nil
                    }
                } else {
                    HomeScreenView(
                        viewModel: wearablesVM,
                        onBack: { appMode = .roleSelection },
                        onSelectLesson: { lesson in
                            streamVM.setLesson(lesson)
                            selectedLesson = lesson
                        }
                    )
                }

            case .expertRecord:
                ExpertRecordView(
                    onStepsGenerated: { steps, title in
                        appMode = .expertReview(steps: steps, title: title)
                    },
                    onCancel: { appMode = .roleSelection }
                )

            case .expertReview(let steps, let title):
                StepReviewView(
                    title: title,
                    suggestedSteps: steps,
                    onSave: { _ in
                        appMode = .roleSelection
                    },
                    onCancel: { appMode = .expertRecord }
                )
            }
        }
        .onChange(of: streamVM.currentLesson == nil) { lessonCleared in
            if lessonCleared { selectedLesson = nil }
        }
        .onOpenURL { url in
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
            else { return }
            Task { _ = try? await Wearables.shared.handleUrl(url) }
        }
    }
}

// MARK: - Role Selection

struct RoleSelectionView: View {
    var onLearn: () -> Void
    var onExpert: () -> Void

    var body: some View {
        ZStack {
            Color.shadowCream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + wordmark
                VStack(spacing: 12) {
                    Image(systemName: "eyeglasses")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56)
                        .foregroundColor(.shadowOrange)

                    Text("Shadow")
                        .font(.system(size: 46, weight: .light, design: .serif))
                        .foregroundColor(.shadowPrimary)

                    Text("Learn hands-on skills through the lens of\nAI-guided AR coaching.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.shadowSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Role cards
                VStack(spacing: 14) {
                    roleCard(
                        icon: "graduationcap",
                        title: "I want to learn",
                        subtitle: "Follow guided lessons with real-time coaching",
                        action: onLearn
                    )

                    roleCard(
                        icon: "video.badge.waveform",
                        title: "I'm an expert",
                        subtitle: "Record a task and create a new lesson",
                        action: onExpert
                    )
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 56)
            }
        }
    }

    private func roleCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.shadowOrange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.shadowOrange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.shadowPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.shadowSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.shadowSecondary)
            }
            .padding(18)
            .background(Color.shadowCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }
}
