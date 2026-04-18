import SwiftUI

enum LensTarget { case user, expert }

struct ContentView: View {
    @Binding var isPresented: Bool
    @State private var zoomTarget: LensTarget? = nil
    @State private var isZooming = false
    @State private var showDestination = false
    @State private var isDeepZoom = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lensY      = h * 0.40
            let lensW      = w * 0.88 * 0.38
            let gap: CGFloat = 20
            let leftLensX  = w / 2 - lensW / 2 - gap / 2
            let rightLensX = w / 2 + lensW / 2 + gap / 2
            let canvasW    = lensW * 2 + gap
            let lensShift  = canvasW * 0.04
            let zoomX: CGFloat = isZooming
                ? (zoomTarget == .user ? w / 2 + lensShift : w / 2 - lensShift)
                : w / 2
            let zoomY: CGFloat = isZooming ? h / 2 : lensY

            ZStack {
                // Sky — light blue at top fading to warm horizon
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.53, green: 0.81, blue: 0.98), location: 0.0),
                        .init(color: Color(red: 0.78, green: 0.91, blue: 1.00), location: 0.38),
                        .init(color: Color(red: 0.95, green: 0.88, blue: 0.74), location: 0.48)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Grass — rich green bottom half
                VStack(spacing: 0) {
                    Color.clear.frame(height: h * 0.50)
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
                    .frame(width: w, height: h * 0.52)
                    .position(x: w / 2, y: h * 0.76)
                    .allowsHitTesting(false)

                // Soft horizon glow where sky meets grass
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
                    .position(x: w / 2, y: h * 0.50)

                // Shadow — wide, diffuse; glasses are floating ~10% screen above the grass
                // so no tight contact shadow, just a broad soft pool
                Ellipse()
                    .fill(Color(red: 0.04, green: 0.14, blue: 0.02).opacity(0.50))
                    .frame(width: w * 1.05, height: 48)
                    .blur(radius: 32)
                    .position(x: w / 2, y: h * 0.52)

                Ellipse()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: w * 0.58, height: 20)
                    .blur(radius: 18)
                    .position(x: w / 2, y: h * 0.518)

                // Destination view — fades in after zoom
                if showDestination {
                    Group {
                        if zoomTarget == .user {
                            UserView()
                        } else {
                            ExpertView()
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                // Main content — hidden when destination is showing
                if !showDestination {

                    // Log out button — top right
                    Button {
                        withAnimation(.easeInOut(duration: 0.5)) { isPresented = false }
                    } label: {
                        Text("Log out")
                            .font(.custom("CopernicusTrial-Book", size: 15))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .position(x: w - 60, y: 110)
                    .zIndex(1)

                    // Left lens label — Student
                    Button {
                        triggerZoom(target: .user, w: w, h: h)
                    } label: {
                        Text("Student")
                            .font(.custom("CopernicusTrial-Book", size: 15))
                            .foregroundStyle(.black.opacity(0.80))
                            .frame(width: w * 0.30, height: h * 0.12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: leftLensX, y: lensY)
                    .zIndex(1)

                    // Right lens label — Expert
                    Button {
                        triggerZoom(target: .expert, w: w, h: h)
                    } label: {
                        Text("Expert")
                            .font(.custom("CopernicusTrial-Book", size: 15))
                            .foregroundStyle(.black.opacity(0.80))
                            .frame(width: w * 0.30, height: h * 0.12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: rightLensX, y: lensY)
                    .zIndex(1)

                    // Hint text — sits on the grass, white so it reads clearly
                    Text("tap a lens to begin")
                        .font(.custom("CopernicusTrial-Book", size: 13))
                        .foregroundStyle(.white.opacity(0.82))
                        .tracking(1.2)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)
                        .position(x: w / 2, y: h * 0.56)
                        .zIndex(1)
                }

                // Back button — always on top when destination is showing
                if showDestination && !isDeepZoom {
                    Button {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showDestination = false
                            isZooming = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { zoomTarget = nil }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(16)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .position(x: 44, y: 70)
                    .zIndex(3)

                    // View / Record button
                    Button {
                        withAnimation(.easeInOut(duration: 0.6)) { isDeepZoom = true }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 18, weight: .semibold))
                            Text("View / Record")
                                .font(.custom("CopernicusTrial-Book", size: 16))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.glass)
                    .position(x: w / 2, y: h * 0.5)
                    .zIndex(3)
                }

                // Deep zoom back button
                if isDeepZoom {
                    Button {
                        withAnimation(.easeInOut(duration: 0.5)) { isDeepZoom = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .position(x: 44, y: 70)
                    .zIndex(3)
                }

                // Glasses frame — always on top during zoom
                if zoomTarget != nil {
                    GlassesFrameView(width: w * 0.88)
                        .position(x: zoomX, y: zoomY)
                        .scaleEffect(
                            isDeepZoom ? 40.0 : (isZooming ? 10.0 : 1.0),
                            anchor: zoomTarget == .user
                                ? UnitPoint(x: 0.36, y: 0.5)
                                : UnitPoint(x: 0.64, y: 0.5)
                        )
                        .animation(.easeInOut(duration: 0.6), value: isDeepZoom)
                        .animation(.easeInOut(duration: 0.5), value: isZooming)
                        .zIndex(2)
                        .allowsHitTesting(false)
                }

                // Static glasses when not zooming
                if zoomTarget == nil {
                    GlassesFrameView(width: w * 0.88)
                        .position(x: w / 2, y: lensY)
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 12)
                        .zIndex(0)
                }
            }
        }
    }

    func triggerZoom(target: LensTarget, w: CGFloat, h: CGFloat) {
        zoomTarget = target
        withAnimation(.easeInOut(duration: 0.5)) { isZooming = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 0.2)) { showDestination = true }
        }
    }
}

struct GlassesFrameView: View {
    let width: CGFloat
    var color: Color = .black

    var body: some View {
        GlassesLensesView(width: width, color: color)
    }
}

struct GlassesLensesView: View {
    let width: CGFloat
    var color: Color = .black

    var body: some View {
        let lensW = width * 0.38
        let lensH = lensW * 0.68
        let gap: CGFloat = 20
        let outerRadius: CGFloat = 42
        let frameThickness: CGFloat = 16
        let innerRadius: CGFloat = max(outerRadius - frameThickness, 8)
        let canvasW = lensW * 2 + gap
        let offsetX: CGFloat = 0

        let leftOuter  = CGRect(x: offsetX, y: 0, width: lensW, height: lensH)
        let rightOuter = CGRect(x: offsetX + lensW + gap, y: 0, width: lensW, height: lensH)
        let leftInner  = leftOuter.insetBy(dx: frameThickness, dy: frameThickness)
        let rightInner = rightOuter.insetBy(dx: frameThickness, dy: frameThickness)

        Canvas { ctx, _ in
            ctx.fill(Path(roundedRect: leftInner,  cornerRadius: innerRadius), with: .color(Color(white: 0.82).opacity(0.5)))
            ctx.fill(Path(roundedRect: rightInner, cornerRadius: innerRadius), with: .color(Color(white: 0.82).opacity(0.5)))

            ctx.fill(Path(roundedRect: CGRect(x: leftInner.minX + 6, y: leftInner.minY + 4,
                                              width: leftInner.width * 0.45, height: leftInner.height * 0.28),
                          cornerRadius: innerRadius * 0.5), with: .color(.white.opacity(0.3)))
            ctx.fill(Path(roundedRect: CGRect(x: rightInner.minX + 6, y: rightInner.minY + 4,
                                              width: rightInner.width * 0.45, height: rightInner.height * 0.28),
                          cornerRadius: innerRadius * 0.5), with: .color(.white.opacity(0.3)))

            var leftFrame = Path(roundedRect: leftOuter, cornerRadius: outerRadius)
            leftFrame.addPath(Path(roundedRect: leftInner, cornerRadius: innerRadius))
            ctx.fill(leftFrame, with: .color(color), style: FillStyle(eoFill: true))

            var rightFrame = Path(roundedRect: rightOuter, cornerRadius: outerRadius)
            rightFrame.addPath(Path(roundedRect: rightInner, cornerRadius: innerRadius))
            ctx.fill(rightFrame, with: .color(color), style: FillStyle(eoFill: true))

            var bridge = Path()
            bridge.move(to: CGPoint(x: leftOuter.maxX, y: lensH * 0.22))
            bridge.addQuadCurve(to: CGPoint(x: rightOuter.minX, y: lensH * 0.22),
                                control: CGPoint(x: offsetX + lensW + gap / 2, y: lensH * 0.08))
            ctx.stroke(bridge, with: .color(color), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        }
        .frame(width: canvasW, height: lensH)
    }
}

#Preview {
    ContentView(isPresented: .constant(true))
}

struct GrassTextureView: View {
    var body: some View {
        Canvas { ctx, size in
            // Deterministic pseudo-random using a simple LCG so blades don't
            // jump every render, but vary visually across the surface.
            var seed: UInt64 = 42
            func rand() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max)
            }

            let cols = 55
            let spacing = size.width / CGFloat(cols)

            for i in 0..<cols * 6 {
                let col = i % cols
                let row = i / cols
                let baseX = CGFloat(col) * spacing + rand() * spacing
                let baseY = CGFloat(row) * (size.height / 6.0) + rand() * (size.height / 6.0)

                // Blade height: taller near the top (horizon), shorter deeper in
                let depthFraction = baseY / size.height
                let bladeH = 22 - depthFraction * 14 + rand() * 10
                let lean = (rand() - 0.5) * 14   // ±7 pt lean
                let shade = 0.52 + rand() * 0.22  // green channel variation
                let alpha = 0.55 + rand() * 0.35

                var blade = Path()
                blade.move(to: CGPoint(x: baseX, y: baseY))
                blade.addQuadCurve(
                    to: CGPoint(x: baseX + lean, y: baseY - bladeH),
                    control: CGPoint(x: baseX + lean * 0.4, y: baseY - bladeH * 0.5)
                )
                ctx.stroke(
                    blade,
                    with: .color(Color(red: 0.14 + rand() * 0.12, green: shade, blue: 0.10).opacity(alpha)),
                    style: StrokeStyle(lineWidth: 1.2 + rand() * 0.8, lineCap: .round)
                )
            }
        }
    }
}
