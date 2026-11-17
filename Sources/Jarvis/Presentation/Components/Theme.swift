import JarvisDomain
import SwiftUI

enum HUD {
    static let background = Color(red: 0.025, green: 0.045, blue: 0.065)
    static let panel = Color(red: 0.040, green: 0.070, blue: 0.095)
    static let cyan = Color(red: 0.29, green: 0.86, blue: 0.94)
    static let gold = Color(red: 0.96, green: 0.72, blue: 0.39)
    static let text = Color(red: 0.84, green: 0.91, blue: 0.94)
    static let muted = Color(red: 0.43, green: 0.55, blue: 0.61)
    static let line = cyan.opacity(0.15)
    static func mono(_ size: CGFloat = 10, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func color(_ status: MissionStatus) -> Color {
        switch status {
        case .working: return cyan
        case .standby: return muted
        case .interrupted: return gold
        case .unknown: return gold
        }
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = HUD.muted
    var body: some View { Text(text).font(HUD.mono(10)).tracking(2).foregroundStyle(color) }
}

/// A wrapped interval keeps the light continuous as it crosses the path's seam.
enum BorderSweep {
    static func ranges(progress: CGFloat, length: CGFloat = 0.12) -> [ClosedRange<CGFloat>] {
        let end = progress - floor(progress)
        let span = min(1, max(0, length))
        let start = end - span
        return start < 0 ? [(1 + start)...1, 0...end] : [start...end]
    }
}

struct HeaderSweepShape: Shape {
    var progress: CGFloat
    var cornerRadius: CGFloat = 9
    func path(in rect: CGRect) -> Path {
        let outline = RoundedRectangle(cornerRadius: cornerRadius).path(
            in: rect.insetBy(dx: 1, dy: 1))
        var path = Path()
        for range in BorderSweep.ranges(progress: progress) {
            path.addPath(outline.trimmedPath(from: range.lowerBound, to: range.upperBound))
        }
        return path
    }
}

struct HeaderActivityBorder: View {
    let active: Bool
    let motion: Bool
    var cornerRadius: CGFloat = 9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CompositorBorder(
            active: active, running: active && motion && !reduceMotion,
            cornerRadius: cornerRadius)
    }
}

/// Explicit HUD colours avoid the system accent becoming a bright fill in active windows.
struct HUDControlStyle: ButtonStyle {
    var selected = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? HUD.cyan : HUD.text)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                HUD.cyan.opacity(configuration.isPressed ? 0.16 : selected ? 0.09 : 0.035),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(HUD.cyan.opacity(selected ? 0.3 : 0.12), lineWidth: 0.7)
            )
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
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
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(
                    selected ? HUD.cyan.opacity(0.65) : HUD.line, lineWidth: selected ? 1 : 0.6))
    }
}

struct GridBackdrop: View {
    var body: some View {
        GridLines().stroke(HUD.cyan.opacity(0.035), lineWidth: 0.5)
            .allowsHitTesting(false)
    }
}

private struct GridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var grid = Path()
        for x in stride(from: rect.minX, through: rect.maxX, by: 48) {
            grid.move(to: CGPoint(x: x, y: rect.minY))
            grid.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        for y in stride(from: rect.minY, through: rect.maxY, by: 48) {
            grid.move(to: CGPoint(x: rect.minX, y: y))
            grid.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return grid
    }
}

enum ReactorMotion {
    static func artworkSize(diameter: CGFloat) -> CGFloat { max(0, min(144, diameter * 0.54)) }

    static func ringAngle(elapsed: TimeInterval, ring: Int) -> Double {
        let speeds = [30.0, -45.0, 24.0]
        let speed = speeds[min(2, max(0, ring))]
        return (elapsed * speed + Double(ring * 100)).truncatingRemainder(dividingBy: 360)
    }
}

struct Reactor: View {
    var motion: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        CompositorReactor(running: motion && !reduceMotion)
            .allowsHitTesting(false).accessibilityLabel("Jarvis reactor")
    }
}
