import SwiftUI
import UIKit

/// Renders `GraphViewModel`'s nodes/edges into a `Canvas`, driven by
/// `TimelineView(.animation)` so the force simulation advances every
/// frame. Calling `viewModel.tick()` from inside the timeline content
/// closure (rather than a separate `Timer`) is the standard SwiftUI
/// idiom for Canvas-driven physics — it's a deliberate, accepted "side
/// effect in the view body" here, not an oversight.
struct GraphCanvasView: View {
    @ObservedObject var viewModel: GraphViewModel
    @Binding var camera: GraphCamera
    let onTap: (GraphNode) -> Void

    @State private var avatarImages: [String: UIImage] = [:]
    @GestureState private var pinchDelta: CGFloat = 1
    @GestureState private var dragDelta: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { _ in
                Canvas { context, size in
                    viewModel.tick()
                    draw(in: &context, size: size)
                }
                .background(NodiColor.background)
            }
            .onAppear { viewModel.canvasSize = proxy.size }
            .onChange(of: proxy.size) { _, newSize in viewModel.canvasSize = newSize }
        }
        .contentShape(Rectangle())
        .gesture(magnifyGesture)
        .simultaneousGesture(dragGesture)
        .onTapGesture { location in
            handleTap(at: location)
        }
        .task(id: nodeIdentitySignature) {
            await loadMissingAvatars()
        }
    }

    private var nodeIdentitySignature: String {
        viewModel.nodes.map(\.id).joined(separator: ",")
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let effectiveCamera = GraphCamera(
            scale: camera.scale * pinchDelta,
            offset: CGSize(width: camera.offset.width + dragDelta.width, height: camera.offset.height + dragDelta.height)
        )
        let centerOffset = CGSize(
            width: size.width / 2 * (1 - effectiveCamera.scale),
            height: size.height / 2 * (1 - effectiveCamera.scale)
        )

        func screenPoint(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: p.x * effectiveCamera.scale + effectiveCamera.offset.width + centerOffset.width,
                y: p.y * effectiveCamera.scale + effectiveCamera.offset.height + centerOffset.height
            )
        }

        let hasActiveFilter = !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || !viewModel.activeFilters.isEmpty
        let nodePositions = Dictionary(uniqueKeysWithValues: viewModel.nodes.map { ($0.id, $0.position) })

        // Edges first, so nodes draw on top.
        for edge in viewModel.edges {
            guard let sourcePos = nodePositions[edge.sourceId], let targetPos = nodePositions[edge.targetId] else { continue }
            let dimmed = hasActiveFilter && !viewModel.edgeMatchesFilter(edge)

            var path = Path()
            path.move(to: screenPoint(sourcePos))
            path.addLine(to: screenPoint(targetPos))

            if edge.isMutualGlow && !dimmed {
                context.stroke(path, with: .color(NodiColor.edgeMutualGlow.opacity(0.35)), lineWidth: 5)
            }
            context.stroke(
                path,
                with: .color(edge.type.edgeColor.opacity(dimmed ? 0.08 : 0.7)),
                lineWidth: edge.isMutualGlow ? 2.2 : 1.2
            )
        }

        for node in viewModel.nodes {
            let dimmed = hasActiveFilter && !viewModel.matches(node)
            drawNode(node, at: screenPoint(node.position), scale: effectiveCamera.scale, dimmed: dimmed, context: &context)
        }
    }

    private func drawNode(_ node: GraphNode, at point: CGPoint, scale: CGFloat, dimmed: Bool, context: inout GraphicsContext) {
        let radius = node.baseRadius * scale
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        let opacity = dimmed ? 0.2 : 1.0

        if node.isCluster {
            context.opacity = opacity
            context.fill(Path(ellipseIn: rect), with: .color(NodiColor.secondaryBackground))
            context.stroke(Path(ellipseIn: rect), with: .color(NodiColor.divider), lineWidth: 1.5)
            if radius > 8 {
                context.draw(
                    Text("+\(clusterCount(node))").font(.system(size: max(9, radius * 0.5), weight: .semibold)).foregroundColor(NodiColor.secondaryText),
                    at: point
                )
            }
            context.opacity = 1
            return
        }

        context.opacity = opacity

        if let uiImage = avatarImages[node.id] {
            context.drawLayer { layerContext in
                layerContext.clip(to: Path(ellipseIn: rect))
                layerContext.draw(Image(uiImage: uiImage), in: rect)
            }
        } else {
            context.fill(Path(ellipseIn: rect), with: .color(node.depth == 0 ? NodiColor.accent : NodiColor.secondaryBackground))
        }

        context.stroke(Path(ellipseIn: rect), with: .color(node.depth == 0 ? NodiColor.accent : NodiColor.divider), lineWidth: node.depth == 0 ? 3 : 1.5)

        if node.isOnline {
            let indicatorRadius = max(3, radius * 0.22)
            let indicatorRect = CGRect(
                x: rect.maxX - indicatorRadius * 1.6,
                y: rect.maxY - indicatorRadius * 1.6,
                width: indicatorRadius * 2,
                height: indicatorRadius * 2
            )
            context.fill(Path(ellipseIn: indicatorRect), with: .color(NodiColor.success))
            context.stroke(Path(ellipseIn: indicatorRect), with: .color(NodiColor.background), lineWidth: 1.5)
        }

        if node.isVerified {
            let badgeRadius = max(3, radius * 0.24)
            let badgeRect = CGRect(
                x: rect.maxX - badgeRadius * 1.6,
                y: rect.minY - badgeRadius * 0.4,
                width: badgeRadius * 2,
                height: badgeRadius * 2
            )
            context.fill(Path(ellipseIn: badgeRect), with: .color(NodiColor.accent))
        }

        if radius > 16 {
            context.draw(
                Text(node.displayName).font(.system(size: max(9, radius * 0.32), weight: .semibold)).foregroundColor(NodiColor.primaryText),
                at: CGPoint(x: point.x, y: rect.maxY + 10)
            )
        }

        context.opacity = 1
    }

    private func clusterCount(_ node: GraphNode) -> Int {
        if case .cluster(let count) = node.kind { return count }
        return 0
    }

    // MARK: Gestures

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in state = value }
            .onEnded { value in
                let newScale = camera.scale * value
                if newScale > 1.6 {
                    camera.scale = 1
                    viewModel.advanceZoomLevel()
                } else if newScale < 0.7 {
                    camera.scale = 1
                    viewModel.retreatZoomLevel()
                } else {
                    camera.scale = min(max(newScale, 0.5), 3)
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragDelta) { value, state, _ in state = value.translation }
            .onEnded { value in
                camera.offset.width += value.translation.width
                camera.offset.height += value.translation.height
            }
    }

    private func handleTap(at location: CGPoint) {
        if let node = viewModel.node(at: location, camera: camera) {
            onTap(node)
        }
    }

    private func loadMissingAvatars() async {
        let needed = viewModel.nodes.filter { !$0.isCluster && $0.photoURL != nil && avatarImages[$0.id] == nil }
        for node in needed {
            guard let urlString = node.photoURL, let url = URL(string: urlString) else { continue }
            if let cached = ImageMemoryCache.shared.image(for: urlString) {
                avatarImages[node.id] = cached
                continue
            }
            if let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) {
                ImageMemoryCache.shared.insert(image, for: urlString)
                avatarImages[node.id] = image
            }
        }
    }
}
