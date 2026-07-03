import SwiftUI

/// The Nodi brand mark: three nodes connected by animated edges, echoing
/// the network-graph metaphor at the center of the product.
struct NodiLogoMark: View {
    var size: CGFloat = 48
    @State private var pulse = false

    private let points: [CGPoint] = [
        CGPoint(x: 0.5, y: 0.08),
        CGPoint(x: 0.1, y: 0.85),
        CGPoint(x: 0.9, y: 0.85)
    ]

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                let resolved = points.map {
                    CGPoint(x: $0.x * canvasSize.width, y: $0.y * canvasSize.height)
                }
                for i in 0..<resolved.count {
                    for j in (i + 1)..<resolved.count {
                        var path = Path()
                        path.move(to: resolved[i])
                        path.addLine(to: resolved[j])
                        context.stroke(path, with: .color(NodiColor.accent.opacity(0.6)), lineWidth: 1.5)
                    }
                }
                for point in resolved {
                    let radius: CGFloat = size * 0.09
                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(NodiColor.accent))
                }
            }
            .frame(width: size, height: size)
        }
        .scaleEffect(pulse ? 1.04 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    NodiLogoMark(size: 96)
        .padding()
        .background(NodiColor.background)
}
