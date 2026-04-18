import SwiftUI

struct ExpertView: View {
    var body: some View {
        NavigationStack {
            Text("Expert")
                .font(.custom("FiraCode-Regular", size: 17))
                .navigationTitle("Expert")
        }
    }
}

#Preview {
    ExpertView()
}
