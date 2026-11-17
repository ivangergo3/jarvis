import AppKit
import Combine
import JarvisDomain
import QuartzCore
import Testing

@testable import Jarvis

@Suite("Animation efficiency") @MainActor struct AnimationEfficiencyTests {
    @Test func nativeHoverBindingsRenderLatestStateAndStopAfterCancellation() throws {
        let hover = GraphHoverState()
        let card = hover.destination(for: "a")
        let destination = DestinationLayerView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let cardBinding = DestinationHoverBinding()
        cardBinding.update(
            view: destination, state: card, selected: false, active: false, left: true)
        destination.layout()
        #expect(!destination.clipsToBounds)
        let border = try #require(
            destination.layer?.sublayers?.first { $0.name == "destinationBorder" })
        let port = try #require(
            destination.layer?.sublayers?.first { $0.name == "destinationPort" } as? CAShapeLayer)
        let topology = TopologyLayerView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let topologyBinding = TopologyHoverBinding()
        let routes = [GraphConnection(points: [.zero, CGPoint(x: 100, y: 50)])]
        topologyBinding.update(
            view: topology, hover: hover, nodeIDs: ["a"], selectedID: nil,
            active: [false], running: false, connections: routes)
        let line = try #require(topology.layer?.sublayers?.first as? CAShapeLayer)
        #expect(border.opacity == 0)
        hover.update("a", inside: true)
        #expect(border.opacity == 0.75)
        #expect(port.strokeColor == HUDLayers.gold)
        #expect(line.strokeColor == HUDLayers.gold)
        #expect(port.path?.boundingBox.midX == 200)
        cardBinding.update(
            view: destination, state: card, selected: false, active: true, left: false)
        destination.layout()
        #expect(port.path?.boundingBox.midX == 0)
        #expect(border.opacity == 0)
        #expect(port.strokeColor == HUDLayers.cyan)
        cardBinding.cancel()
        topologyBinding.cancel()
        hover.clear()
        #expect(line.strokeColor == HUDLayers.gold)
        #expect(port.strokeColor == HUDLayers.cyan)
        let replacement = GraphHoverState()
        topologyBinding.update(
            view: topology, hover: replacement, nodeIDs: ["a"], selectedID: nil,
            active: [false], running: false, connections: routes)
        #expect(line.strokeColor == HUDLayers.muted)
        hover.update("a", inside: true)
        #expect(line.strokeColor == HUDLayers.muted)
        topologyBinding.cancel()
    }

    @Test func connectorHoverLoadOnlyWritesChangedLayerStyles() throws {
        for count in [4, 100] {
            let view = TopologyLayerView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
            let routes = (0..<count).map { index in
                GraphConnection(points: [.zero, CGPoint(x: index + 1, y: 100)])
            }
            let inactive = Array(repeating: false, count: count)
            view.configure(
                active: inactive, highlighted: inactive, running: true, connections: routes)
            let lines = view.layer?.sublayers ?? []
            var writes = 0
            RenderWorkCounters.onCount = { if $0 == .connectorStyle { writes += 1 } }
            defer { RenderWorkCounters.onCount = nil }
            let transitions = 1_000
            for index in 0..<transitions {
                var highlight = inactive
                highlight[index % count] = true
                view.configure(
                    active: inactive, highlighted: highlight, running: true, connections: routes)
                view.configure(
                    active: inactive, highlighted: highlight, running: true, connections: routes)
            }
            view.configure(
                active: inactive, highlighted: inactive, running: false, connections: routes)
            #expect(writes == transitions * 2)
            #expect(view.layer?.sublayers?.count == lines.count)
            #expect(zip(lines, view.layer?.sublayers ?? []).allSatisfy { $0.0 === $0.1 })
            let shapes = (view.layer?.sublayers ?? []).compactMap { $0 as? CAShapeLayer }
            #expect(
                shapes.filter { $0.name == "connectorLine" }.allSatisfy {
                    $0.strokeColor == HUDLayers.muted
                })
        }
    }

    @Test func borderUsesOneCompositorAnimationAndStopsWhenDisabled() {
        let view = BorderLayerView(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
        view.configure(active: true, running: true, radius: 12)
        view.layout()
        let sweep = view.layer?.sublayers?.first { $0.name == "activitySweep" }
        #expect(sweep?.animation(forKey: "travel") != nil)
        let before = sweep?.animation(forKey: "travel")?.duration
        view.configure(active: true, running: true, radius: 12)
        view.layout()
        #expect(sweep?.animation(forKey: "travel")?.duration == before)
        view.configure(active: true, running: false, radius: 12)
        view.layout()
        #expect(sweep?.animationKeys()?.isEmpty ?? true)
        #expect(sweep?.isHidden == false)  // Static active indicator remains.
        view.configure(active: false, running: false, radius: 12)
        view.layout()
        #expect(sweep?.isHidden == true)
    }

    @Test func reactorStopsAllOrbitsWithoutLosingItsArtwork() {
        let view = ReactorLayerView(frame: CGRect(x: 0, y: 0, width: 180, height: 180))
        view.configure(running: true)
        view.layout()
        let rings =
            view.layer?.sublayers?.filter { $0.name?.hasPrefix("reactorRing") == true } ?? []
        #expect(rings.count == 3)
        #expect(rings.allSatisfy { $0.animation(forKey: "orbit") != nil })
        view.configure(running: false)
        view.layout()
        #expect(rings.allSatisfy { $0.animationKeys()?.isEmpty ?? true })
        #expect(view.layer?.sublayers?.contains { $0.name == "reactorArtwork" } == true)
    }

    @Test func reactorArtworkStaysFixedWhenAnimationStateChanges() throws {
        let view = ReactorLayerView(frame: CGRect(x: 0, y: 0, width: 180, height: 180))
        for running in [true, false, true] {
            view.configure(running: running)
            view.layout()
            let artwork = try #require(view.layer?.sublayers?.first { $0.name == "reactorArtwork" })
            #expect(artwork.position == CGPoint(x: 90, y: 90))
            #expect(CATransform3DEqualToTransform(artwork.transform, CATransform3DIdentity))
            #expect(artwork.animationKeys()?.isEmpty ?? true)
        }
    }

    @Test func pulseChangesOnlyCoreOpacityAndStopsWhenDisabled() throws {
        let view = ReactorLayerView(frame: CGRect(x: 0, y: 0, width: 180, height: 180))
        view.configure(running: true)
        view.layout()
        let core = try #require(view.layer?.sublayers?.first { $0.name == "reactorCoreGlow" })
        let animation = try #require(core.animation(forKey: "corePulse") as? CABasicAnimation)
        #expect(animation.keyPath == "opacity")
        #expect(animation.autoreverses)
        #expect(core.position == CGPoint(x: 90, y: 90))
        #expect(CATransform3DEqualToTransform(core.transform, CATransform3DIdentity))
        view.configure(running: false)
        view.layout()
        #expect(core.animationKeys()?.isEmpty ?? true)
    }

    @Test func corePulseStaysInsideWhiteCentreAcrossSizes() throws {
        for diameter in [125.0, 180, 270] {
            let view = ReactorLayerView(
                frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
            view.configure(running: true)
            view.layout()
            let core = try #require(
                view.layer?.sublayers?.first { $0.name == "reactorCoreGlow" } as? CAGradientLayer)
            let artwork = try #require(view.layer?.sublayers?.first { $0.name == "reactorArtwork" })
            // Artwork's white disc is inside the inner 10%; the cyan rim is outside it.
            #expect(core.bounds.width <= artwork.bounds.width * 0.10)
            #expect(core.position == artwork.position)
            #expect(core.type == .radial)
            let colors = try #require(core.colors as? [CGColor])
            let edge = try #require(colors.last)
            #expect(edge.alpha == 0)
            let pulse = try #require(core.animation(forKey: "corePulse") as? CABasicAnimation)
            let darkest = try #require(pulse.fromValue as? Double)
            #expect(darkest <= 0.25)  // Core remains luminous even at the darkest phase.
            #expect(artwork.animationKeys()?.isEmpty ?? true)
        }
    }

    @Test func coreGradientActuallyRendersAnAreaRatherThanAnEmptyLine() throws {
        let view = ReactorLayerView(frame: CGRect(x: 0, y: 0, width: 270, height: 270))
        view.configure(running: true)
        view.layout()
        let core = try #require(
            view.layer?.sublayers?.first { $0.name == "reactorCoreGlow" } as? CAGradientLayer)
        // Radial endpoints define both ellipse radii. Either zero radius makes it invisible.
        let radiusX = abs(core.endPoint.x - core.startPoint.x) * core.bounds.width
        let radiusY = abs(core.endPoint.y - core.startPoint.y) * core.bounds.height
        #expect(radiusX > 0)
        #expect(radiusY > 0)
        #expect(abs(radiusX - radiusY) < 0.001)
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        graphics.cgContext.scaleBy(x: 40 / core.bounds.width, y: 40 / core.bounds.height)
        core.render(in: graphics.cgContext)
        let centre = try #require(bitmap.colorAt(x: 20, y: 20))
        #expect(centre.alphaComponent > 0.01)
    }

    @Test func hoverDoesNotRepublishDashboardAndIgnoresStaleExits() {
        let dashboard = DashboardState()
        var dashboardUpdates = 0
        var hoverUpdates = 0
        let parent = dashboard.objectWillChange.sink { dashboardUpdates += 1 }
        let child = dashboard.graphHover.objectWillChange.sink { hoverUpdates += 1 }
        dashboard.graphHover.update("a", inside: true)
        dashboard.graphHover.update("a", inside: true)
        dashboard.graphHover.update("b", inside: true)
        dashboard.graphHover.update("a", inside: false)
        #expect(dashboard.graphHover.nodeID == "b")
        #expect(hoverUpdates == 2)
        #expect(dashboardUpdates == 0)
        dashboard.graphHover.clear()
        #expect(dashboard.graphHover.nodeID == nil)
        parent.cancel()
        child.cancel()
    }

    @Test func hoverRetainsConnectorLayersAndRunningSignals() throws {
        let view = TopologyLayerView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let routes = [GraphConnection(points: [.zero, CGPoint(x: 100, y: 100)])]
        view.configure(active: [true], highlighted: [false], running: true, connections: routes)
        let line = try #require(
            view.layer?.sublayers?.first { $0.name == "connectorLine" } as? CAShapeLayer)
        let dot = try #require(view.layer?.sublayers?.first { $0.name == "connectorSignal" })
        for index in 0..<100 {
            view.configure(
                active: [true], highlighted: [index % 2 == 0], running: true, connections: routes)
            #expect(view.layer?.sublayers?.first === line)
            #expect(view.layer?.sublayers?.last === dot)
            #expect(dot.animation(forKey: "signal") != nil)
        }
        view.configure(active: [false], highlighted: [true], running: false, connections: routes)
        #expect(line.strokeColor == HUDLayers.gold)
        #expect(dot.isHidden)
        #expect(dot.animationKeys()?.isEmpty ?? true)
        let resized = [GraphConnection(points: [.zero, CGPoint(x: 200, y: 100)])]
        view.configure(active: [true], highlighted: [false], running: true, connections: resized)
        #expect(view.layer?.sublayers?.first !== line)
    }

    @Test func roundedPathLengthHandlesTinyViews() {
        #expect(AnimationGeometry.roundedPerimeter(size: .zero, radius: 12) == 0)
        #expect(
            AnimationGeometry.roundedPerimeter(size: CGSize(width: 100, height: 50), radius: 0)
                == 300)
        #expect(
            AnimationGeometry.roundedPerimeter(size: CGSize(width: 10, height: 10), radius: 50) > 0)
    }

    @Test func backgroundRefreshBacksOffWithoutOverridingSlowerUserPreference() {
        #expect(
            RefreshPolicy.seconds(configured: 3, active: true, visible: true, lowPower: false) == 3)
        #expect(
            RefreshPolicy.seconds(configured: 3, active: false, visible: true, lowPower: false)
                == 15)
        #expect(
            RefreshPolicy.seconds(configured: 3, active: true, visible: false, lowPower: false)
                == 30)
        #expect(
            RefreshPolicy.seconds(configured: 3, active: true, visible: true, lowPower: true) == 15)
        #expect(
            RefreshPolicy.seconds(configured: 30, active: false, visible: true, lowPower: true)
                == 30)
    }

    @Test func unchangedHistoryDoesNotRepublishMessagesButNewRepliesDo() async {
        let connection = LinkedFixtureConnection()
        let model = CompanionModel(makeConnection: { connection })
        let scope = ConversationScope(projectID: "p", name: "Test", directory: nil, threadID: "a")
        await model.follow(scope)
        var publications = 0
        let subscription = model.$messages.dropFirst().sink { _ in publications += 1 }
        await model.refreshLinkedHistory()
        await model.refreshLinkedHistory()
        #expect(publications == 0)
        await connection.setHistory([
            .object([
                "status": .string("completed"),
                "items": .array([
                    .object([
                        "type": .string("agentMessage"), "id": .string("new"),
                        "text": .string("New reply"),
                    ])
                ]),
            ])
        ])
        await model.refreshLinkedHistory()
        #expect(publications == 1)
        #expect(model.completionID == "new")
        await model.refreshLinkedHistory()
        #expect(publications == 1)
        subscription.cancel()
        await model.shutdown()
    }

    @Test func observationTimestampAloneDoesNotChangeDisplay() {
        let first = FleetSnapshot(projects: [], missions: [], readAt: .distantPast, notices: [])
        let next = FleetSnapshot(projects: [], missions: [], readAt: .distantFuture, notices: [])
        #expect(first.hasSameDisplayContent(as: next))
        let unavailable = FleetSnapshot(
            projects: [], missions: [], readAt: .distantFuture, notices: ["Unavailable"])
        #expect(!first.hasSameDisplayContent(as: unavailable))
    }
}
