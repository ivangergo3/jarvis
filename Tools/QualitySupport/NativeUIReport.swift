import Foundation

public enum NativeUIReport {
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
        discovery: Any, results: Any, summary: [String: Any], required: Set<String>
    ) throws -> Int {
        let discovered = identifiers(in: discovery)
        let executed = identifiers(in: results)
        guard !required.isEmpty, !discovered.isEmpty, required.isSubset(of: discovered),
            executed == discovered
        else { throw QualityFailure("Native UI test inventory is missing or incomplete.") }
        guard summary["failedTests"] as? Int == 0, summary["skippedTests"] as? Int == 0,
            summary["passedTests"] as? Int == discovered.count,
            summary["totalTestCount"] as? Int == discovered.count
        else {
            throw QualityFailure(
                "Native UI results contain failures, skips or an unexpected count.")
        }
        return discovered.count
    }
}
