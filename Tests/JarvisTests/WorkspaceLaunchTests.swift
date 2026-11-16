import Foundation
import JarvisDomain
import Testing

@Suite("Synthetic workspace launch isolation")
struct WorkspaceLaunchTests {
    @Test func normalLaunchRemainsLive() throws {
        #expect(
            try WorkspaceLaunch.resolve(
                arguments: [], bundleIdentifier: "dev.jarvis.app", fixtureDirectory: nil) == .live)
    }
    @Test func reopeningFixtureWithoutArgumentsUsesEmbeddedDataInsteadOfLiveRecords() throws {
        #expect(
            try WorkspaceLaunch.resolve(
                arguments: [], bundleIdentifier: "dev.jarvis.workspacefixture.synthetic",
                fixtureDirectory: "/synthetic/workspace")
                == .fixture(URL(fileURLWithPath: "/synthetic/workspace")))
    }
    @Test func fixtureWithMissingConfigurationFailsClosed() {
        #expect(throws: WorkspaceLaunch.Failure.missingDirectory) {
            try WorkspaceLaunch.resolve(
                arguments: [], bundleIdentifier: "dev.jarvis.workspacefixture.synthetic",
                fixtureDirectory: nil)
        }
        #expect(throws: WorkspaceLaunch.Failure.missingDirectory) {
            try WorkspaceLaunch.resolve(
                arguments: ["--workspace-fixture", "--diagnose"], bundleIdentifier: nil,
                fixtureDirectory: nil)
        }
    }
    @Test func fixtureCannotReuseTheNormalAppsPreferences() {
        #expect(throws: WorkspaceLaunch.Failure.isolatedBundleRequired) {
            try WorkspaceLaunch.resolve(
                arguments: ["--workspace-fixture", "/synthetic/workspace"],
                bundleIdentifier: "dev.jarvis.app", fixtureDirectory: nil)
        }
    }
    @Test func explicitNonUIFixtureDiagnosisIsAllowed() throws {
        #expect(
            try WorkspaceLaunch.resolve(
                arguments: ["--diagnose", "--workspace-fixture", "/synthetic/workspace"],
                bundleIdentifier: nil, fixtureDirectory: nil
            ).isFixture)
    }
}
