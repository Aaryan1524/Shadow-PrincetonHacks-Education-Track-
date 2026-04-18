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
            let leftLensX  = w * 0.30
            let rightLensX = w * 0.68
            let canvasW    = w * 0.88 * 0.38 * 4 + 20
            let lensShift  = canvasW * 0.04
            let zoomX: CGFloat = isZooming
                ? (zoomTarget == .user ? w / 2 + lensShift : w / 2 - lensShift)
                : w / 2
            let zoomY: CGFloat = isZooming ? h / 2 : lensY

            ZStack {
                // Beige background
                Color(red: 0.96, green: 0.93, blue: 0.86)
                    .ignoresSafeArea()

                // Brown lower half — surface the glasses hover above
                VStack(spacing: 0) {
                    Color.clear.frame(height: h * 0.52)
                    Color(red: 0.38, green: 0.24, blue: 0.14)
                }
                .ignoresSafeArea(edges: .bottom)

                // Shadow cast by glasses onto the brown surface
                Ellipse()
                    .fill(Color.black.opacity(0.30))
                    .frame(width: w * 0.68, height: 28)
                    .blur(radius: 22)
                    .position(x: w / 2, y: h * 0.524)

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

                    // Tap zones over lenses
                    Button {
                        triggerZoom(target: .user, w: w, h: h)
                    } label: { Color.clear.frame(width: w * 0.35, height: h * 0.14) }
                        .position(x: leftLensX, y: lensY)
                        .zIndex(0)

                    Button {
                        triggerZoom(target: .expert, w: w, h: h)
                    } label: { Color.clear.frame(width: w * 0.35, height: h * 0.14) }
                        .position(x: rightLensX, y: lensY)
                        .zIndex(0)

                    VStack {
                        Spacer()
                        HStack(spacing: 24) {
                            Button { triggerZoom(target: .user, w: w, h: h) } label: {
                                Text("User")
                                    .font(.custom("CopernicusTrial-Book", size: 17))
                                    .frame(width: 120, height: 50)
                            }
                            .buttonStyle(.glass)
                            Button { triggerZoom(target: .expert, w: w, h: h) } label: {
                                Text("Expert")
                                    .font(.custom("CopernicusTrial-Book", size: 17))
                                    .frame(width: 120, height: 50)
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(.bottom, 60)
                    }
                    .zIndex(0)
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
        ZStack {
            GlassesLensesView(width: width, color: color)
            GlassesArmsView(width: width, color: color)
        }
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
        let armLen = lensW * 1.0
        let canvasW = lensW * 2 + gap + armLen * 2
        let offsetX = armLen

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

struct GlassesArmsView: View {
    let width: CGFloat
    var color: Color = .black
    var body: some View {
        ZStack {
            GlassesLeftArmView(width: width, color: color)
            GlassesRightArmView(width: width, color: color)
        }
    }
}

struct GlassesLeftArmView: View {
    let width: CGFloat
    var color: Color = .black

    var body: some View {
        let lensW = width * 0.38
        let lensH = lensW * 0.68
        let gap: CGFloat = 20
        let armLen = lensW * 1.0
        let canvasW = lensW * 2 + gap + armLen * 2
        let offsetX = armLen
        let leftOuter = CGRect(x: offsetX, y: 0, width: lensW, height: lensH)

        Canvas { ctx, _ in
            var leftArm = Path()
            leftArm.move(to: CGPoint(x: leftOuter.minX + 4, y: lensH * 0.5))
            leftArm.addLine(to: CGPoint(x: 0, y: lensH * 0.5))
            ctx.stroke(leftArm, with: .color(color), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        }
        .frame(width: canvasW, height: lensH)
    }
}

struct GlassesRightArmView: View {
    let width: CGFloat
    var color: Color = .black

    var body: some View {
        let lensW = width * 0.38
        let lensH = lensW * 0.68
        let gap: CGFloat = 20
        let armLen = lensW * 1.0
        let canvasW = lensW * 2 + gap + armLen * 2
        let offsetX = armLen
        let framesRight = offsetX + lensW * 2 + gap

        Canvas { ctx, _ in
            var rightArm = Path()
            rightArm.move(to: CGPoint(x: framesRight - 4, y: lensH * 0.5))
            rightArm.addLine(to: CGPoint(x: canvasW, y: lensH * 0.5))
            ctx.stroke(rightArm, with: .color(color), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        }
        .frame(width: canvasW, height: lensH)
    }
}

#Preview {
    ContentView(isPresented: .constant(true))
}
