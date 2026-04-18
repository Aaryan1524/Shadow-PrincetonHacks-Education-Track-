import MWDATCore
import SwiftUI

struct MainAppView: View {
    @StateObject private var wearablesVM: WearablesViewModel
    @StateObject private var streamVM: StreamSessionViewModel

    @State private var selectedLesson: APILesson?

    private let wearables: WearablesInterface

    init(wearables: WearablesInterface) {
        self.wearables = wearables
        _wearablesVM = StateObject(wrappedValue: WearablesViewModel(wearables: wearables))
        _streamVM = StateObject(wrappedValue: StreamSessionViewModel(wearables: wearables))
    }

    var body: some View {
        Group {
            if wearablesVM.registrationState == .registered, selectedLesson != nil {
                StreamView(streamVM: streamVM, wearablesVM: wearablesVM)
            } else {
                HomeScreenView(viewModel: wearablesVM) { lesson in
                    streamVM.setLesson(lesson)
                    selectedLesson = lesson
                }
            }
        }
        .onChange(of: streamVM.currentLesson == nil) { lessonCleared in
            // When returnToMainPage() clears the lesson, navigate back
            if lessonCleared {
                selectedLesson = nil
            }
        }
        .onOpenURL { url in
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
            else { return }
            Task {
                _ = try? await Wearables.shared.handleUrl(url)
            }
        }
    }
}
