import SwiftUI

/// A simple left-to-right, top-to-bottom wrapping layout for chip groups
/// (software tags, filter pills, etc.) where `HStack` would just overflow.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height + spacing } - spacing
        return CGSize(width: maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0), height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        var index = 0
        for row in rows {
            var x = bounds.minX
            for _ in row.subviewIndices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var subviewIndices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentIndices: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth, !currentIndices.isEmpty {
                rows.append(Row(subviewIndices: currentIndices, width: currentWidth - spacing, height: currentHeight))
                currentIndices = []
                currentWidth = 0
                currentHeight = 0
            }
            currentIndices.append(index)
            currentWidth += size.width + spacing
            currentHeight = max(currentHeight, size.height)
        }
        if !currentIndices.isEmpty {
            rows.append(Row(subviewIndices: currentIndices, width: currentWidth - spacing, height: currentHeight))
        }
        return rows
    }
}
