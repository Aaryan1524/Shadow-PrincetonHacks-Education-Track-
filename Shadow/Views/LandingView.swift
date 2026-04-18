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
                    .font(.custom("CopernicusTrial-Book", size: 42))
                    .foregroundStyle(.black)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.10)
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
            let blue     = Color(red: 0.43, green: 0.51, blue: 0.59)
            let charcoal = Color(red: 0.29, green: 0.29, blue: 0.29)
            let gW = w * glassesWidthFraction
            let gH = gW * 0.38 * 0.68

            ZStack {
                // Paper base
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 1.00, blue: 0.89), location: 0.0),
                        .init(color: Color(red: 0.93, green: 0.93, blue: 0.90), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Ink wash blob — top right
                Circle()
                    .fill(blue.opacity(0.22))
                    .frame(width: w * 1.25)
                    .blur(radius: 90)
                    .position(x: w * 0.88, y: h * 0.07)

                // Ink wash blob — bottom left
                Circle()
                    .fill(blue.opacity(0.18))
                    .frame(width: w * 1.05)
                    .blur(radius: 78)
                    .position(x: w * 0.10, y: h * 0.88)

                // Ink wash blob — center left accent
                Circle()
                    .fill(blue.opacity(0.10))
                    .frame(width: w * 0.72)
                    .blur(radius: 56)
                    .position(x: w * 0.05, y: h * 0.46)

                // Blue glow halo around glasses
                RoundedRectangle(cornerRadius: 46)
                    .fill(blue.opacity(0.24))
                    .frame(width: gW + 52, height: gH + 52)
                    .blur(radius: 32)
                    .position(x: w / 2 + w * glassesXOffset, y: h * glassesYFraction)
                    .offset(y: floatOffset)
                    .allowsHitTesting(false)

                // Slogan
                Text("See the world through expert eyes.")
                    .font(.custom("CopernicusTrial-Book", size: 15))
                    .foregroundStyle(blue.opacity(0.80))
                    .tracking(1.2)
                    .position(x: w / 2, y: h * 0.20)

                // Drop shadow (blue-tinted)
                Ellipse()
                    .fill(blue.opacity(0.22))
                    .frame(width: w * 0.84, height: 52)
                    .blur(radius: 28)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.530)
                    .offset(y: floatOffset * 0.15)

                Ellipse()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: w * 0.44, height: 14)
                    .blur(radius: 10)
                    .position(x: w / 2 + w * glassesXOffset, y: h * 0.526)
                    .offset(y: floatOffset * 0.15)

                // Glasses
                ZStack {
                    GlassesLensesView(width: w * glassesWidthFraction, color: blue)
                }
                .rotation3DEffect(.degrees(glassesY3D), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .shadow(color: blue.opacity(0.35), radius: 28, x: 0, y: 12)
                .offset(y: floatOffset)
                .position(x: w / 2 + w * glassesXOffset, y: h * glassesYFraction)

                // Bottom panel
                if !isTransitioning {
                    VStack(spacing: 12) {
                        Button {
                            startTransition(w: w, h: h)
                        } label: {
                            HStack(spacing: 10) {
                                Text("Get Started")
                                    .font(.custom("CopernicusTrial-Book", size: 18))
                                    .foregroundStyle(.white)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 18)
                            .background(blue)
                            .clipShape(Capsule())
                            .shadow(color: blue.opacity(0.45), radius: 18, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)

                        Text("student or expert — your choice")
                            .font(.custom("CopernicusTrial-Book", size: 12))
                            .foregroundStyle(charcoal.opacity(0.40))
                            .tracking(0.8)
                    }
                    .position(x: w / 2, y: h * 0.74)
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
