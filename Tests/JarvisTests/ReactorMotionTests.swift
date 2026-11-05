import Foundation
import Testing
@testable import Jarvis

@Suite("Reactor motion") struct ReactorMotionTests {
    @Test func artworkAndGlowFitSmallAndLargeReactors() {
        for diameter in [125.0, 180, 270] {
            let artwork = ReactorMotion.artworkSize(diameter: diameter)
            #expect(artwork + diameter * 0.24 < diameter)
        }
        #expect(ReactorMotion.artworkSize(diameter: 0) == 0)
    }
    @Test func ringsMakeVisibleProgressInOppositeDirections() {
        #expect(ReactorMotion.ringAngle(elapsed: 1, ring: 0) == 30)
        #expect(ReactorMotion.ringAngle(elapsed: 1, ring: 1) == 55)
        #expect(ReactorMotion.ringAngle(elapsed: 12, ring: 0) == 0)
    }
}
