import SwiftUI

enum LensTarget { case user, expert }

struct ContentView: View {
    @Binding var isPresented: Bool
    @State private var zoomTarget: LensTarget? = nil
    @State private var isZooming = false
    @State private var showDestination = false
    @State private var isDeepZoom = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.55
    @State private var outerRingScale: CGFloat = 1.0
    @State private var outerRingOpacity: Double = 0.45

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
                // Cream base
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 1.00, blue: 0.89), location: 0.0),
                        .init(color: Color(red: 0.92, green: 0.92, blue: 0.88), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Ink wash blobs
                let blue     = Color(red: 0.43, green: 0.51, blue: 0.59)
                let deepBlue = Color(red: 0.28, green: 0.36, blue: 0.48)

                Circle()
                    .fill(blue.opacity(0.34))
                    .frame(width: w * 1.45)
                    .blur(radius: 88)
                    .position(x: w * 0.96, y: h * 0.05)

                Circle()
                    .fill(deepBlue.opacity(0.28))
                    .frame(width: w * 1.25)
                    .blur(radius: 80)
                    .position(x: w * 0.04, y: h * 0.93)

                Circle()
                    .fill(blue.opacity(0.18))
                    .frame(width: w * 0.82)
                    .blur(radius: 62)
                    .position(x: w * 0.06, y: h * 0.46)

                // Particle field
                Canvas { ctx, size in
                    var seed: UInt64 = 54321
                    func rand() -> CGFloat {
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        return CGFloat(seed >> 33) / CGFloat(UInt32.max)
                    }
                    for _ in 0..<55 {
                        let x = rand() * size.width
                        let y = rand() * size.height
                        let r = 1.0 + rand() * 2.8
                        let op = 0.10 + rand() * 0.28
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(blue.opacity(op))
                        )
                    }
                }
                .ignoresSafeArea()

                // Triple glow behind glasses
                let glassW = w * 0.88
                let glassH = glassW * 0.38 * 0.68

                RoundedRectangle(cornerRadius: 56)
                    .fill(blue.opacity(0.16))
                    .frame(width: glassW + 130, height: glassH + 96)
                    .blur(radius: 65)
                    .position(x: w / 2, y: lensY)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 52)
                    .fill(blue.opacity(0.24))
                    .frame(width: glassW + 70, height: glassH + 52)
                    .blur(radius: 36)
                    .position(x: w / 2, y: lensY)
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 47)
                    .fill(blue.opacity(0.36))
                    .frame(width: glassW + 30, height: glassH + 22)
                    .blur(radius: 18)
                    .position(x: w / 2, y: lensY)
                    .allowsHitTesting(false)

                // Drop shadow
                Ellipse()
                    .fill(blue.opacity(0.26))
                    .frame(width: w * 1.05, height: 50)
                    .blur(radius: 30)
                    .position(x: w / 2, y: h * 0.52)

                Ellipse()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: w * 0.58, height: 18)
                    .blur(radius: 14)
                    .position(x: w / 2, y: h * 0.518)

                // Destination view — fades in after zoom
                if showDestination {
                    ZStack(alignment: .topLeading) {
                        if zoomTarget == .user {
                            UserView()
                        } else {
                            ExpertView()
                        }

                        if !isDeepZoom {
                            Button {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showDestination = false
                                    isZooming = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { zoomTarget = nil }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                            .padding(.leading, 12)
                            .zIndex(999)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }

                // Main content — hidden when destination is showing
                if !showDestination {
                    let blue     = Color(red: 0.43, green: 0.51, blue: 0.59)
                    let deepBlue = Color(red: 0.28, green: 0.36, blue: 0.48)
                    let charcoal = Color(red: 0.29, green: 0.29, blue: 0.29)
                    let lensH    = lensW * 0.68
                    let cardY    = lensY + lensH / 2 + 52

                    // Log out button
                    Button {
                        withAnimation(.easeInOut(duration: 0.5)) { isPresented = false }
                    } label: {
                        Text("Log out")
                            .font(.custom("CopernicusTrial-Book", size: 14))
                            .foregroundStyle(charcoal.opacity(0.65))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.65))
                            .overlay(Capsule().stroke(blue.opacity(0.35), lineWidth: 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .position(x: w - 58, y: h * 0.10)
                    .zIndex(1)

                    // Outer ripple rings (wide, slow fade)
                    ForEach([leftLensX, rightLensX], id: \.self) { lx in
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(blue.opacity(outerRingOpacity), lineWidth: 3)
                            .frame(width: lensW * outerRingScale, height: lensH * outerRingScale)
                            .position(x: lx, y: lensY)
                            .blur(radius: 8)
                            .allowsHitTesting(false)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                            outerRingScale   = 1.24
                            outerRingOpacity = 0.0
                        }
                    }

                    // Inner pulse rings (tighter, faster)
                    let lensInnerW = lensW - 22
                    let lensInnerH = lensH - 22
                    ForEach([leftLensX, rightLensX], id: \.self) { lx in
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(blue.opacity(pulseOpacity), lineWidth: 5)
                            .frame(width: lensInnerW * pulseScale, height: lensInnerH * pulseScale)
                            .position(x: lx, y: lensY)
                            .blur(radius: 6)
                            .allowsHitTesting(false)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            pulseScale   = 1.12
                            pulseOpacity = 0.0
                        }
                    }

                    // Student card
                    Button {
                        triggerZoom(target: .user, w: w, h: h)
                    } label: {
                        VStack(spacing: 3) {
                            Text("Student")
                                .font(.custom("CopernicusTrial-Book", size: 16))
                                .foregroundStyle(blue)
                            Text("Learn from experts")
                                .font(.custom("CopernicusTrial-Book", size: 11))
                                .foregroundStyle(charcoal.opacity(0.50))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(colors: [blue.opacity(0.20), deepBlue.opacity(0.12)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(colors: [blue.opacity(0.65), blue.opacity(0.18)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.5
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: blue.opacity(0.38), radius: 14, x: 0, y: 6)
                        .shadow(color: deepBlue.opacity(0.20), radius: 26, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                    .position(x: leftLensX, y: cardY)
                    .zIndex(1)

                    // Expert card
                    Button {
                        triggerZoom(target: .expert, w: w, h: h)
                    } label: {
                        VStack(spacing: 3) {
                            Text("Expert")
                                .font(.custom("CopernicusTrial-Book", size: 16))
                                .foregroundStyle(blue)
                            Text("Share your craft")
                                .font(.custom("CopernicusTrial-Book", size: 11))
                                .foregroundStyle(charcoal.opacity(0.50))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(colors: [blue.opacity(0.20), deepBlue.opacity(0.12)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(colors: [blue.opacity(0.65), blue.opacity(0.18)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.5
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: blue.opacity(0.38), radius: 14, x: 0, y: 6)
                        .shadow(color: deepBlue.opacity(0.20), radius: 26, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                    .position(x: rightLensX, y: cardY)
                    .zIndex(1)

                    // Hint text
                    Text("tap a lens to begin")
                        .font(.custom("CopernicusTrial-Book", size: 12))
                        .foregroundStyle(blue.opacity(0.58))
                        .tracking(2.2)
                        .shadow(color: blue.opacity(0.45), radius: 8, x: 0, y: 1)
                        .scaleEffect(pulseScale > 1.05 ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulseScale)
                        .position(x: w / 2, y: cardY + 58)
                        .zIndex(1)
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
                    .buttonStyle(.plain)
                    .position(x: 44, y: h * 0.10)
                    .zIndex(3)
                }

                // Glasses frame — always on top during zoom
                if zoomTarget != nil {
                    GlassesFrameView(width: w * 0.88)
                        .position(x: zoomX, y: zoomY)
                        .scaleEffect(
                            isDeepZoom ? 40.0 : (isZooming ? 10.0 : 1.0),
                            anchor: zoomTarget == .user
                                ? UnitPoint(x: 0.25, y: 0.5)
                                : UnitPoint(x: 0.75, y: 0.5)
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
                        .shadow(color: Color(red: 0.43, green: 0.51, blue: 0.59).opacity(0.60), radius: 36, x: 0, y: 16)
                        .shadow(color: Color(red: 0.28, green: 0.36, blue: 0.48).opacity(0.35), radius: 64, x: 0, y: 24)
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
    var color: Color = Color(red: 0.43, green: 0.51, blue: 0.59)

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
            ctx.fill(Path(roundedRect: leftInner,  cornerRadius: innerRadius), with: .color(Color(white: 0.90).opacity(0.08)))
            ctx.fill(Path(roundedRect: rightInner, cornerRadius: innerRadius), with: .color(Color(white: 0.90).opacity(0.08)))

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
