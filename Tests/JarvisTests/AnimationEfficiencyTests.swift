import AppKit
import Combine
import QuartzCore
import Testing
@testable import Jarvis

@Suite("Animation efficiency") @MainActor struct AnimationEfficiencyTests {
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
        #expect(sweep?.isHidden == false) // Static active indicator remains.
        view.configure(active: false, running: false, radius: 12)
        view.layout()
        #expect(sweep?.isHidden == true)
    }

    @Test func reactorStopsAllOrbitsWithoutLosingItsArtwork() {
        let view = ReactorLayerView(frame: CGRect(x: 0, y: 0, width: 180, height: 180))
        view.configure(running: true)
        view.layout()
        let rings = view.layer?.sublayers?.filter { $0.name?.hasPrefix("reactorRing") == true } ?? []
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
            let view = ReactorLayerView(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
            view.configure(running: true)
            view.layout()
            let core = try #require(view.layer?.sublayers?.first { $0.name == "reactorCoreGlow" } as? CAGradientLayer)
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
            #expect(darkest <= 0.25) // Core remains luminous even at the darkest phase.
            #expect(artwork.animationKeys()?.isEmpty ?? true)
        }
    }

    @Test func coreGradientActuallyRendersAnAreaRatherThanAnEmptyLine() throws {
        let view = ReactorLayerView(frame: CGRect(x: 0, y: 0, width: 270, height: 270))
        view.configure(running: true)
        view.layout()
        let core = try #require(view.layer?.sublayers?.first { $0.name == "reactorCoreGlow" } as? CAGradientLayer)
        // Radial endpoints define both ellipse radii. Either zero radius makes it invisible.
        let radiusX = abs(core.endPoint.x - core.startPoint.x) * core.bounds.width
        let radiusY = abs(core.endPoint.y - core.startPoint.y) * core.bounds.height
        #expect(radiusX > 0)
        #expect(radiusY > 0)
        #expect(abs(radiusX - radiusY) < 0.001)
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40,
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
        var dashboardUpdates = 0, hoverUpdates = 0
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
        parent.cancel(); child.cancel()
    }

    @Test func hoverRetainsConnectorLayersAndRunningSignals() throws {
        let view = TopologyLayerView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let routes = [GraphConnection(points: [.zero, CGPoint(x: 100, y: 100)])]
        view.configure(active: [true], highlighted: [false], running: true, connections: routes)
        let line = try #require(view.layer?.sublayers?.first { $0.name == "connectorLine" } as? CAShapeLayer)
        let dot = try #require(view.layer?.sublayers?.first { $0.name == "connectorSignal" })
        for index in 0..<100 {
            view.configure(active: [true], highlighted: [index % 2 == 0], running: true, connections: routes)
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
        #expect(AnimationGeometry.roundedPerimeter(size: CGSize(width: 100, height: 50), radius: 0) == 300)
        #expect(AnimationGeometry.roundedPerimeter(size: CGSize(width: 10, height: 10), radius: 50) > 0)
    }

    @Test func backgroundRefreshBacksOffWithoutOverridingSlowerUserPreference() {
        #expect(RefreshPolicy.seconds(configured: 3, active: true, visible: true, lowPower: false) == 3)
        #expect(RefreshPolicy.seconds(configured: 3, active: false, visible: true, lowPower: false) == 15)
        #expect(RefreshPolicy.seconds(configured: 3, active: true, visible: false, lowPower: false) == 30)
        #expect(RefreshPolicy.seconds(configured: 3, active: true, visible: true, lowPower: true) == 15)
        #expect(RefreshPolicy.seconds(configured: 30, active: false, visible: true, lowPower: true) == 30)
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
        await connection.setHistory([.object(["status": .string("completed"), "items": .array([
            .object(["type": .string("agentMessage"), "id": .string("new"), "text": .string("New reply")])
        ])])])
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
        let unavailable = FleetSnapshot(projects: [], missions: [], readAt: .distantFuture, notices: ["Unavailable"])
        #expect(!first.hasSameDisplayContent(as: unavailable))
    }
}
