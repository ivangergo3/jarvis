import SwiftUI

enum HUD {
    static let background = Color(red: 0.025, green: 0.045, blue: 0.065)
    static let panel = Color(red: 0.040, green: 0.070, blue: 0.095)
    static let cyan = Color(red: 0.29, green: 0.86, blue: 0.94)
    static let gold = Color(red: 0.96, green: 0.72, blue: 0.39)
    static let text = Color(red: 0.84, green: 0.91, blue: 0.94)
    static let muted = Color(red: 0.43, green: 0.55, blue: 0.61)
    static let line = cyan.opacity(0.15)
    static func mono(_ size: CGFloat = 10, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .monospaced) }
    static func color(_ status: MissionStatus) -> Color {
        switch status { case .working: return cyan; case .standby: return muted; case .interrupted: return gold; case .unknown: return gold }
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = HUD.muted
    var body: some View { Text(text).font(HUD.mono(10)).tracking(2).foregroundStyle(color) }
}

struct StatusBadge: View {
    let status: MissionStatus
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(HUD.color(status)).frame(width: 5, height: 5)
            Text(status.label).font(HUD.mono(9)).tracking(0.8)
        }.foregroundStyle(HUD.color(status)).padding(.horizontal, 9).padding(.vertical, 6)
            .background(HUD.color(status).opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(HUD.color(status).opacity(0.20), lineWidth: 0.5))
    }
}

struct HUDPanel: ViewModifier {
    var selected = false
    func body(content: Content) -> some View {
        content.background(HUD.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? HUD.cyan.opacity(0.65) : HUD.line, lineWidth: selected ? 1 : 0.6))
    }
}

struct GridBackdrop: View {
    var body: some View {
        Canvas { context, size in
            var grid = Path()
            for x in stride(from: CGFloat(0), through: size.width, by: 48) { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)) }
            for y in stride(from: CGFloat(0), through: size.height, by: 48) { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)) }
            context.stroke(grid, with: .color(HUD.cyan.opacity(0.035)), lineWidth: 0.5)
        }.allowsHitTesting(false)
    }
}

struct Reactor: View {
    var motion: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !motion || reduceMotion)) { timeline in
            let t = motion && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                Circle().fill(RadialGradient(colors: [HUD.cyan.opacity(0.10), .clear], center: .center, startRadius: 20, endRadius: 160))
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = min(size.width, size.height) / 2
                    for i in 0..<120 {
                        let a = Double(i) * .pi / 60
                        let outer = r * 0.92, inner = outer - (i % 10 == 0 ? 9 : 3)
                        var p = Path(); p.move(to: CGPoint(x: center.x + cos(a) * inner, y: center.y + sin(a) * inner))
                        p.addLine(to: CGPoint(x: center.x + cos(a) * outer, y: center.y + sin(a) * outer))
                        context.stroke(p, with: .color(i % 10 == 0 ? HUD.cyan.opacity(0.5) : HUD.cyan.opacity(0.18)), lineWidth: 1)
                    }
                    for ring in 0..<3 {
                        let radius = r * (0.78 - Double(ring) * 0.055)
                        let angle = t * (ring == 1 ? -2 : 1.3) + Double(ring * 100)
                        var arc = Path(); arc.addArc(center: center, radius: radius, startAngle: .degrees(angle), endAngle: .degrees(angle + 235), clockwise: false)
                        context.stroke(arc, with: .color(ring == 1 ? HUD.gold.opacity(0.45) : HUD.cyan.opacity(0.30)), style: StrokeStyle(lineWidth: ring == 0 ? 2 : 0.7, lineCap: .round))
                    }
                }
                if let image = NSImage(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("reactor.png")) {
                    Image(nsImage: image).resizable().interpolation(.high).scaledToFit().frame(width: 144, height: 144)
                        .shadow(color: HUD.cyan.opacity(0.18 + sin(t * 0.7) * 0.04), radius: 18)
                        .offset(y: motion && !reduceMotion ? sin(t * 0.65) * 2 : 0)
                } else {
                    Circle().stroke(HUD.cyan, lineWidth: 2).frame(width: 100, height: 100)
                }
            }
        }.accessibilityLabel("Jarvis reactor")
    }
}

struct TopologyLines: View {
    let active: [Bool]
    let highlighted: [Bool]
    let motion: Bool
    let connections: [GraphConnection]
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !motion)) { timeline in
            Canvas { context, _ in
                for (i, route) in connections.enumerated() {
                    let on = i < active.count && active[i]
                    let focused = i < highlighted.count && highlighted[i]
                    let color = on ? HUD.cyan : focused ? HUD.gold : HUD.muted
                    var p = Path(); p.move(to: route.points[0])
                    for point in route.points.dropFirst() { p.addLine(to: point) }
                    context.stroke(p, with: .color(color.opacity(on || focused ? 0.75 : 0.23)), style: StrokeStyle(lineWidth: on || focused ? 1.4 : 0.8, lineCap: .round, lineJoin: .round, dash: on || focused ? [] : [3, 5]))
                    let end = route.destination
                    let direction: CGFloat = end.x < route.points[route.points.count - 2].x ? -1 : 1
                    var arrow = Path(); arrow.move(to: CGPoint(x: end.x - direction * 8, y: end.y - 4)); arrow.addLine(to: end); arrow.addLine(to: CGPoint(x: end.x - direction * 8, y: end.y + 4))
                    context.stroke(arrow, with: .color(color.opacity(on || focused ? 0.95 : 0.4)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                    if on && motion {
                        let point = route.point(at: GraphDestination.phase(timeline.date, index: i))
                        context.fill(Path(ellipseIn: CGRect(x: point.x-2.5, y: point.y-2.5, width: 5, height: 5)), with: .color(HUD.cyan))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// The destination flashes as its own travelling pulse arrives. Hover and selection
/// also highlight the matching route, including idle nodes without implying work.
struct GraphDestination: ViewModifier {
    let active: Bool
    let highlighted: Bool
    let motion: Bool
    let index: Int
    let left: Bool

    static func phase(_ date: Date, index: Int) -> Double {
        (date.timeIntervalSinceReferenceDate * 0.18 + Double(index) * 0.17).truncatingRemainder(dividingBy: 1)
    }
    func body(content: Content) -> some View {
        content.overlay {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !active || !motion)) { timeline in
                let phase = Self.phase(timeline.date, index: index)
                let arrival = active && motion ? max(0, 1 - abs(phase - 0.94) / 0.10) : 0
                let color = active ? HUD.cyan : highlighted ? HUD.gold : HUD.muted
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(active ? 0.42 + arrival * 0.55 : highlighted ? 0.9 : 0), lineWidth: active || highlighted ? 1.4 + arrival : 0)
                    .shadow(color: color.opacity(active ? 0.15 + arrival * 0.45 : highlighted ? 0.25 : 0), radius: 8 + arrival * 8)
                    .overlay(alignment: left ? .trailing : .leading) {
                        Circle().fill(HUD.panel).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(color.opacity(active || highlighted ? 1 : 0.45), lineWidth: 1.4))
                            .overlay(Circle().fill(color.opacity(active || highlighted ? 0.9 : 0.3)).frame(width: 3, height: 3))
                            .shadow(color: color.opacity(active ? 0.7 : 0), radius: 5 + arrival * 5)
                            .offset(x: left ? 4.5 : -4.5)
                    }
            }.allowsHitTesting(false)
        }
    }
}
