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
                // Warm cream base
                Color(red: 0.97, green: 0.94, blue: 0.89)
                    .ignoresSafeArea()

                // Soft light halo — spotlight from above tracking glasses
                RadialGradient(
                    colors: [Color.white.opacity(0.60), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.28),
                    startRadius: 10,
                    endRadius: w * 0.65
                )
                .ignoresSafeArea()

                // Deep walnut surface — bottom half
                VStack(spacing: 0) {
                    Color.clear.frame(height: h * 0.52)
                    Color(red: 0.16, green: 0.10, blue: 0.06)
                        .frame(maxHeight: .infinity)
                }
                .ignoresSafeArea(edges: .bottom)

                // Ambient glow bleeding over the surface rim
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.97, green: 0.94, blue: 0.89).opacity(0.18), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.55
                        )
                    )
                    .frame(width: w * 1.1, height: 80)
                    .blur(radius: 18)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.52)

                // Slogan only — title lives in the outer ZStack overlay
                Text("Learn through expert eyes.")
                    .font(.custom("CopernicusTrial-Book", size: 16))
                    .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.10))
                    .tracking(1.2)
                    .position(x: w / 2, y: h * 0.19)

                // Shadow — outer wide soft glow
                Ellipse()
                    .fill(Color.black.opacity(0.30))
                    .frame(width: w * 0.82, height: 68)
                    .blur(radius: 38)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.525)
                    .offset(y: floatOffset * 0.15)

                // Shadow — inner tight contact shadow
                Ellipse()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: w * 0.46, height: 16)
                    .blur(radius: 10)
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
