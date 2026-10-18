import SwiftUI

/// Compact, static pond motif. The small watch canvas keeps data and controls steady.
struct WatchWaterLiliesBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color("LilyWater").opacity(0.42), Color("LilyWater").opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96)

            Canvas { context, size in
                let clusters: [(CGFloat, CGFloat)] = [(0.20, 0.32), (0.76, 0.18), (0.53, 0.73)]
                for (index, cluster) in clusters.enumerated() {
                    let center = CGPoint(x: size.width * cluster.0, y: size.height * cluster.1)
                    for stroke in 0..<5 {
                        let shift = CGFloat(stroke - 2)
                        var leaf = Path()
                        leaf.move(to: CGPoint(x: center.x - 15, y: center.y + shift * 2.6))
                        leaf.addQuadCurve(
                            to: CGPoint(x: center.x + 13, y: center.y + shift * 2.4),
                            control: CGPoint(x: center.x + 2, y: center.y + shift * 1.5 - 3)
                        )
                        context.stroke(
                            leaf,
                            with: .color(Color("LilyLeaf").opacity(index == 1 ? 0.38 : 0.27)),
                            style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                        )
                    }
                    var flower = Path()
                    flower.move(to: CGPoint(x: center.x + 3, y: center.y - 7))
                    flower.addLine(to: CGPoint(x: center.x + 1, y: center.y - 13))
                    flower.move(to: CGPoint(x: center.x + 4, y: center.y - 7))
                    flower.addLine(to: CGPoint(x: center.x + 8, y: center.y - 11))
                    context.stroke(
                        flower,
                        with: .color(Color("LilyFlower").opacity(0.55)),
                        style: StrokeStyle(lineWidth: 2.3, lineCap: .round)
                    )
                }
            }
            .frame(height: 80)
            .mask {
                LinearGradient(colors: [.white, .white.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
