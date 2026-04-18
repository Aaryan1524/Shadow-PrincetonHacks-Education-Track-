import SwiftUI

struct LandingView: View {
    @State private var showMain = false
    @State private var isTransitioning = false

    // Landing state → ContentView state
    @State private var glassesY3D: Double = 50
    @State private var leftArmScaleX: Double = 1.7
    @State private var leftArmScaleY: Double = 0.8
    @State private var leftArmRotation: Double = 180
    @State private var rightArmScaleX: Double = 1.8
    @State private var rightArmScaleY: Double = 0.8
    @State private var rightArmRotation: Double = 30
    @State private var glassesXOffset: Double = -0.06
    @State private var glassesYFraction: Double = 0.42
    @State private var glassesWidthFraction: Double = 0.90
    @State private var floatOffset: CGFloat = 0
    @State private var animateGlow = false

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
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        .init(0, 0), .init(0.5, 0), .init(1, 0),
                        .init(0, 0.4), .init(0.5, 0.38), .init(1, 0.4),
                        .init(0, 1), .init(0.5, 1), .init(1, 1)
                    ],
                    colors: [
                        Color.white,
                        Color(red: 0.92, green: 0.96, blue: 1.0),
                        Color.white,
                        Color(red: 0.80, green: 0.91, blue: 1.0),
                        animateGlow ? Color(red: 0.38, green: 0.68, blue: 0.98) : Color(red: 0.52, green: 0.78, blue: 1.0),
                        Color(red: 0.80, green: 0.91, blue: 1.0),
                        Color(red: 0.90, green: 0.95, blue: 1.0),
                        Color(red: 0.68, green: 0.85, blue: 1.0),
                        Color(red: 0.90, green: 0.95, blue: 1.0)
                    ]
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                        animateGlow = true
                    }
                }

                // Slogan only — title lives in the outer ZStack overlay
                Text("Learn through expert eyes.")
                    .font(.custom("CopernicusTrial-Book", size: 16))
                    .foregroundStyle(Color(red: 0.25, green: 0.35, blue: 0.55))
                    .tracking(1.2)
                    .position(x: w / 2, y: h * 0.19)

                // Cast shadow below glasses
                Ellipse()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: w * 0.65, height: 44)
                    .blur(radius: 26)
                    .position(x: w / 2 + w * glassesXOffset, y: h * glassesYFraction + 70)
                    .offset(y: floatOffset * 0.3)

                ZStack {
                    GlassesLensesView(width: w * glassesWidthFraction)
                    GlassesLeftArmView(width: w * glassesWidthFraction)
                        .scaleEffect(x: leftArmScaleX, y: leftArmScaleY, anchor: UnitPoint(x: 0.26, y: 0.5))
                        .rotation3DEffect(.degrees(leftArmRotation), axis: (x: 0, y: 1, z: 0), anchor: UnitPoint(x: 0.25, y: 0.5), perspective: 0.5)
                    GlassesRightArmView(width: w * glassesWidthFraction)
                        .scaleEffect(x: rightArmScaleX, y: rightArmScaleY, anchor: UnitPoint(x: 0.75, y: 0.6))
                        .rotation3DEffect(.degrees(rightArmRotation), axis: (x: 0, y: 1, z: 0), anchor: UnitPoint(x: 0.75, y: 0.5), perspective: 0.5)
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
            leftArmScaleX = 1.8
            leftArmScaleY = 0.8
            leftArmRotation = 120
            rightArmScaleX = 1.8
            rightArmScaleY = 0.8
            rightArmRotation = 30
            glassesXOffset = -0.06
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
            leftArmScaleX = 1.0
            leftArmScaleY = 1.0
            leftArmRotation = 0
            rightArmScaleX = 1.0
            rightArmScaleY = 1.0
            rightArmRotation = 0
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
