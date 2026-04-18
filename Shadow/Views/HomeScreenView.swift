import MWDATCore
import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var viewModel: WearablesViewModel

    var body: some View {
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)

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
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage)
        }
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
