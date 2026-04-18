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
    @State private var glowBeat: Double = 0.22
    @State private var blobBreath: CGFloat = 0.94
    var body: some View {
        ZStack {
            if showMain {
                ContentView(isPresented: $showMain)
                    .transition(.opacity)
            } else {
                landing
                    .transition(.opacity)
            }

            // Persistent title with glow
            GeometryReader { geo in
                let blue = Color(red: 0.43, green: 0.51, blue: 0.59)
                Text("Shadow")
                    .font(.custom("CopernicusTrial-Book", size: 42))
                    .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.29))
                    .shadow(color: blue.opacity(glowBeat * 0.8), radius: 18, x: 0, y: 2)
                    .shadow(color: blue.opacity(glowBeat * 0.4), radius: 36, x: 0, y: 4)
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
            let deepBlue = Color(red: 0.28, green: 0.36, blue: 0.48)
            let charcoal = Color(red: 0.29, green: 0.29, blue: 0.29)
            let gW = w * CGFloat(glassesWidthFraction)
            let gH = gW * 0.38 * 0.68
            let gX = w / 2 + w * CGFloat(glassesXOffset)
            let gY = h * CGFloat(glassesYFraction)

            ZStack {
                // Cream base
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 1.00, blue: 0.89), location: 0.0),
                        .init(color: Color(red: 0.92, green: 0.92, blue: 0.88), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Blob 1 — top right, breathing
                Circle()
                    .fill(blue.opacity(0.36))
                    .frame(width: w * 1.45 * blobBreath)
                    .blur(radius: 88)
                    .position(x: w * 0.96, y: h * 0.05)

                // Blob 2 — bottom left, counter-breathing
                Circle()
                    .fill(deepBlue.opacity(0.30))
                    .frame(width: w * 1.28 * (2.0 - blobBreath))
                    .blur(radius: 80)
                    .position(x: w * 0.04, y: h * 0.93)

                // Blob 3 — center left
                Circle()
                    .fill(blue.opacity(0.22))
                    .frame(width: w * 0.82 * blobBreath)
                    .blur(radius: 62)
                    .position(x: w * 0.06, y: h * 0.46)

                // Blob 4 — top center accent
                Circle()
                    .fill(blue.opacity(0.14))
                    .frame(width: w * 0.60)
                    .blur(radius: 50)
                    .position(x: w * 0.52, y: h * 0.0)

                // Particle field
                Canvas { ctx, size in
                    var seed: UInt64 = 91827
                    func rand() -> CGFloat {
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        return CGFloat(seed >> 33) / CGFloat(UInt32.max)
                    }
                    for _ in 0..<70 {
                        let x = rand() * size.width
                        let y = rand() * size.height
                        let r = 1.0 + rand() * 3.2
                        let op = 0.12 + rand() * 0.32
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(blue.opacity(op))
                        )
                    }
                }
                .ignoresSafeArea()

                // Triple glow — outer (widest, softest)
                RoundedRectangle(cornerRadius: 56)
                    .fill(blue.opacity(glowBeat * 0.48))
                    .frame(width: gW + 130, height: gH + 96)
                    .blur(radius: 65)
                    .position(x: gX, y: gY)
                    .offset(y: floatOffset)
                    .allowsHitTesting(false)

                // Triple glow — mid
                RoundedRectangle(cornerRadius: 52)
                    .fill(blue.opacity(glowBeat * 0.82))
                    .frame(width: gW + 72, height: gH + 54)
                    .blur(radius: 36)
                    .position(x: gX, y: gY)
                    .offset(y: floatOffset)
                    .allowsHitTesting(false)

                // Triple glow — inner (tightest, brightest)
                RoundedRectangle(cornerRadius: 47)
                    .fill(blue.opacity(glowBeat * 1.45))
                    .frame(width: gW + 32, height: gH + 24)
                    .blur(radius: 18)
                    .position(x: gX, y: gY)
                    .offset(y: floatOffset)
                    .allowsHitTesting(false)

                // Drop shadow
                Ellipse()
                    .fill(blue.opacity(0.32))
                    .frame(width: gW * 0.92, height: 50)
                    .blur(radius: 30)
                    .position(x: gX, y: gY + gH / 2 + 22)
                    .offset(y: floatOffset * 0.15)

                // Slogan
                Text("See the world through expert eyes.")
                    .font(.custom("CopernicusTrial-Book", size: 15))
                    .foregroundStyle(blue.opacity(0.90))
                    .tracking(1.4)
                    .shadow(color: blue.opacity(0.55), radius: 10, x: 0, y: 2)
                    .position(x: w / 2, y: h * 0.20)

                // Glasses — double shadow for depth
                ZStack {
                    GlassesLensesView(width: gW, color: blue)
                }
                .rotation3DEffect(.degrees(glassesY3D), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .shadow(color: blue.opacity(0.70), radius: 40, x: 0, y: 16)
                .shadow(color: deepBlue.opacity(0.40), radius: 70, x: 0, y: 24)
                .offset(y: floatOffset)
                .position(x: gX, y: gY)

                // Button panel
                if !isTransitioning {
                    VStack(spacing: 10) {
                        Button {
                            startTransition(w: w, h: h)
                        } label: {
                            HStack(spacing: 10) {
                                Text("Get Started")
                                    .font(.custom("CopernicusTrial-Book", size: 18))
                                    .foregroundStyle(.white)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.88))
                            }
                            .padding(.horizontal, 52)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(colors: [blue, deepBlue],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: blue.opacity(0.72), radius: 28, x: 0, y: 12)
                            .shadow(color: deepBlue.opacity(0.35), radius: 50, x: 0, y: 20)
                            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(glowBeat > 0.38 ? 1.018 : 1.0)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glowBeat)

                        Text("student or expert — your choice")
                            .font(.custom("CopernicusTrial-Book", size: 12))
                            .foregroundStyle(charcoal.opacity(0.38))
                            .tracking(0.8)
                    }
                    .position(x: w / 2, y: h * 0.76)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isTransitioning)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    floatOffset = -10
                }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glowBeat = 0.56
                }
                withAnimation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true)) {
                    blobBreath = 1.10
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
