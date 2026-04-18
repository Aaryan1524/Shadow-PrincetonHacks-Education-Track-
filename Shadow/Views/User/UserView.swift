import SwiftUI

struct UserView: View {
    var body: some View {
        NavigationStack {
            Text("User")
                .navigationTitle("User")
        }
    }
}

#Preview {
    UserView()
}
