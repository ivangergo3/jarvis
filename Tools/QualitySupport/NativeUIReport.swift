import Foundation

public enum NativeUIReport {
    public enum Shard: Int {
        case interactions = 1
        case remaining = 2

        // These three journeys measured 96.8s together; the other six took
        // 89.5s on the same Intel runner. The second shard also gets new tests.
        private static let namedJourneys = [
            "testEmptyProject", "testKeyboardNavigationAndDraftDestination",
            "testViewModesSettingsAndPanelVisibilityPreserveDraft",
        ]

        public var xcodeFilters: [String] {
            let flag = self == .interactions ? "-only-testing:" : "-skip-testing:"
            return Self.namedJourneys.map { flag + "JarvisUITests/JarvisUITests/" + $0 }
        }

        fileprivate func expected(from discovered: Set<String>) throws -> Set<String> {
            let interactions = Set(Self.namedJourneys)
            guard interactions.isSubset(of: discovered) else {
                throw QualityFailure("Native UI discovery is missing a sharded journey.")
            }
            return self == .interactions ? interactions : discovered.subtracting(interactions)
        }
    }

    public static func identifiers(in value: Any) -> Set<String> {
        if let dictionary = value as? [String: Any] {
            return dictionary.values.reduce(into: []) { $0.formUnion(identifiers(in: $1)) }
        }
        if let array = value as? [Any] {
            return array.reduce(into: []) { $0.formUnion(identifiers(in: $1)) }
        }
        guard let string = value as? String,
            let last = string.split(separator: "/").last
        else { return [] }
        let name = String(last).replacingOccurrences(of: "()", with: "")
        guard name.range(of: "^test[A-Za-z0-9_]+$", options: .regularExpression) != nil else {
            return []
        }
        return [name]
    }

    public static func validate(
        discovery: Any, results: Any, summary: [String: Any], required: Set<String>,
        shard: Shard? = nil
    ) throws -> Int {
        let discovered = identifiers(in: discovery)
        let expected = try shard?.expected(from: discovered) ?? discovered
        let executed = identifiers(in: results)
        guard !required.isEmpty, !expected.isEmpty, required.isSubset(of: discovered),
            executed == expected
        else { throw QualityFailure("Native UI test inventory is missing or incomplete.") }
        guard summary["failedTests"] as? Int == 0, summary["skippedTests"] as? Int == 0,
            summary["passedTests"] as? Int == expected.count,
            summary["totalTestCount"] as? Int == expected.count
        else {
            throw QualityFailure(
                "Native UI results contain failures, skips or an unexpected count.")
        }
        return expected.count
    }
}
