import SwiftUI

/// Bare-bones flow layout (a.k.a. wrapping HStack) used by the URL inspector to
/// wrap stripped-parameter chips across multiple rows when there are many.
/// SwiftUI's built-in `Layout` does the heavy lifting; we just compute origins.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = arrange(subviews: subviews, maxWidth: maxWidth)
        return result.totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, maxWidth: bounds.width)
        for (index, point) in result.origins.enumerated() {
            let placement = CGPoint(x: bounds.origin.x + point.x, y: bounds.origin.y + point.y)
            subviews[index].place(at: placement, proposal: ProposedViewSize(result.sizes[index]))
        }
    }

    private struct Arrangement {
        var origins: [CGPoint]
        var sizes: [CGSize]
        var totalSize: CGSize
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> Arrangement {
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        let totalHeight = y + rowHeight
        return Arrangement(
            origins: origins,
            sizes: sizes,
            totalSize: CGSize(width: max(totalWidth, 0), height: totalHeight)
        )
    }
}
