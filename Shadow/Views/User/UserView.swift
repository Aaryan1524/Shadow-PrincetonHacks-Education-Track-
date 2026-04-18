import SwiftUI

struct UserView: View {
    var body: some View {
        NavigationStack {
            Text("User")
                .font(.custom("FiraCode-Regular", size: 17))
                .navigationTitle("User")
        }
    }
}

#Preview {
    UserView()
}
