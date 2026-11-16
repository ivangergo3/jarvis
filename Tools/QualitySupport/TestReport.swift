import Foundation

public struct TestCase: Sendable {
    public let id: String
    public var failed = false
    public var skipped = false
}

/// Parse bounded synthetic xUnit output with Foundation's native streaming XML parser.
/// DTDs are refused and external entities are never resolved.
private final class ReportParser: NSObject, XMLParserDelegate {
    var cases: [TestCase] = []
    var invalidSuite = false
    private var current: TestCase?

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName: String?, attributes: [String: String]
    ) {
        if elementName == "testsuite" {
            for key in ["failures", "errors", "skipped"] {
                if let value = attributes[key], Double(value) != 0 { invalidSuite = true }
            }
        }
        if elementName == "testcase" {
            current = TestCase(
                id: TestReport.id(
                    (attributes["classname"] ?? "") + "/" + (attributes["name"] ?? "")))
            current?.skipped = ["skipped", "disabled", "notrun"].contains(
                attributes["status", default: ""].lowercased())
        }
        if elementName == "failure" || elementName == "error" { current?.failed = true }
        if elementName == "skipped" { current?.skipped = true }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String,
        namespaceURI: String?, qualifiedName: String?
    ) {
        if elementName == "testcase", let current {
            cases.append(current)
            self.current = nil
        }
    }
}

public enum TestReport {
    public static func id(_ value: String) -> String {
        String(value.prefix { $0 != "(" })
    }

    public static func read(_ urls: [URL], allowReportedIssues: Bool = false) throws -> [TestCase] {
        var cases: [TestCase] = []
        for url in urls {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: 8 * 1024 * 1024 + 1) ?? Data()
            guard data.count <= 8 * 1024 * 1024 else {
                throw QualityFailure("Oversized test report")
            }
            guard !String(decoding: data, as: UTF8.self).contains("<!DOCTYPE") else {
                throw QualityFailure("Test reports must not contain a DTD")
            }
            let delegate = ReportParser()
            let parser = XMLParser(data: data)
            parser.shouldResolveExternalEntities = false
            parser.delegate = delegate
            guard parser.parse() else { throw QualityFailure("Malformed test report") }
            guard allowReportedIssues || !delegate.invalidSuite else {
                throw QualityFailure("Report contains failures, errors or skips")
            }
            cases += delegate.cases
        }
        return cases
    }

    public static func validate(
        _ cases: [TestCase], discovered: Set<String>,
        required: Set<String>
    ) throws -> Int {
        guard !cases.isEmpty else {
            throw QualityFailure("Zero test cases reported (or missing report)")
        }
        guard !cases.contains(where: { $0.failed || $0.skipped }) else {
            throw QualityFailure("Failed, errored or skipped test case")
        }
        guard !discovered.isEmpty else { throw QualityFailure("Zero tests discovered") }
        let missing = discovered.union(required).subtracting(cases.map(\.id))
        guard missing.isEmpty else {
            throw QualityFailure(
                "Tests missing from results: " + missing.sorted().joined(separator: ", "))
        }
        guard required.isSubset(of: discovered) else {
            throw QualityFailure("Critical tests missing from discovery")
        }
        return cases.count
    }

    public static func files(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" }
    }

    public static func discovered(in text: String) -> Set<String> {
        Set(
            text.split(whereSeparator: \.isNewline).compactMap { line in
                let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    value.range(
                        of: #"^(JarvisTests|QualitySupportTests)\.[^/\s]+/[^\s]+$"#,
                        options: .regularExpression) != nil
                else { return nil }
                return id(value)
            })
    }
}
