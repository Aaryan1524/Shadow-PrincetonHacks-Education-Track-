import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    Color.white.ignoresSafeArea()

                    VStack {
                        Text("Shadow")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                        Spacer()
                    }
                    .padding(.top, 64)

                    GlassesFrameView(width: w * 0.80)
                        .position(x: w / 2, y: h * 0.44)
                        .rotation3DEffect(.degrees(-14), axis: (x: 1, y: 0, z: 0))
                        .rotation3DEffect(.degrees(32), axis: (x: 0, y: 1, z: 0))
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 8, y: 12)

                    VStack {
                        Spacer()
                        HStack(spacing: 24) {
                            NavigationLink(destination: UserView()) {
                                Text("User")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 120, height: 50)
                                    .background(Color.black)
                                    .cornerRadius(14)
                            }
                            NavigationLink(destination: ExpertView()) {
                                Text("Expert")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 120, height: 50)
                                    .background(Color.black)
                                    .cornerRadius(14)
                            }
                        }
                        .padding(.bottom, 60)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct GlassesFrameView: View {
    let width: CGFloat

    var body: some View {
        let lensW = width * 0.38
        let lensH = lensW * 0.68
        let gap: CGFloat = 20
        let outerRadius: CGFloat = 42
        let frameThickness: CGFloat = 16
        let innerRadius: CGFloat = max(outerRadius - frameThickness, 8)
        let armLen = lensW * 1.0         // full temple arm length
        let canvasW = lensW * 2 + gap + armLen * 2  // extra space for arms on both sides
        let offsetX = armLen             // shift lenses right to make room for left arm

        let leftOuter  = CGRect(x: offsetX, y: 0, width: lensW, height: lensH)
        let rightOuter = CGRect(x: offsetX + lensW + gap, y: 0, width: lensW, height: lensH)
        let leftInner  = leftOuter.insetBy(dx: frameThickness, dy: frameThickness)
        let rightInner = rightOuter.insetBy(dx: frameThickness, dy: frameThickness)
        let framesRight = offsetX + lensW * 2 + gap  // right edge of right lens

        Canvas { ctx, _ in
            // Lens tint
            ctx.fill(Path(roundedRect: leftInner,  cornerRadius: innerRadius), with: .color(Color(white: 0.82).opacity(0.5)))
            ctx.fill(Path(roundedRect: rightInner, cornerRadius: innerRadius), with: .color(Color(white: 0.82).opacity(0.5)))

            // Lens glare
            ctx.fill(Path(roundedRect: CGRect(x: leftInner.minX + 6, y: leftInner.minY + 4,
                                              width: leftInner.width * 0.45, height: leftInner.height * 0.28),
                          cornerRadius: innerRadius * 0.5), with: .color(.white.opacity(0.3)))
            ctx.fill(Path(roundedRect: CGRect(x: rightInner.minX + 6, y: rightInner.minY + 4,
                                              width: rightInner.width * 0.45, height: rightInner.height * 0.28),
                          cornerRadius: innerRadius * 0.5), with: .color(.white.opacity(0.3)))

            // Frames (outer minus inner)
            var leftFrame = Path(roundedRect: leftOuter, cornerRadius: outerRadius)
            leftFrame.addPath(Path(roundedRect: leftInner, cornerRadius: innerRadius))
            ctx.fill(leftFrame, with: .color(.black), style: FillStyle(eoFill: true))

            var rightFrame = Path(roundedRect: rightOuter, cornerRadius: outerRadius)
            rightFrame.addPath(Path(roundedRect: rightInner, cornerRadius: innerRadius))
            ctx.fill(rightFrame, with: .color(.black), style: FillStyle(eoFill: true))

            // Bridge
            var bridge = Path()
            bridge.move(to: CGPoint(x: leftOuter.maxX, y: lensH * 0.22))
            bridge.addQuadCurve(to: CGPoint(x: rightOuter.minX, y: lensH * 0.22),
                                control: CGPoint(x: offsetX + lensW + gap / 2, y: lensH * 0.08))
            ctx.stroke(bridge, with: .color(.black), style: StrokeStyle(lineWidth: 11, lineCap: .round))

            // Left temple arm — goes straight back horizontally
            var leftArm = Path()
            leftArm.move(to: CGPoint(x: leftOuter.minX + 4, y: lensH * 0.22))
            leftArm.addLine(to: CGPoint(x: 0, y: lensH * 0.22))
            ctx.stroke(leftArm, with: .color(.black), style: StrokeStyle(lineWidth: 11, lineCap: .round))

            // Right temple arm — goes straight back horizontally
            var rightArm = Path()
            rightArm.move(to: CGPoint(x: framesRight - 4, y: lensH * 0.22))
            rightArm.addLine(to: CGPoint(x: canvasW, y: lensH * 0.22))
            ctx.stroke(rightArm, with: .color(.black), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        }
        .frame(width: canvasW, height: lensH)
    }
}

#Preview {
    ContentView()
}
