import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let lensW = w * 0.42
                let lensH = h * 0.36
                let lensY = h * 0.42
                let leftX = w * 0.25
                let rightX = w * 0.75

                ZStack {
                    // Background
                    Color.black.ignoresSafeArea()

                    // Scene visible through lenses
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .cyan.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .mask(
                        ZStack {
                            Ellipse()
                                .frame(width: lensW, height: lensH)
                                .position(x: leftX, y: lensY)
                            Ellipse()
                                .frame(width: lensW, height: lensH)
                                .position(x: rightX, y: lensY)
                        }
                    )

                    // Glasses frame
                    Canvas { ctx, size in
                        // Left lens frame
                        let leftLens = CGRect(
                            x: leftX - lensW / 2, y: lensY - lensH / 2,
                            width: lensW, height: lensH
                        )
                        // Right lens frame
                        let rightLens = CGRect(
                            x: rightX - lensW / 2, y: lensY - lensH / 2,
                            width: lensW, height: lensH
                        )
                        var leftPath = Path(ellipseIn: leftLens)
                        var rightPath = Path(ellipseIn: rightLens)

                        ctx.stroke(leftPath, with: .color(.white.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 6))
                        ctx.stroke(rightPath, with: .color(.white.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 6))

                        // Bridge
                        var bridge = Path()
                        bridge.move(to: CGPoint(x: leftX + lensW / 2, y: lensY - 4))
                        bridge.addQuadCurve(
                            to: CGPoint(x: rightX - lensW / 2, y: lensY - 4),
                            control: CGPoint(x: w / 2, y: lensY - 24)
                        )
                        ctx.stroke(bridge, with: .color(.white.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 5))

                        // Left temple arm
                        var leftArm = Path()
                        leftArm.move(to: CGPoint(x: leftX - lensW / 2, y: lensY))
                        leftArm.addLine(to: CGPoint(x: 0, y: lensY - 10))
                        ctx.stroke(leftArm, with: .color(.white.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 5))

                        // Right temple arm
                        var rightArm = Path()
                        rightArm.move(to: CGPoint(x: rightX + lensW / 2, y: lensY))
                        rightArm.addLine(to: CGPoint(x: w, y: lensY - 10))
                        ctx.stroke(rightArm, with: .color(.white.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 5))
                    }

                    // Title
                    VStack {
                        Text("Shadow")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, 60)

                    // User button — left lens
                    NavigationLink(destination: UserView()) {
                        Text("User")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .position(x: leftX, y: lensY)

                    // Expert button — right lens
                    NavigationLink(destination: ExpertView()) {
                        Text("Expert")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .position(x: rightX, y: lensY)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ContentView()
}
