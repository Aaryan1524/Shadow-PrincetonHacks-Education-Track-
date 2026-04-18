import SwiftUI

struct PhotoPreviewView: View {
    let photo: UIImage
    let onDismiss: () -> Void

    @State private var saved = false

    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()

                HStack(spacing: 20) {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil)
                        saved = true
                    } label: {
                        Label(saved ? "Saved" : "Save to Photos", systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(saved ? Color.green : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(saved)

                    Button {
                        onDismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Captured Photo")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
