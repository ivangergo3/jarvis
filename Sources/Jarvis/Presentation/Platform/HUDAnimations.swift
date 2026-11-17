import AppKit
import Combine
import QuartzCore
import SwiftUI

/// Continuous decoration runs in Core Animation's compositor, not SwiftUI frame callbacks.
@MainActor enum HUDLayers {
    static let cyan = NSColor(red: 0.29, green: 0.86, blue: 0.94, alpha: 1).cgColor
    static let gold = NSColor(red: 0.96, green: 0.72, blue: 0.39, alpha: 1).cgColor
    static let muted = NSColor(red: 0.43, green: 0.55, blue: 0.61, alpha: 1).cgColor
    static func change(_ action: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        action()
        CATransaction.commit()
    }
    static func stroke(_ color: CGColor, width: CGFloat, opacity: Float = 1) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.fillColor = nil
        shape.strokeColor = color
        shape.lineWidth = width
        shape.opacity = opacity
        shape.lineCap = .round
        shape.lineJoin = .round
        return shape
    }
    static func repeatAnimation(
        on layer: CALayer, key: String, animation: CAAnimation, running: Bool
    ) {
        if !running {
            layer.removeAnimation(forKey: key)
        } else if layer.animation(forKey: key) == nil {
            animation.repeatCount = .infinity
            layer.add(animation, forKey: key)
        }
    }
}

@MainActor class DecorationLayerView: NSView {
    override var isFlipped: Bool { true }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.isGeometryFlipped = true
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { stopAnimations(layer) }
        super.viewWillMove(toWindow: newWindow)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
    }
    private func stopAnimations(_ parent: CALayer?) {
        parent?.removeAllAnimations()
        for sublayer in parent?.sublayers ?? [] { stopAnimations(sublayer) }
    }
}

struct CompositorBorder: NSViewRepresentable {
    let active: Bool
    let running: Bool
    let cornerRadius: CGFloat
    func makeNSView(context: Context) -> BorderLayerView { BorderLayerView() }
    func updateNSView(_ view: BorderLayerView, context: Context) {
        view.configure(active: active, running: running, radius: cornerRadius)
    }
}

@MainActor final class BorderLayerView: DecorationLayerView {
    private let base = HUDLayers.stroke(HUDLayers.cyan, width: 0.8, opacity: 0.15)
    private let sweep = HUDLayers.stroke(HUDLayers.cyan, width: 1.8)
    private var active = false
    private var running = false
    private var radius: CGFloat = 9
    private var drawnBounds = CGRect.null
    private var drawnRadius: CGFloat = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        sweep.name = "activitySweep"
        sweep.shadowColor = HUDLayers.cyan
        sweep.shadowOpacity = 0.6
        sweep.shadowRadius = 3
        sweep.shadowOffset = .zero
        layer?.addSublayer(base)
        layer?.addSublayer(sweep)
    }
    required init?(coder: NSCoder) { nil }
    func configure(active: Bool, running: Bool, radius: CGFloat) {
        guard self.active != active || self.running != running || self.radius != radius else {
            return
        }
        self.active = active
        self.running = running
        self.radius = radius
        needsLayout = true
    }
    override func layout() {
        super.layout()
        HUDLayers.change {
            let rect = bounds.insetBy(dx: 1, dy: 1)
            if drawnBounds != rect || drawnRadius != radius {
                drawnBounds = rect
                drawnRadius = radius
                let r = min(radius, max(0, min(rect.width, rect.height) / 2))
                let path = CGPath(
                    roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
                base.path = path
                sweep.path = path
                let length = AnimationGeometry.roundedPerimeter(size: rect.size, radius: r)
                sweep.lineDashPattern = [
                    NSNumber(value: Double(length * 0.12)), NSNumber(value: Double(length * 0.88)),
                ]
                sweep.removeAnimation(forKey: "travel")
            }
            base.opacity = active ? 0.35 : 0.15
            sweep.isHidden = !active
            let animation = CABasicAnimation(keyPath: "lineDashPhase")
            animation.fromValue = 0
            animation.toValue = -AnimationGeometry.roundedPerimeter(
                size: drawnBounds.size, radius: radius)
            animation.duration = 6
            HUDLayers.repeatAnimation(
                on: sweep, key: "travel", animation: animation, running: active && running)
        }
    }
}

enum AnimationGeometry {
    static func roundedPerimeter(size: CGSize, radius: CGFloat) -> CGFloat {
        let width = max(0, size.width)
        let height = max(0, size.height)
        let r = min(max(0, radius), min(width, height) / 2)
        return max(0, 2 * (width + height) - 8 * r + 2 * .pi * r)
    }
}

struct CompositorReactor: NSViewRepresentable {
    let running: Bool
    func makeNSView(context: Context) -> ReactorLayerView { ReactorLayerView() }
    func updateNSView(_ view: ReactorLayerView, context: Context) {
        view.configure(running: running)
    }
}

@MainActor final class ReactorLayerView: DecorationLayerView {
    private let minorTicks = HUDLayers.stroke(HUDLayers.cyan, width: 1, opacity: 0.18)
    private let majorTicks = HUDLayers.stroke(HUDLayers.cyan, width: 1, opacity: 0.5)
    private let rings = (0..<3).map {
        HUDLayers.stroke(
            $0 == 1 ? HUDLayers.gold : HUDLayers.cyan,
            width: $0 == 0 ? 2 : 0.7, opacity: $0 == 1 ? 0.45 : 0.3)
    }
    private let coreGlow = CAGradientLayer()
    private let artwork = CALayer()
    private let fallback = HUDLayers.stroke(HUDLayers.cyan, width: 2)
    private var running = false
    private var drawnSize = CGSize.zero
    private static let image: CGImage? = Bundle.main.resourceURL.flatMap { url in
        NSImage(contentsOf: url.appendingPathComponent("reactor.png"))?.cgImage(
            forProposedRect: nil, context: nil, hints: nil)
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.addSublayer(minorTicks)
        layer?.addSublayer(majorTicks)
        for (index, ring) in rings.enumerated() {
            ring.name = "reactorRing\(index)"
            layer?.addSublayer(ring)
        }
        artwork.name = "reactorArtwork"
        artwork.contents = Self.image
        artwork.contentsGravity = .resizeAspect
        artwork.shadowColor = HUDLayers.cyan
        artwork.shadowOpacity = 0.2
        artwork.shadowOffset = .zero
        layer?.addSublayer(artwork)
        layer?.addSublayer(fallback)
        fallback.isHidden = Self.image != nil
        coreGlow.name = "reactorCoreGlow"
        // Feathered attenuation fits inside the artwork's white centre (about 9.5%
        // of its diameter). Cyan rim and surrounding machinery never enter this layer.
        let shade = NSColor(red: 0.12, green: 0.28, blue: 0.32, alpha: 1)
        coreGlow.type = .radial
        coreGlow.colors = [shade.cgColor, shade.cgColor, shade.withAlphaComponent(0).cgColor]
        coreGlow.locations = [0, 0.55, 1]
        coreGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        // A radial gradient needs nonzero X and Y radii; matching Y to
        // startPoint collapses the ellipse and renders no visible pulse.
        coreGlow.endPoint = CGPoint(x: 1, y: 1)
        coreGlow.opacity = 0.10
        layer?.addSublayer(coreGlow)
    }
    required init?(coder: NSCoder) { nil }
    func configure(running: Bool) {
        guard self.running != running else { return }
        self.running = running
        needsLayout = true
    }
    override func layout() {
        super.layout()
        HUDLayers.change {
            let diameter = min(bounds.width, bounds.height)
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            if drawnSize != bounds.size {
                drawnSize = bounds.size
                let minor = CGMutablePath()
                let major = CGMutablePath()
                for index in 0..<120 {
                    let angle = Double(index) * .pi / 60
                    let outer = diameter / 2 * 0.92
                    let inner = outer - (index % 10 == 0 ? 9 : 3)
                    let path = index % 10 == 0 ? major : minor
                    path.move(
                        to: CGPoint(
                            x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                    path.addLine(
                        to: CGPoint(
                            x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                }
                minorTicks.path = minor
                majorTicks.path = major
                for (index, ring) in rings.enumerated() {
                    ring.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
                    ring.position = center
                    let path = CGMutablePath()
                    path.addArc(
                        center: CGPoint(x: diameter / 2, y: diameter / 2),
                        radius: diameter / 2 * (0.78 - Double(index) * 0.055), startAngle: 0,
                        endAngle: 235 * .pi / 180, clockwise: false)
                    ring.path = path
                }
                let size = ReactorMotion.artworkSize(diameter: diameter)
                artwork.bounds = CGRect(x: 0, y: 0, width: size, height: size)
                artwork.position = center
                let glowSize = size * 0.095
                coreGlow.bounds = CGRect(x: 0, y: 0, width: glowSize, height: glowSize)
                coreGlow.position = center
                artwork.shadowRadius = diameter * 0.06
                fallback.path = CGPath(
                    ellipseIn: CGRect(
                        x: center.x - size / 2, y: center.y - size / 2,
                        width: size, height: size), transform: nil)
            }
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.22
            pulse.toValue = 0.02
            pulse.duration = 0.65
            pulse.autoreverses = true
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            HUDLayers.repeatAnimation(
                on: coreGlow, key: "corePulse", animation: pulse, running: running)
            for (index, ring) in rings.enumerated() {
                let speed = [30.0, -45.0, 24.0][index]
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.fromValue = Double(index * 100) * .pi / 180
                animation.toValue = Double(index * 100) * .pi / 180 + (speed > 0 ? 2 : -2) * .pi
                animation.duration = 360 / abs(speed)
                HUDLayers.repeatAnimation(
                    on: ring, key: "orbit", animation: animation, running: running)
            }
        }
    }
}

struct CompositorTopology: NSViewRepresentable {
    let hover: GraphHoverState
    let nodeIDs: [String]
    let selectedID: String?
    let active: [Bool]
    let running: Bool
    let connections: [GraphConnection]
    func makeNSView(context: Context) -> TopologyLayerView { TopologyLayerView() }
    func makeCoordinator() -> TopologyHoverBinding { TopologyHoverBinding() }
    func updateNSView(_ view: TopologyLayerView, context: Context) {
        context.coordinator.update(
            view: view, hover: hover, nodeIDs: nodeIDs, selectedID: selectedID,
            active: active, running: running, connections: connections)
    }
    static func dismantleNSView(_ view: TopologyLayerView, coordinator: TopologyHoverBinding) {
        coordinator.cancel()
    }
}

/// Subscribe at the native decoration boundary: pointer lighting must not invalidate SwiftUI/AX layout.
@MainActor final class TopologyHoverBinding {
    private weak var view: TopologyLayerView?
    private var source: GraphHoverState?
    private var subscription: AnyCancellable?
    private var nodeIDs: [String] = []
    private var selectedID: String?
    private var active: [Bool] = []
    private var running = false
    private var connections: [GraphConnection] = []
    func update(
        view: TopologyLayerView, hover: GraphHoverState, nodeIDs: [String], selectedID: String?,
        active: [Bool], running: Bool, connections: [GraphConnection]
    ) {
        self.view = view
        self.nodeIDs = nodeIDs
        self.selectedID = selectedID
        self.active = active
        self.running = running
        self.connections = connections
        if source !== hover {
            subscription?.cancel()
            source = hover
            subscription = hover.$nodeID.sink { [weak self] id in self?.render(id) }
        } else {
            render(hover.nodeID)
        }
    }
    private func render(_ hovered: String?) {
        RenderWorkCounters.count(.nativeTopologyUpdate)
        view?.configure(
            active: active, highlighted: nodeIDs.map { $0 == hovered || $0 == selectedID },
            running: running, connections: connections)
    }
    func cancel() {
        subscription?.cancel()
        subscription = nil
        source = nil
        view = nil
    }
}

struct CompositorDestination: NSViewRepresentable {
    let destination: GraphHoverDestination
    let selected: Bool
    let active: Bool
    let left: Bool
    func makeNSView(context: Context) -> DestinationLayerView { DestinationLayerView() }
    func makeCoordinator() -> DestinationHoverBinding { DestinationHoverBinding() }
    func updateNSView(_ view: DestinationLayerView, context: Context) {
        context.coordinator.update(
            view: view, state: destination, selected: selected, active: active, left: left)
    }
    static func dismantleNSView(_ view: DestinationLayerView, coordinator: DestinationHoverBinding)
    {
        coordinator.cancel()
    }
}

@MainActor final class DestinationHoverBinding {
    private weak var view: DestinationLayerView?
    private var source: GraphHoverDestination?
    private var subscription: AnyCancellable?
    private var selected = false
    private var active = false
    private var left = false
    func update(
        view: DestinationLayerView, state: GraphHoverDestination, selected: Bool, active: Bool,
        left: Bool
    ) {
        self.view = view
        self.selected = selected
        self.active = active
        self.left = left
        if source !== state {
            subscription?.cancel()
            source = state
            subscription = state.$highlighted.sink { [weak self] value in self?.render(value) }
        } else {
            render(state.highlighted)
        }
    }
    private func render(_ highlighted: Bool) {
        RenderWorkCounters.count(.nativeDestinationUpdate)
        view?.configure(active: active, highlighted: selected || highlighted, left: left)
    }
    func cancel() {
        subscription?.cancel()
        subscription = nil
        source = nil
        view = nil
    }
}

@MainActor final class DestinationLayerView: DecorationLayerView {
    private let border = HUDLayers.stroke(HUDLayers.gold, width: 1)
    private let port = HUDLayers.stroke(HUDLayers.muted, width: 1.4)
    private let core = CAShapeLayer()
    private var left = false
    private var drawnBounds = CGRect.null
    private var drawnLeft: Bool?
    override init(frame: NSRect) {
        super.init(frame: frame)
        clipsToBounds = false  // The connection port straddles the card edge.
        border.name = "destinationBorder"
        port.name = "destinationPort"
        core.name = "destinationCore"
        port.fillColor = NSColor(red: 0.040, green: 0.070, blue: 0.095, alpha: 1).cgColor
        layer?.addSublayer(border)
        layer?.addSublayer(port)
        layer?.addSublayer(core)
    }
    required init?(coder: NSCoder) { nil }
    func configure(active: Bool, highlighted: Bool, left: Bool) {
        HUDLayers.change {
            if self.left != left {
                self.left = left
                needsLayout = true
            }
            let color = active ? HUDLayers.cyan : highlighted ? HUDLayers.gold : HUDLayers.muted
            border.opacity = highlighted && !active ? 0.75 : 0
            port.strokeColor = color.copy(alpha: active || highlighted ? 1 : 0.45)
            port.opacity = 1
            core.fillColor = color
            core.opacity = active || highlighted ? 0.9 : 0.3
        }
    }
    override func layout() {
        super.layout()
        guard drawnBounds != bounds || drawnLeft != left else { return }
        drawnBounds = bounds
        drawnLeft = left
        HUDLayers.change {
            border.path = CGPath(
                roundedRect: bounds, cornerWidth: 12, cornerHeight: 12, transform: nil)
            let x = left ? bounds.maxX : bounds.minX
            port.path = CGPath(
                ellipseIn: CGRect(x: x - 4.5, y: bounds.midY - 4.5, width: 9, height: 9),
                transform: nil)
            core.path = CGPath(
                ellipseIn: CGRect(x: x - 1.5, y: bounds.midY - 1.5, width: 3, height: 3),
                transform: nil)
        }
    }
}

@MainActor final class TopologyLayerView: DecorationLayerView {
    private struct Style: Equatable {
        let active: Bool
        let focused: Bool
        let running: Bool
    }
    private var appliedStyles: [Style?] = []
    private var routes: [GraphConnection] = []
    private var active: [Bool] = []
    private var highlighted: [Bool] = []
    private var running = false
    private var lines: [CAShapeLayer] = []
    private var dots: [CAShapeLayer] = []
    func configure(
        active: [Bool], highlighted: [Bool], running: Bool, connections: [GraphConnection]
    ) {
        guard
            self.active != active || self.highlighted != highlighted || self.running != running
                || routes != connections
        else { return }
        let geometryChanged = routes != connections
        self.active = active
        self.highlighted = highlighted
        self.running = running
        routes = connections
        HUDLayers.change {
            if geometryChanged { rebuildGeometry() }
            updateStyles()
        }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        appliedStyles = Array(repeating: nil, count: lines.count)
        HUDLayers.change { updateStyles() }
    }
    private func rebuildGeometry() {
        RenderWorkCounters.count(.connectorRebuild)
        for sublayer in layer?.sublayers ?? [] { sublayer.removeFromSuperlayer() }
        lines = []
        dots = []
        appliedStyles = Array(repeating: nil, count: routes.count)
        for route in routes {
            let path = CGMutablePath()
            if let first = route.points.first {
                path.move(to: first)
                for point in route.points.dropFirst() { path.addLine(to: point) }
            }
            let line = HUDLayers.stroke(HUDLayers.muted, width: 0.8)
            line.name = "connectorLine"
            line.path = path
            let dot = CAShapeLayer()
            dot.name = "connectorSignal"
            dot.path = CGPath(
                ellipseIn: CGRect(x: -2.5, y: -2.5, width: 5, height: 5), transform: nil)
            dot.fillColor = HUDLayers.cyan
            dot.position = route.points.first ?? .zero
            lines.append(line)
            dots.append(dot)
            layer?.addSublayer(line)
            layer?.addSublayer(dot)
        }
    }
    private func updateStyles() {
        for index in lines.indices {
            let on = index < active.count && active[index]
            let focused = index < highlighted.count && highlighted[index]
            // Active styling already wins over hover; don't dirty unchanged CA layers.
            let style = Style(active: on, focused: !on && focused, running: on && running)
            guard appliedStyles[index] != style else { continue }
            appliedStyles[index] = style
            RenderWorkCounters.count(.connectorStyle)
            let line = lines[index]
            let dot = dots[index]
            line.strokeColor = on ? HUDLayers.cyan : focused ? HUDLayers.gold : HUDLayers.muted
            line.lineWidth = on || focused ? 1.4 : 0.8
            line.opacity = on || focused ? 0.75 : 0.23
            line.lineDashPattern = on || focused ? nil : [3, 5]
            dot.isHidden = !(on && running)
            if on && running && dot.animation(forKey: "signal") == nil {
                let animation = CAKeyframeAnimation(keyPath: "position")
                animation.path = line.path
                animation.calculationMode = .paced
                animation.duration = 1 / 0.18
                animation.timeOffset = Double(index) * 0.17 * animation.duration
                HUDLayers.repeatAnimation(
                    on: dot, key: "signal", animation: animation, running: true)
            } else if !on || !running {
                dot.removeAnimation(forKey: "signal")
            }
        }
    }
}
