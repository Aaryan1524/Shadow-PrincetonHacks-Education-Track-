import SwiftUI

struct LandingView: View {
    @State private var showMain = false
    @State private var glassesRotation: Double = 0

    var body: some View {
        ZStack {
            if showMain {
                ContentView(isPresented: $showMain)
                    .transition(.opacity)
            } else {
                landing
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showMain)
    }

    private var landing: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Color.white.ignoresSafeArea()

                GlassesFrameView(width: w * 0.82)
                    .rotation3DEffect(.degrees(glassesRotation), axis: (x: 0, y: 1, z: 0))
                    .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
                    .position(x: w / 2, y: h * 0.42)
                    .onAppear {
                        glassesRotation = 0
                        withAnimation(.easeInOut(duration: 0.8)) {
                            glassesRotation = 45
                        }
                    }

                Button {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showMain = true
                    }
                } label: {
                    Text("Get Started")
                        .font(.custom("FiraCode-SemiBold", size: 18))
                        .frame(width: 200, height: 54)
                }
                .buttonStyle(.glassProminent)
                .position(x: w / 2, y: h * 0.72)
            }
        }
    }
}

#Preview {
    LandingView()
}
