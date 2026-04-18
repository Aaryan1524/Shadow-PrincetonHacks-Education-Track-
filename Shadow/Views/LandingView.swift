import SwiftUI

struct LandingView: View {
    @State private var showMain = false
    @State private var isTransitioning = false

    // Landing state → ContentView state
    @State private var glassesY3D: Double = 50
    @State private var glassesXOffset: Double = 0
    @State private var glassesYFraction: Double = 0.42
    @State private var glassesWidthFraction: Double = 0.90
    @State private var floatOffset: CGFloat = 0
    var body: some View {
        ZStack {
            if showMain {
                ContentView(isPresented: $showMain)
                    .transition(.opacity)
            } else {
                landing
                    .transition(.opacity)
            }

            // Persistent title — sits outside the transition so it never moves
            GeometryReader { geo in
                Text("Shadow")
                    .font(.custom("CopernicusTrial-Book", size: 52))
                    .foregroundStyle(.black)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.14)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.2), value: showMain)
        .onChange(of: showMain) { _, newValue in
            if !newValue {
                reverseTransition()
            }
        }
    }

    private var landing: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Sky — light blue at top fading to warm horizon
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.53, green: 0.81, blue: 0.98), location: 0.0),
                        .init(color: Color(red: 0.78, green: 0.91, blue: 1.00), location: 0.38),
                        .init(color: Color(red: 0.95, green: 0.88, blue: 0.74), location: 0.52)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Grass — rich green bottom half
                VStack(spacing: 0) {
                    Color.clear.frame(height: h * 0.52)
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.35, green: 0.62, blue: 0.22), location: 0.0),
                            .init(color: Color(red: 0.20, green: 0.42, blue: 0.12), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(maxHeight: .infinity)
                }
                .ignoresSafeArea(edges: .bottom)

                // Grass blade texture
                GrassTextureView()
                    .frame(width: w, height: h * 0.50)
                    .position(x: w / 2, y: h * 0.77)
                    .allowsHitTesting(false)

                // Soft horizon glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 1.0, green: 0.95, blue: 0.80).opacity(0.45), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.6
                        )
                    )
                    .frame(width: w * 1.2, height: 90)
                    .blur(radius: 20)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.52)

                // Slogan only — title lives in the outer ZStack overlay
                Text("Learn through expert eyes.")
                    .font(.custom("CopernicusTrial-Book", size: 16))
                    .foregroundStyle(Color(red: 0.10, green: 0.24, blue: 0.08))
                    .tracking(1.2)
                    .position(x: w / 2, y: h * 0.19)

                // Shadow — outer green-tinted glow on grass
                Ellipse()
                    .fill(Color(red: 0.08, green: 0.22, blue: 0.04).opacity(0.52))
                    .frame(width: w * 0.82, height: 58)
                    .blur(radius: 34)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.528)
                    .offset(y: floatOffset * 0.15)

                // Shadow — tight contact shadow
                Ellipse()
                    .fill(Color.black.opacity(0.42))
                    .frame(width: w * 0.44, height: 13)
                    .blur(radius: 9)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.524)
                    .offset(y: floatOffset * 0.15)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.522)
                    .offset(y: floatOffset * 0.15)

                ZStack {
                    GlassesLensesView(width: w * glassesWidthFraction)
                }
                .rotation3DEffect(.degrees(glassesY3D), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 10)
                .offset(y: floatOffset)
                .position(x: w / 2 + w * glassesXOffset, y: h * glassesYFraction)

                if !isTransitioning {
                    Button {
                        startTransition(w: w, h: h)
                    } label: {
                        Text("Get Started")
                            .font(.custom("CopernicusTrial-Book", size: 18))
                            .padding(.horizontal, 36)
                            .padding(.vertical, 18)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .position(x: w / 2, y: h * 0.72)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isTransitioning)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    floatOffset = -10
                }
            }
        }
    }

    private func reverseTransition() {
        withAnimation(.easeInOut(duration: 0.55)) {
            glassesY3D = 50
            glassesXOffset = 0
            glassesYFraction = 0.42
            glassesWidthFraction = 0.90
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isTransitioning = false
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatOffset = -10
            }
        }
    }

    private func startTransition(w: CGFloat, h: CGFloat) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTransitioning = true
            floatOffset = 0
        }
        withAnimation(.easeInOut(duration: 0.55)) {
            glassesY3D = 0
            glassesXOffset = 0
            glassesYFraction = 0.40
            glassesWidthFraction = 0.88
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showMain = true
            }
        }
    }
}

#Preview {
    LandingView()
}
