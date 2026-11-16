import Foundation

public enum WorkspaceLaunch: Equatable, Sendable {
    case live
    case fixture(URL)

    public var isFixture: Bool {
        if case .fixture = self { return true }
        return false
    }

    public enum Failure: Error, LocalizedError {
        case missingDirectory, isolatedBundleRequired
        public var errorDescription: String? {
            switch self {
            case .missingDirectory:
                return "Fixture configuration missing; live workspace is disabled."
            case .isolatedBundleRequired:
                return "Use scripts/workspace-journey.sh for an isolated fixture app."
            }
        }
    }

    public static func resolve(
        arguments: [String], bundleIdentifier: String?,
        fixtureDirectory: String?
    ) throws -> Self {
        let isolated = bundleIdentifier?.hasPrefix("dev.jarvis.workspacefixture.") == true
        let index = arguments.firstIndex(of: "--workspace-fixture")
        guard isolated || index != nil else { return .live }
        var path = fixtureDirectory
        if let index {
            guard index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else {
                throw Failure.missingDirectory
            }
            path = arguments[index + 1]
        }
        guard let path, !path.isEmpty else { throw Failure.missingDirectory }
        guard isolated || arguments.contains("--diagnose") else {
            throw Failure.isolatedBundleRequired
        }
        return .fixture(URL(fileURLWithPath: path))
    }
}
