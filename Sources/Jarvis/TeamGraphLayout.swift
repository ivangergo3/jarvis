import Foundation

/// Shared geometry keeps every card and its connector in the same coordinate system.
struct TeamGraphLayout {
    let size: CGSize
    let cardWidth: CGFloat
    let center: CGPoint
    let nodes: [CGPoint]

    var connections: [GraphConnection] {
        nodes.enumerated().map { index, node in
            let left = node.x < center.x
            let sideIndices = nodes.indices.filter { (nodes[$0].x < center.x) == left }
            let rank = sideIndices.firstIndex(of: index) ?? 0
            let edge = node.x + (left ? cardWidth / 2 : -cardWidth / 2)
            // Each route gets its own lane in the empty gutter, never in a card column.
            let fraction = 0.14 + 0.72 * CGFloat(rank + 1) / CGFloat(sideIndices.count + 1)
            let lane = edge + (center.x - edge) * fraction
            let launchY = center.y + (CGFloat(rank) - CGFloat(sideIndices.count - 1) / 2) * 12
            return GraphConnection(points: [CGPoint(x: center.x, y: launchY),
                                             CGPoint(x: lane, y: launchY),
                                             CGPoint(x: lane, y: node.y),
                                             CGPoint(x: edge, y: node.y)])
        }
    }

    init(count: Int, viewport: CGSize) {
        let count = max(0, count)
        if count <= 4 {
            size = CGSize(width: max(1, viewport.width), height: max(1, viewport.height))
            cardWidth = min(275, size.width * 0.37)
            center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
            let canvas = size
            nodes = (0..<count).map { index in
                CGPoint(x: canvas.width * (index % 2 == 0 ? 0.23 : 0.77),
                        y: canvas.height * (index < 2 ? 0.19 : 0.81))
            }
        } else {
            let rows = (count + 1) / 2
            // Reserve a dedicated centre lane for the reactor. Smaller windows can pan
            // horizontally; larger teams extend vertically instead of shrinking their text.
            size = CGSize(width: max(860, viewport.width), height: max(viewport.height, CGFloat(rows) * 220 + 60))
            cardWidth = min(275, (size.width - 320) / 2 - 24)
            center = CGPoint(x: size.width / 2, y: size.height / 2)
            let spacing = (size.height - 60) / CGFloat(rows)
            let canvas = size, width = cardWidth
            nodes = (0..<count).map { index in
                CGPoint(x: index % 2 == 0 ? 24 + width / 2 : canvas.width - 24 - width / 2,
                        y: 30 + (CGFloat(index / 2) + 0.5) * spacing)
            }
        }
    }
}

struct GraphConnection: Equatable {
    let points: [CGPoint]
    var destination: CGPoint { points.last! }

    /// Constant speed around elbows, without teleporting between unequal segments.
    func point(at fraction: Double) -> CGPoint {
        if fraction >= 1 { return destination }
        if fraction <= 0 { return points[0] }
        let lengths = zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var distance = CGFloat(min(1, max(0, fraction))) * lengths.reduce(0, +)
        for (index, length) in lengths.enumerated() {
            if distance <= length && length > 0 {
                let a = points[index], b = points[index + 1], t = distance / length
                return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            distance -= length
        }
        return destination
    }
}
